// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qportal_webapp/screens/verifier/alert_page.dart';
import 'package:qportal_webapp/screens/verifier/subscription_page.dart';
import 'package:qportal_webapp/utils/webApp_config.dart';
import 'package:qportal_webapp/models/verifiying_models.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/utils/logger.dart';

// ─── Exceptions & Results ─────────────────────────────────────────────────────

class ConnectionException implements Exception {
  final String message;
  ConnectionException([this.message = 'Unable to connect to the server.']);
  @override
  String toString() => message;
}

class IssueResult {
  final bool success;
  final String credentialID;
  final String? error;

  const IssueResult({
    required this.success,
    required this.credentialID,
    this.error,
  });
}

class VerificationDetailData {
  final VerificationHistoryRecord historyRecord;
  final VerificationResult result;

  const VerificationDetailData({
    required this.historyRecord,
    required this.result,
  });
}

// Add this wrapper model for alerts to decouple from mock data
class LiveAlertRecord {
  final String id;
  final String credentialID;
  final String holderName;
  final String credentialName;
  final AlertSeverity severity;
  final String description;
  final String dateTime;
  bool acknowledged;

  LiveAlertRecord({
    required this.id,
    required this.credentialID,
    required this.holderName,
    required this.credentialName,
    required this.severity,
    required this.description,
    required this.dateTime,
    this.acknowledged = false,
  });
}

// Audit Log Wrappers
enum LiveAuditAction {
  issued,
  revoked,
  suspended,
  verified,
  policy,
  system,
  error,
}

class LiveAuditLogRecord {
  final String id;
  final LiveAuditAction action;
  final String details;
  final String performedBy;
  final String performedByRole;
  final String ipAddress;
  final String timestamp;

  LiveAuditLogRecord({
    required this.id,
    required this.action,
    required this.details,
    required this.performedBy,
    required this.performedByRole,
    required this.ipAddress,
    required this.timestamp,
  });
}

// Staff Wrappers
enum PortalType { issuer, verifier }

class LiveStaffRecord {
  final String id;
  final String name;
  final String email;
  final PortalType portal;
  final String role;
  final String addedDate;
  final String status;

  LiveStaffRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.portal,
    required this.role,
    required this.addedDate,
    required this.status,
  });
}

class OrgDirectoryRecord {
  final String name;
  final String email;

  OrgDirectoryRecord({required this.name, required this.email});

  factory OrgDirectoryRecord.fromJson(Map<String, dynamic> json) {
    return OrgDirectoryRecord(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }
}

// ─── API service ──────────────────────────────────────────────────────────────

class ApiService {
  static final _client = http.Client();

  // Connection state cache
  static bool _isConnected = false;
  static DateTime? _lastHealthCheck;

  // ─── SHARED DATE FORMATTER ─────────────────────────────────────────────────
  static String formatIsoDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      // Returns format: 15 Jun 2025
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso; // Fallback to raw string if parsing fails
    }
  }

  // GET /health
  static Future<bool> checkHealth() async {
    logDebug('[ApiService] checkHealth called');
    try {
      final res = await _client
          .get(Uri.parse('$kApiBaseUrl/health'))
          .timeout(const Duration(seconds: 15));
      _isConnected = res.statusCode == 200;
      _lastHealthCheck = DateTime.now();

      if (_isConnected) {
        logDebug('[ApiService] checkHealth success: API is reachable');
      } else {
        logDebug('[ApiService] checkHealth failed: HTTP ${res.statusCode}');
      }

      return _isConnected;
    } catch (e) {
      _isConnected = false;
      _lastHealthCheck = DateTime.now();
      logDebug('[ApiService] checkHealth exception: $e');
      return false;
    }
  }

  static Future<bool> _ensureConnection() async {
    final startTime = DateTime.now();
    while (true) {
      if (_lastHealthCheck != null &&
          DateTime.now().difference(_lastHealthCheck!).inSeconds < 10) {
        if (_isConnected) return true;
      } else {
        final ok = await checkHealth();
        if (ok) return true;
      }

      if (DateTime.now().difference(startTime).inSeconds >= 50) {
        return false;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  // POST /issueCredential
  static Future<IssueResult> issueCredential({
    required String holderEmiratesID,
    required String credentialType,
    required String info,
  }) async {
    logDebug(
      '[ApiService] issueCredential called for EID: $holderEmiratesID, type: $credentialType',
    );
    if (!await _ensureConnection()) {
      logDebug('[ApiService] issueCredential blocked: backend disconnected');
      return const IssueResult(
        success: false,
        credentialID: '',
        error: 'Backend is disconnected',
      );
    }
    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/issueCredential'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'holderEmiratesID': holderEmiratesID,
          'credentialType': credentialType,
          'info': info,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        logDebug(
          '[ApiService] issueCredential success: credentialID ${body['credentialID']}',
        );
        return IssueResult(
          success: true,
          credentialID: body['credentialID'] as String? ?? '',
        );
      }
      logDebug(
        '[ApiService] issueCredential failed: ${body['error'] as String? ?? 'Server error (${res.statusCode})'}',
      );
      return IssueResult(
        success: false,
        credentialID: '',
        error: body['error'] as String? ?? 'Server error (${res.statusCode})',
      );
    } catch (e) {
      logDebug('[ApiService] issueCredential exception: $e');
      return IssueResult(success: false, credentialID: '', error: e.toString());
    }
  }

  // POST /verifyCredential
  static Future<VerificationResult> verifyCredential(
    String credentialID,
  ) async {
    logDebug(
      '[ApiService] verifyCredential called for credentialID: $credentialID',
    );
    if (!await _ensureConnection()) {
      logDebug('[ApiService] verifyCredential blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/verifyCredential'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'credentialID': credentialID}),
      );

      if (res.statusCode == 200) {
        logDebug('[ApiService] verifyCredential success');
        return _parseVerifyResponse(
          jsonDecode(res.body) as Map<String, dynamic>,
          credentialID,
        );
      } else {
        logDebug(
          '[ApiService] verifyCredential failed: HTTP ${res.statusCode}',
        );
        throw ConnectionException('Server error (${res.statusCode})');
      }
    } catch (e) {
      logDebug('[ApiService] verifyCredential exception: $e');
      throw ConnectionException();
    }
  }

  // POST /resolveSession
  static Future<VerificationResult> resolveSession(String sessionToken) async {
    logDebug(
      '[ApiService] resolveSession called for sessionToken: $sessionToken',
    );
    if (!await _ensureConnection()) {
      logDebug('[ApiService] resolveSession blocked: backend disconnected');
      throw ConnectionException();
    }

    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/resolveSession'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sessionToken': sessionToken}),
      );

      if (res.statusCode == 404) {
        logDebug(
          '[ApiService] resolveSession failed: HTTP 404 (Session not found)',
        );
        throw Exception('Session not found or invalid code.');
      }
      if (res.statusCode == 400) {
        logDebug(
          '[ApiService] resolveSession failed: HTTP 400 (Session expired)',
        );
        throw Exception('Session expired. Please generate a new QR code.');
      }
      if (res.statusCode != 200) {
        logDebug('[ApiService] resolveSession failed: HTTP ${res.statusCode}');
        throw Exception('Failed to resolve session (HTTP ${res.statusCode})');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      logDebug('[ApiService] resolveSession success');

      return _parseVerifyResponse(body, body['credentialID'] as String? ?? '');
    } catch (e) {
      logDebug('[ApiService] resolveSession exception: $e');
      rethrow;
    }
  }

  // POST /revokeCredential
  static Future<bool> revokeCredential(String credentialID) async {
    logDebug(
      '[ApiService] revokeCredential called for credentialID: $credentialID',
    );
    if (!await _ensureConnection()) {
      logDebug('[ApiService] revokeCredential blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/revokeCredential'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'credentialID': credentialID}),
      );

      if (res.statusCode == 200) {
        logDebug('[ApiService] revokeCredential success');
        return true;
      } else {
        logDebug(
          '[ApiService] revokeCredential failed: HTTP ${res.statusCode}',
        );
        return false;
      }
    } catch (e) {
      logDebug('[ApiService] revokeCredential exception for $credentialID: $e');
      throw ConnectionException();
    }
  }

  static Future<List<CredentialRecord>> getAllCredentials({
    String? status,
    int page = 1,
    int limit = 25,
  }) async {
    logDebug(
      '[ApiService] getAllCredentials called (page: $page, limit: $limit, status: ${status ?? "all"})',
    );
    if (!await _ensureConnection()) {
      logDebug('[ApiService] getAllCredentials blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.get(
        Uri.parse('$kApiBaseUrl/getAllCredentials').replace(
          queryParameters: {
            'page': '$page',
            'limit': '$limit',
            if (status != null) 'status': status,
          },
        ),
      );
      if (res.statusCode != 200) {
        logDebug(
          '[ApiService] getAllCredentials failed: HTTP ${res.statusCode}',
        );
        return [];
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['credentials'] as List? ?? []);
      logDebug(
        '[ApiService] getAllCredentials success: fetched ${list.length} credentials',
      );

      return list
          .map((e) => _parseCredentialRecord(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logDebug('[ApiService] getAllCredentials exception: $e');
      throw ConnectionException();
    }
  }

  static Future<List<Map<String, dynamic>>> getCredentialsByHolder(
    String emiratesID,
  ) async {
    logDebug(
      '[ApiService] getCredentialsByHolder called for emiratesID: $emiratesID',
    );
    if (!await _ensureConnection()) {
      logDebug(
        '[ApiService] getCredentialsByHolder blocked: backend disconnected',
      );
      throw ConnectionException();
    }
    try {
      final res = await _client.get(
        Uri.parse('$kApiBaseUrl/getCredentialsByHolder?emiratesID=$emiratesID'),
      );
      if (res.statusCode != 200) {
        logDebug(
          '[ApiService] getCredentialsByHolder failed: HTTP ${res.statusCode}',
        );
        return [];
      }

      final body = jsonDecode(res.body);
      if (body is List) {
        logDebug(
          '[ApiService] getCredentialsByHolder success: fetched ${body.length} credentials',
        );
        return List<Map<String, dynamic>>.from(body);
      }
      if (body is Map && body['credentials'] is List) {
        logDebug(
          '[ApiService] getCredentialsByHolder success: fetched ${(body['credentials'] as List).length} credentials',
        );
        return List<Map<String, dynamic>>.from(body['credentials']);
      }

      logDebug(
        '[ApiService] getCredentialsByHolder failed: unexpected body structure',
      );
      return [];
    } catch (e) {
      logDebug('[ApiService] getCredentialsByHolder exception: $e');
      throw ConnectionException();
    }
  }

  // suspendCredential
  static Future<bool> suspendCredential(
    String credentialID, {
    String reason = '',
  }) async {
    logDebug(
      '[ApiService] suspendCredential called for credentialID: $credentialID, reason: $reason',
    );
    if (!await _ensureConnection()) {
      logDebug('[ApiService] suspendCredential blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/suspendCredential'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'credentialID': credentialID, 'reason': reason}),
      );

      if (res.statusCode == 200) {
        logDebug('[ApiService] suspendCredential success');
        return true;
      } else {
        logDebug(
          '[ApiService] suspendCredential failed: HTTP ${res.statusCode}',
        );
        return false;
      }
    } catch (e) {
      logDebug(
        '[ApiService] suspendCredential exception for $credentialID: $e',
      );
      throw ConnectionException();
    }
  }

  // restoreCredential
  static Future<bool> restoreCredential(String credentialID) async {
    logDebug(
      '[ApiService] restoreCredential called for credentialID: $credentialID',
    );
    if (!await _ensureConnection()) {
      logDebug('[ApiService] restoreCredential blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/restoreCredential'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'credentialID': credentialID}),
      );

      if (res.statusCode == 200) {
        logDebug('[ApiService] restoreCredential success');
        return true;
      } else {
        logDebug(
          '[ApiService] restoreCredential failed: HTTP ${res.statusCode}',
        );
        return false;
      }
    } catch (e) {
      logDebug(
        '[ApiService] restoreCredential exception for $credentialID: $e',
      );
      throw ConnectionException();
    }
  }

  //getHolderDetails
  static Future<List<HolderRecord>> getHolders({String search = ''}) async {
    logDebug('[ApiService] getHolders called with search term: "$search"');
    if (!await _ensureConnection()) {
      logDebug('[ApiService] getHolders blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.get(
        Uri.parse('$kApiBaseUrl/getHolders').replace(
          queryParameters: search.isNotEmpty ? {'search': search} : null,
        ),
      );
      if (res.statusCode != 200) {
        logDebug('[ApiService] getHolders failed: HTTP ${res.statusCode}');
        return [];
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['holders'] as List? ?? [];
      logDebug(
        '[ApiService] getHolders success: fetched ${list.length} holders',
      );

      return list
          .map((e) => _parseHolderRecord(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logDebug('[ApiService] getHolders exception: $e');
      throw ConnectionException();
    }
  }

  // verification history
  static Future<List<VerificationHistoryRecord>> getVerificationHistory({
    int page = 1,
    int limit = 25,
    String? result,
  }) async {
    logDebug(
      '[ApiService] getVerificationHistory called (page: $page, limit: $limit, result: ${result ?? "all"})',
    );
    if (!await _ensureConnection()) {
      logDebug(
        '[ApiService] getVerificationHistory blocked: backend disconnected',
      );
      throw ConnectionException();
    }
    try {
      final res = await _client.get(
        Uri.parse('$kApiBaseUrl/getVerificationHistory').replace(
          queryParameters: {
            'page': '$page',
            'limit': '$limit',
            if (result != null) 'result': result,
          },
        ),
      );
      if (res.statusCode != 200) {
        logDebug(
          '[ApiService] getVerificationHistory failed: HTTP ${res.statusCode}',
        );
        return [];
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['records'] as List? ?? [];
      logDebug(
        '[ApiService] getVerificationHistory success: fetched ${list.length} records',
      );

      return list
          .map(
            (e) => _parseVerificationHistoryRecord(e as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      logDebug('[ApiService] getVerificationHistory exception: $e');
      throw ConnectionException();
    }
  }

  //getDashboardStats
  static Future<Map<String, dynamic>> getDashboardStats() async {
    logDebug('[ApiService] getDashboardStats called');
    if (!await _ensureConnection()) {
      logDebug('[ApiService] getDashboardStats blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.get(
        Uri.parse('$kApiBaseUrl/getDashboardStats'),
      );
      if (res.statusCode != 200) {
        logDebug(
          '[ApiService] getDashboardStats failed: HTTP ${res.statusCode}',
        );
        return {};
      }

      logDebug('[ApiService] getDashboardStats success');
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      logDebug('[ApiService] getDashboardStats exception: $e');
      throw ConnectionException();
    }
  }

  //getCredentialDetail
  static Future<CredentialRecord?> getCredentialDetail(
    String credentialID,
  ) async {
    logDebug(
      '[ApiService] getCredentialDetail called for credentialID: $credentialID',
    );
    if (!await _ensureConnection()) {
      logDebug(
        '[ApiService] getCredentialDetail blocked: backend disconnected',
      );
      throw ConnectionException();
    }
    try {
      final res = await _client.get(
        Uri.parse(
          '$kApiBaseUrl/getCredentialDetail',
        ).replace(queryParameters: {'credentialID': credentialID}),
      );
      if (res.statusCode == 404) {
        logDebug('[ApiService] getCredentialDetail failed: HTTP 404');
        return null;
      }
      if (res.statusCode != 200) {
        logDebug(
          '[ApiService] getCredentialDetail failed: HTTP ${res.statusCode}',
        );
        return null;
      }

      logDebug('[ApiService] getCredentialDetail success');
      return _parseCredentialDetail(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    } catch (e) {
      logDebug('[ApiService] getCredentialDetail exception: $e');
      throw ConnectionException();
    }
  }

  //updateCredential
  static Future<bool> updateCredential({
    required String credentialID,
    required String holderEmail,
    String? expiryDate,
  }) async {
    logDebug(
      '[ApiService] updateCredential called for credentialID: $credentialID, email: $holderEmail',
    );
    if (!await _ensureConnection()) {
      logDebug('[ApiService] updateCredential blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/updateCredential'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'credentialID': credentialID,
          'holderEmail': holderEmail,
          'expiryDate': expiryDate,
        }),
      );
      if (res.statusCode != 200) {
        logDebug(
          '[ApiService] updateCredential failed: HTTP ${res.statusCode}',
        );
        return false;
      }

      logDebug('[ApiService] updateCredential success');
      return true;
    } catch (e) {
      logDebug('[ApiService] updateCredential exception: $e');
      throw ConnectionException();
    }
  }

  //getVerificationDetail
  static Future<VerificationDetailData?> getVerificationDetail(
    String id,
  ) async {
    logDebug('[ApiService] getVerificationDetail called for ID: $id');
    if (!await _ensureConnection()) {
      logDebug(
        '[ApiService] getVerificationDetail blocked: backend disconnected',
      );
      throw ConnectionException();
    }
    try {
      final res = await _client.get(
        Uri.parse(
          '$kApiBaseUrl/getVerificationDetail',
        ).replace(queryParameters: {'id': id}),
      );
      if (res.statusCode == 404) {
        logDebug('[ApiService] getVerificationDetail failed: HTTP 404');
        return null;
      }
      if (res.statusCode != 200) {
        logDebug(
          '[ApiService] getVerificationDetail failed: HTTP ${res.statusCode}',
        );
        return null;
      }

      logDebug('[ApiService] getVerificationDetail success');
      return _parseVerificationDetail(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    } catch (e) {
      logDebug('[ApiService] getVerificationDetail exception: $e');
      throw ConnectionException();
    }
  }

  // --- SUBSCRIPTIONS ---

  static Future<bool> requestSubscription(String credentialID) async {
    logDebug(
      '[ApiService] requestSubscription called for credentialID: $credentialID',
    );
    if (!await _ensureConnection()) {
      logDebug(
        '[ApiService] requestSubscription blocked: backend disconnected',
      );
      throw ConnectionException();
    }
    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/requestSubscription'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'credentialID': credentialID}),
      );
      if (res.statusCode != 200) {
        logDebug(
          '[ApiService] requestSubscription failed: HTTP ${res.statusCode}',
        );
        return false;
      }

      logDebug('[ApiService] requestSubscription success');
      return true;
    } catch (e) {
      logDebug('[ApiService] requestSubscription exception: $e');
      throw ConnectionException();
    }
  }

  // getSubscriptions
  static Future<List<SubscriptionRecord>> getSubscriptions({
    int page = 1,
    int limit = 100,
  }) async {
    logDebug(
      '[ApiService] getSubscriptions called (page: $page, limit: $limit)',
    );
    if (!await _ensureConnection()) {
      logDebug('[ApiService] getSubscriptions blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.get(
        Uri.parse('$kApiBaseUrl/getSubscriptions?page=$page&limit=$limit'),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = body['subscriptions'] as List? ?? [];
        logDebug(
          '[ApiService] getSubscriptions success: fetched ${list.length} subscriptions',
        );
        return list
            .map((e) => _parseSubscriptionRecord(e as Map<String, dynamic>))
            .toList();
      }
      logDebug('[ApiService] getSubscriptions failed: HTTP ${res.statusCode}');
      return [];
    } catch (e) {
      logDebug('[ApiService] getSubscriptions exception: $e');
      throw ConnectionException();
    }
  }

  // deleteSubscription
  static Future<bool> deleteSubscription(String subscriptionID) async {
    logDebug(
      '[ApiService] deleteSubscription called for subscriptionID: $subscriptionID',
    );
    if (!await _ensureConnection()) {
      logDebug('[ApiService] deleteSubscription blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/deleteSubscription'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'subscriptionID': subscriptionID}),
      );
      if (res.statusCode != 200) {
        logDebug(
          '[ApiService] deleteSubscription failed: HTTP ${res.statusCode}',
        );
        return false;
      }

      logDebug('[ApiService] deleteSubscription success');
      return true;
    } catch (e) {
      logDebug('[ApiService] deleteSubscription exception: $e');
      throw ConnectionException();
    }
  }

  // unsubscribe
  static Future<bool> unsubscribe(String subscriptionID) async {
    logDebug(
      '[ApiService] unsubscribe called for subscriptionID: $subscriptionID',
    );
    if (!await _ensureConnection()) {
      logDebug('[ApiService] unsubscribe blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/unsubscribe'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'subscriptionID': subscriptionID}),
      );
      if (res.statusCode != 200) {
        logDebug('[ApiService] unsubscribe failed: HTTP ${res.statusCode}');
        return false;
      }

      logDebug('[ApiService] unsubscribe success');
      return true;
    } catch (e) {
      logDebug('[ApiService] unsubscribe exception: $e');
      throw ConnectionException();
    }
  }

  // --- ALERTS (NEW) ---

  static Future<List<LiveAlertRecord>> getSubscriptionAlerts() async {
    logDebug('[ApiService] getSubscriptionAlerts called');
    if (!await _ensureConnection()) {
      logDebug(
        '[ApiService] getSubscriptionAlerts blocked: backend disconnected',
      );
      throw ConnectionException();
    }
    try {
      final res = await _client.get(
        Uri.parse('$kApiBaseUrl/getSubscriptionAlerts'),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = body['alerts'] as List? ?? [];
        logDebug(
          '[ApiService] getSubscriptionAlerts success: fetched ${list.length} alerts',
        );
        return list
            .map((e) => _parseAlertRecord(e as Map<String, dynamic>))
            .toList();
      }
      logDebug(
        '[ApiService] getSubscriptionAlerts failed: HTTP ${res.statusCode}',
      );
      return [];
    } catch (e) {
      logDebug('[ApiService] getSubscriptionAlerts exception: $e');
      throw ConnectionException();
    }
  }

  // acknowledgeAlert
  static Future<bool> acknowledgeAlert(String alertID) async {
    logDebug('[ApiService] acknowledgeAlert called for alertID: $alertID');
    if (!await _ensureConnection()) {
      logDebug('[ApiService] acknowledgeAlert blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/acknowledgeAlert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'alertID': alertID}),
      );
      if (res.statusCode != 200) {
        logDebug(
          '[ApiService] acknowledgeAlert failed: HTTP ${res.statusCode}',
        );
        return false;
      }

      logDebug('[ApiService] acknowledgeAlert success');
      return true;
    } catch (e) {
      logDebug('[ApiService] acknowledgeAlert exception: $e');
      throw ConnectionException();
    }
  }

  //IT ADMINS

  // getAuditLogs
  static Future<List<LiveAuditLogRecord>> getAuditLogs({
    int page = 1,
    int limit = 500,
  }) async {
    logDebug('[ApiService] getAuditLogs called (page: $page, limit: $limit)');
    if (!await _ensureConnection()) {
      logDebug('[ApiService] getAuditLogs blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.get(
        Uri.parse('$kApiBaseUrl/getAuditLogs?page=$page&limit=$limit'),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = body['records'] as List? ?? [];
        logDebug(
          '[ApiService] getAuditLogs success: fetched ${list.length} records',
        );
        return list
            .map((e) => _parseAuditLogRecord(e as Map<String, dynamic>))
            .toList();
      }
      logDebug('[ApiService] getAuditLogs failed: HTTP ${res.statusCode}');
      return [];
    } catch (e) {
      logDebug('[ApiService] getAuditLogs exception: $e');
      throw ConnectionException();
    }
  }

  // getStaff
  static Future<List<LiveStaffRecord>> getStaff() async {
    logDebug('[ApiService] getStaff called');
    if (!await _ensureConnection()) {
      logDebug('[ApiService] getStaff blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.get(Uri.parse('$kApiBaseUrl/getStaff'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = body['staff'] as List? ?? [];
        logDebug(
          '[ApiService] getStaff success: fetched ${list.length} staff members',
        );
        return list
            .map((e) => _parseStaffRecord(e as Map<String, dynamic>))
            .toList();
      }
      logDebug('[ApiService] getStaff failed: HTTP ${res.statusCode}');
      return [];
    } catch (e) {
      logDebug('[ApiService] getStaff exception: $e');
      throw ConnectionException();
    }
  }

  // inviteStaff
  static Future<bool> inviteStaff({
    required String email,
    required PortalType portal,
    required String role,
  }) async {
    logDebug(
      '[ApiService] inviteStaff called for email: $email, portal: ${portal.name}, role: $role',
    );
    if (!await _ensureConnection()) {
      logDebug('[ApiService] inviteStaff blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/inviteStaff'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'portal': portal.name, 'role': role}),
      );
      if (res.statusCode != 200) {
        logDebug('[ApiService] inviteStaff failed: HTTP ${res.statusCode}');
        return false;
      }

      logDebug('[ApiService] inviteStaff success');
      return true;
    } catch (e) {
      logDebug('[ApiService] inviteStaff exception: $e');
      throw ConnectionException();
    }
  }

  // updateStaffRole
  static Future<bool> updateStaffRole({
    required String id,
    required PortalType portal,
    required String role,
  }) async {
    logDebug(
      '[ApiService] updateStaffRole called for staffID: $id, portal: ${portal.name}, role: $role',
    );
    if (!await _ensureConnection()) {
      logDebug('[ApiService] updateStaffRole blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/updateStaffRole'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'portal': portal.name, 'role': role}),
      );
      if (res.statusCode != 200) {
        logDebug('[ApiService] updateStaffRole failed: HTTP ${res.statusCode}');
        return false;
      }

      logDebug('[ApiService] updateStaffRole success');
      return true;
    } catch (e) {
      logDebug('[ApiService] updateStaffRole exception: $e');
      throw ConnectionException();
    }
  }

  // deleteStaff
  static Future<bool> deleteStaff({
    required String id,
    required PortalType portal,
  }) async {
    logDebug(
      '[ApiService] deleteStaff called for staffID: $id, portal: ${portal.name}',
    );
    if (!await _ensureConnection()) {
      logDebug('[ApiService] deleteStaff blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/deleteStaff'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'portal': portal.name}),
      );
      if (res.statusCode != 200) {
        logDebug('[ApiService] deleteStaff failed: HTTP ${res.statusCode}');
        return false;
      }

      logDebug('[ApiService] deleteStaff success');
      return true;
    } catch (e) {
      logDebug('[ApiService] deleteStaff exception: $e');
      throw ConnectionException();
    }
  }

  static Future<List<OrgDirectoryRecord>> getOrgDirectory() async {
    logDebug('[ApiService] getOrgDirectory called');
    if (!await _ensureConnection()) throw ConnectionException();

    try {
      final res = await _client.get(Uri.parse('$kApiBaseUrl/getDirectory'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = body['directory'] as List? ?? [];
        return list.map((e) => OrgDirectoryRecord.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      logDebug('[ApiService] getOrgDirectory exception: $e');
      throw ConnectionException();
    }
  }

  // ── parsers ───────────────────────────────────────────────────────────────

  static LiveAlertRecord _parseAlertRecord(Map<String, dynamic> e) {
    return LiveAlertRecord(
      id: e['id'] as String? ?? '',
      credentialID: e['credentialID'] as String? ?? '',
      holderName: e['holderName'] as String? ?? '',
      credentialName: e['credentialName'] as String? ?? '',
      severity: _parseAlertSeverity(e['severity'] as String? ?? 'revoked'),
      description: e['description'] as String? ?? '',
      dateTime: e['dateTime'] as String? ?? '',
      acknowledged: e['acknowledged'] as bool? ?? false,
    );
  }

  static AlertSeverity _parseAlertSeverity(String s) {
    switch (s.toLowerCase()) {
      case 'revoked':
        return AlertSeverity.revoked;
      case 'expired':
        return AlertSeverity.expired;
      case 'suspended':
        return AlertSeverity.suspended;
      case 'tampered':
        return AlertSeverity.tampered;
      case 'renewed':
        return AlertSeverity.renewed;
      case 'reissued':
        return AlertSeverity.reissued;
      default:
        return AlertSeverity.revoked;
    }
  }

  static CredentialRecord _parseCredentialRecord(Map<String, dynamic> e) {

    final rawExpiry = e['expiryDate'] as String?;

    return CredentialRecord(
      id: e['credentialID'] as String? ?? '',
      holderName: e['holderName'] as String? ?? '',
      holderEmail: e['holderEmail'] as String? ?? '',
      holderId: e['holderID'] as String? ?? '',
      holderEmiratesID: e['holderEID'] as String? ?? '',
      credentialType: e['credentialType'] as String? ?? '',
      issuedBy: e['issuedBy'] as String? ?? '',
      issueDate: e['issuedAt'] as String? ?? '',
      // expiryDate: e['expiryDate'] as String?,
      expiryDate: (rawExpiry != null && rawExpiry.trim().isNotEmpty)
          ? rawExpiry
          : null,
      status: _parseStatus(e['status'] as String? ?? ''),
      auditTrail: const [],
      attributes: const {},
    );
  }

  static HolderRecord _parseHolderRecord(Map<String, dynamic> e) {
    return HolderRecord(
      id: e['holderID'] as String? ?? '',
      fullName: e['fullName'] as String? ?? '',
      email: e['email'] as String? ?? '',
      emiratesID: e['emiratesID'] as String? ?? '',
      type: _parseHolderType(e['type'] as String? ?? ''),
      college: e['college'] as String? ?? '',
    );
  }

  static VerificationHistoryRecord _parseVerificationHistoryRecord(
    Map<String, dynamic> e,
  ) {
    final dt =
        DateTime.tryParse(e['verifiedAt'] as String? ?? '') ?? DateTime.now();
    return VerificationHistoryRecord(
      id: e['id'] as String? ?? '',
      credID: e['credentialID'] as String? ?? '',
      date:
          '${dt.day.toString().padLeft(2, '0')} ${_monthName(dt.month)} ${dt.year}',
      time:
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
      credentialType: e['credentialType'] as String? ?? '',
      holderName: e['holderName'] as String? ?? '',
      issuerName: e['issuerName'] as String? ?? '',
      result: _parseVerifyResult(e['result'] as String? ?? ''),
      method: _parseVerifyMethod(e['method'] as String? ?? ''),
      verifiedBy: e['verifiedBy'] as String? ?? '',
    );
  }

  static VerificationDetailData _parseVerificationDetail(
    Map<String, dynamic> e,
  ) {
    final dt =
        DateTime.tryParse(e['verifiedAt'] as String? ?? '') ?? DateTime.now();
    final resultStr = e['result'] as String? ?? '';
    final reasonStr = e['reason'] as String?;
    final verifyResult = _parseVerifyResult(resultStr);

    final historyRecord = VerificationHistoryRecord(
      id: e['id'] as String? ?? '',
      credID: e['credentialID'] as String? ?? '',
      date:
          '${dt.day.toString().padLeft(2, '0')} ${_monthName(dt.month)} ${dt.year}',
      time:
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
      credentialType: e['credentialType'] as String? ?? '',
      holderName: e['holderName'] as String? ?? '',
      issuerName: e['issuerName'] as String? ?? '',
      result: verifyResult,
      method: _parseVerifyMethod(e['method'] as String? ?? ''),
      verifiedBy: e['verifiedBy'] as String? ?? '',
    );

    final rawExpiry = e['expiryDate'] as String?;

    final cred = CredentialRecord(
      id: e['credentialID'] as String? ?? '',
      holderName: e['holderName'] as String? ?? '',
      holderEmail: '',
      holderId: e['holderID'] as String? ?? '',
      holderEmiratesID: '',
      credentialType: e['credentialType'] as String? ?? '',
      issuedBy: e['issuerName'] as String? ?? '',
      issueDate: formatIsoDate(e['issuedAt'] as String? ?? ''),
      // expiryDate: formatIsoDate(e['expiryDate'] as String?),
      expiryDate: (rawExpiry != null && rawExpiry.trim().isNotEmpty)
          ? formatIsoDate(rawExpiry)
          : null,
      status: _parseStatusFromVerifyResult(verifyResult),
      auditTrail: const [],
      attributes: const {},
    );

    final InvalidReason? invalidReason = verifyResult == VerifyResult.valid
        ? null
        : _parseInvalidReason(resultStr, reasonStr);
    final checks = (e['checks'] as Map?)?.cast<String, dynamic>() ?? {};

    final policyChecks = [
      PolicyCheck(
        label: 'Exists on Blockchain',
        passed:
            checks['existsOnChain'] as bool? ??
            (invalidReason != InvalidReason.notFound),
      ),
      PolicyCheck(
        label: 'Not Revoked',
        passed:
            checks['notRevoked'] as bool? ??
            (invalidReason != InvalidReason.revoked &&
                invalidReason != InvalidReason.suspended),
      ),
      PolicyCheck(
        label: 'Signature Valid (ML-DSA-44)',
        passed:
            checks['signatureValid'] as bool? ??
            (invalidReason != InvalidReason.tampered),
      ),
      PolicyCheck(
        label: 'Hash Matches',
        passed:
            checks['hashMatches'] as bool? ??
            (invalidReason != InvalidReason.tampered),
      ),
    ];

    final result = VerificationResult(
      invalidReason: invalidReason,
      credential: cred,
      policyChecks: policyChecks,
      verifiedAt: e['verifiedAt'] as String? ?? dt.toString(),
    );

    return VerificationDetailData(historyRecord: historyRecord, result: result);
  }

  static HolderType _parseHolderType(String s) {
    switch (s) {
      case 'masterStudent':
        return HolderType.masterStudent;
      case 'phdStudent':
        return HolderType.phdStudent;
      case 'employee':
        return HolderType.employee;
      case 'medical':
        return HolderType.medical;
      default:
        return HolderType.bachelorStudent;
    }
  }

  static VerifyResult _parseVerifyResult(String s) {
    switch (s) {
      case 'revoked':
        return VerifyResult.revoked;
      case 'suspended':
        return VerifyResult.suspended;
      case 'expired':
        return VerifyResult.expired;
      case 'tampered':
        return VerifyResult.tampered;
      case 'notFound':
        return VerifyResult.notFound;
      default:
        return VerifyResult.valid;
    }
  }

  static VerifyMethod _parseVerifyMethod(String s) {
    switch (s) {
      case 'qrScan':
        return VerifyMethod.qrScan;
      case 'fileUpload':
        return VerifyMethod.fileUpload;
      case 'batch':
        return VerifyMethod.batch;
      default:
        return VerifyMethod.manual;
    }
  }

  static InvalidReason _parseInvalidReason(
    String resultStr,
    String? reasonStr,
  ) {
    if (reasonStr != null) {
      switch (reasonStr.toUpperCase()) {
        case 'REVOKED':
          return InvalidReason.revoked;
        case 'SUSPENDED':
          return InvalidReason.suspended;
        case 'EXPIRED':
          return InvalidReason.expired;
        case 'TAMPERED':
          return InvalidReason.tampered;
        case 'NOT_FOUND':
          return InvalidReason.notFound;
      }
    }
    switch (resultStr) {
      case 'revoked':
        return InvalidReason.revoked;
      case 'suspended':
        return InvalidReason.suspended;
      case 'expired':
        return InvalidReason.expired;
      case 'tampered':
        return InvalidReason.tampered;
      default:
        return InvalidReason.notFound;
    }
  }

  static CredentialStatus _parseStatusFromVerifyResult(VerifyResult vr) {
    switch (vr) {
      case VerifyResult.revoked:
        return CredentialStatus.revoked;
      case VerifyResult.suspended:
        return CredentialStatus.suspended;
      case VerifyResult.expired:
        return CredentialStatus.expired;
      default:
        return CredentialStatus.valid;
    }
  }

  static String _monthName(int m) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[m - 1];
  }

  static VerificationResult _parseVerifyResponse(
    Map<String, dynamic> body,
    String credentialID,
  ) {
    final verified = body['verified'] as bool? ?? false;
    final credType = body['credentialType'] as String? ?? '';
    final holderName = body['holderName'] as String? ?? '';
    final issuedAt = body['issuedAt'] as String? ?? '';
    //final expiryDate = body['expiryDate'] as String? ?? '';
    final issuer = body['issuer'] as String? ?? 'University of Sharjah';
    final status = body['status'] as String? ?? '';
    final credData =
        (body['credentialData'] as Map?)?.cast<String, dynamic>() ?? {};
    final attributes = credData.map((k, v) => MapEntry(k, v?.toString() ?? ''));

    final cred = CredentialRecord(
      holderEmiratesID: body['holderEID'] as String? ?? '',
      id: body['credentialID'] as String? ?? credentialID,
      holderName: holderName,
      holderEmail: body['holderEmail'] as String? ?? '',
      holderId: body['holderID'] as String? ?? '',
      credentialType: credType,
      issuedBy: issuer,
      issueDate: formatIsoDate(issuedAt),
      //expiryDate: expiryDate != null ? formatIsoDate(expiryDate) : null,
      status: _parseStatus(status),
      auditTrail: const [],
      attributes: attributes,
    );

    if (!verified) {
      final reason = body['reason'] as String?;
      InvalidReason invalidReason;
      if (reason == 'REVOKED') {
        invalidReason = InvalidReason.revoked;
      } else if (reason == 'SUSPENDED')
        invalidReason = InvalidReason.suspended;
      else if (reason == 'EXPIRED')
        invalidReason = InvalidReason.expired;
      else if (reason == 'TAMPERED')
        invalidReason = InvalidReason.tampered;
      else
        invalidReason = InvalidReason.notFound;

      return VerificationResult(
        invalidReason: invalidReason,
        credential: cred,
        policyChecks: const [],
        verifiedAt: DateTime.now().toString(),
      );
    }

    final checks = (body['checks'] as Map?)?.cast<String, dynamic>() ?? {};
    final policyChecks = [
      PolicyCheck(
        label: 'Exists on Blockchain',
        passed: checks['existsOnChain'] as bool? ?? false,
      ),
      PolicyCheck(
        label: 'Not Revoked',
        passed: checks['notRevoked'] as bool? ?? false,
      ),
      PolicyCheck(
        label: 'Signature Valid (ML-DSA-44)',
        passed: checks['signatureValid'] as bool? ?? false,
      ),
      PolicyCheck(
        label: 'Hash Matches',
        passed: checks['hashMatches'] as bool? ?? false,
      ),
    ];

    return VerificationResult(
      invalidReason: null,
      credential: cred,
      policyChecks: policyChecks,
      verifiedAt: DateTime.now().toString(),
    );
  }

  static CredentialStatus _parseStatus(String s) {
    switch (s.toLowerCase()) {
      case 'revoked':
        return CredentialStatus.revoked;
      case 'suspended':
        return CredentialStatus.suspended;
      case 'expired':
        return CredentialStatus.expired;
      default:
        return CredentialStatus.valid;
    }
  }

  static CredentialRecord _parseCredentialDetail(Map<String, dynamic> e) {
    final rawTrail = e['auditTrail'] as List? ?? [];
    final auditTrail = rawTrail.map((entry) {
      final m = entry as Map<String, dynamic>;
      return AuditEntry(
        date: m['date'] as String? ?? '',
        action: m['action'] as String? ?? '',
        performedBy: m['performedBy'] as String? ?? '',
        note: m['note'] as String?,
      );
    }).toList();

    return CredentialRecord(
      id: e['credentialID'] as String? ?? '',
      holderName: e['holderName'] as String? ?? '',
      holderEmail: e['holderEmail'] as String? ?? '',
      holderId: e['holderID'] as String? ?? '',
      holderEmiratesID: e['holderEID'] as String? ?? '',
      credentialType: e['credentialType'] as String? ?? '',
      issuedBy: e['issuedBy'] as String? ?? '',
      issueDate: e['issuedAt'] as String? ?? '',
      expiryDate: e['expiryDate'] as String?,
      status: _parseStatus(e['status'] as String? ?? ''),
      auditTrail: auditTrail,
      attributes: const {},
    );
  }

  static SubscriptionRecord _parseSubscriptionRecord(Map<String, dynamic> e) {
    return SubscriptionRecord(
      id: e['id'] as String? ?? '',
      credentialID: e['credentialID'] as String? ?? '',
      holderName: e['holderName'] as String? ?? '',
      holderId: e['holderID'] as String? ?? '',
      credentialType: e['credentialType'] as String? ?? '',
      issuer: e['issuer'] as String? ?? '',
      subscribedDate: e['subscribedDate'] as String? ?? '—',
      expiryDate: e['expiryDate'] as String? ?? '—',
      status: _parseSubStatus(e['status'] as String? ?? 'pending'),
    );
  }

  static SubStatus _parseSubStatus(String s) {
    switch (s.toLowerCase()) {
      case 'active':
        return SubStatus.active;
      case 'unsubscribed':
        return SubStatus.unsubscribed;
      case 'rejected':
        return SubStatus.rejected;
      case 'expired':
        return SubStatus.expired;
      default:
        return SubStatus.pending;
    }
  }

  static LiveAuditLogRecord _parseAuditLogRecord(Map<String, dynamic> e) {
    // Convert ISO to human readable so it looks nice in the UI table
    final dt =
        DateTime.tryParse(e['timestamp'] as String? ?? '') ?? DateTime.now();
    final formattedTime =
        '${dt.day.toString().padLeft(2, '0')} ${_monthName(dt.month)} ${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return LiveAuditLogRecord(
      id: e['id'] as String? ?? '',
      action: _parseAuditAction(e['action'] as String? ?? ''),
      details: e['details'] as String? ?? '',
      performedBy: e['performedBy'] as String? ?? '',
      performedByRole: e['performedByRole'] as String? ?? '',
      ipAddress: e['ipAddress'] as String? ?? '',
      timestamp: formattedTime,
    );
  }

  static LiveAuditAction _parseAuditAction(String s) {
    switch (s.toLowerCase()) {
      case 'issued':
        return LiveAuditAction.issued;
      case 'revoked':
        return LiveAuditAction.revoked;
      case 'suspended':
        return LiveAuditAction.suspended;
      case 'verified':
        return LiveAuditAction.verified;
      case 'policy_changed':
        return LiveAuditAction.policy;
      case 'system_config':
        return LiveAuditAction.system;
      default:
        return LiveAuditAction.error;
    }
  }

  static LiveStaffRecord _parseStaffRecord(Map<String, dynamic> e) {
    return LiveStaffRecord(
      id: e['id'] as String? ?? '',
      name: e['name'] as String? ?? '',
      email: e['email'] as String? ?? '',
      portal: (e['portal'] as String? ?? '') == 'verifier'
          ? PortalType.verifier
          : PortalType.issuer,
      role: e['role'] as String? ?? '',
      addedDate: e['addedDate'] as String? ?? '',
      status: e['status'] as String? ?? 'invited',
    );
  }
}
