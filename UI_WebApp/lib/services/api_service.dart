import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qportal_webapp/utils/app_config.dart';
import 'package:qportal_webapp/models/verifiying_models.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/utils/logger.dart';

// ─── Issue result ─────────────────────────────────────────────────────────────

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

// ─── API service ──────────────────────────────────────────────────────────────

class ApiService {
  static final _client = http.Client();

  // Connection state cache
  static bool _isConnected = false;
  static DateTime? _lastHealthCheck;

  // GET /health
  static Future<bool> checkHealth() async {
    try {
      final res = await _client
          .get(Uri.parse('$kApiBaseUrl/health'))
          .timeout(const Duration(seconds: 15)); // 15 second timeout

      _isConnected = res.statusCode == 200;
      _lastHealthCheck = DateTime.now();
      return _isConnected;
    } catch (_) {
      _isConnected = false;
      _lastHealthCheck = DateTime.now();
      return false; // Returns false on timeout, socket exception, or 500 error
    }
  }

  // Internal helper to prevent API calls if backend is disconnected.
  // Uses cached result if checked within the last 10 seconds.
  static Future<bool> _ensureConnection() async {
    if (_lastHealthCheck != null &&
        DateTime.now().difference(_lastHealthCheck!).inSeconds < 10) {
      return _isConnected;
    }
    return await checkHealth();
  }

  // POST /issueCredential
  static Future<IssueResult> issueCredential({
    required String holderEmiratesID,
    required String credentialType,
    required String info,
  }) async {
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
    if (!await _ensureConnection()) {
      logDebug('[ApiService] verifyCredential blocked: backend disconnected');
      return VerificationResult(
        invalidReason: InvalidReason.notFound,
        credential: null,
        policyChecks: const [],
        verifiedAt: DateTime.now().toString(),
      );
    }

    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/verifyCredential'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'credentialID': credentialID}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return _parseVerifyResponse(body, credentialID);
    } catch (e) {
      logDebug('[ApiService] verifyCredential exception: $e');
      return VerificationResult(
        invalidReason: InvalidReason.notFound,
        credential: null,
        policyChecks: const [],
        verifiedAt: DateTime.now().toString(),
      );
    }
  }

  // POST /revokeCredential
  static Future<bool> revokeCredential(String credentialID) async {
    if (!await _ensureConnection()) {
      logDebug('[ApiService] revokeCredential blocked: backend disconnected');
      return false;
    }

    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/revokeCredential'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'credentialID': credentialID}),
      );
      return res.statusCode == 200;
    } catch (_) {
      logDebug('[ApiService] revokeCredential exception for $credentialID');
      return false;
    }
  }

  // GET /getCredentialsByHolder?emiratesID=...
  static Future<List<Map<String, dynamic>>> getCredentialsByHolder(
    String emiratesID,
  ) async {
    if (!await _ensureConnection()) {
      logDebug('[ApiService] getCredentialsByHolder blocked: backend disconnected');
      return [];
    }

    try {
      final res = await _client.get(
        Uri.parse('$kApiBaseUrl/getCredentialsByHolder?emiratesID=$emiratesID'),
      );
      if (res.statusCode != 200) {
        logDebug('[ApiService] getCredentialsByHolder failed: HTTP ${res.statusCode}');
        return [];
      }
      final body = jsonDecode(res.body);
      if (body is List) return List<Map<String, dynamic>>.from(body);
      if (body is Map && body['credentials'] is List) {
        return List<Map<String, dynamic>>.from(body['credentials']);
      }
      logDebug('[ApiService] getCredentialsByHolder returned unexpected body');
      return [];
    } catch (_) {
      logDebug('[ApiService] getCredentialsByHolder exception');
      return [];
    }
  }

  //Get /getAllCredentials?page=1&limit=25&status=valid
  static Future<List<CredentialRecord>> getAllCredentials({
    String? status,
    int page = 1,
    int limit = 25,
  }) async {
    if (!await _ensureConnection()) {
      logDebug('[ApiService] getAllCredentials blocked: backend disconnected');
      return [];
    }

    try {
      final params = <String, String>{
        'page': '$page',
        'limit': '$limit',
        if (status != null) 'status': status,
      };
      final res = await _client.get(
        Uri.parse(
          '$kApiBaseUrl/getAllCredentials',
        ).replace(queryParameters: params),
      );
      if (res.statusCode != 200) {
        logDebug('[ApiService] getAllCredentials failed: HTTP ${res.statusCode}');
        return [];
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['credentials'] as List? ?? []);
      return list
          .map((e) => _parseCredentialRecord(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      logDebug('[ApiService] getAllCredentials exception');
      return [];
    }
  }

  // suspendCredential
  static Future<bool> suspendCredential(
    String credentialID, {
    String reason = '',
  }) async {
    if (!await _ensureConnection()) {
      logDebug('[ApiService] suspendCredential blocked: backend disconnected');
      return false;
    }

    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/suspendCredential'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'credentialID': credentialID, 'reason': reason}),
      );
      return res.statusCode == 200;
    } catch (_) {
      logDebug('[ApiService] suspendCredential exception for $credentialID');
      return false;
    }
  }

  // restoreCredential
  static Future<bool> restoreCredential(String credentialID) async {
    if (!await _ensureConnection()) {
      logDebug('[ApiService] restoreCredential blocked: backend disconnected');
      return false;
    }

    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/restoreCredential'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'credentialID': credentialID}),
      );
      return res.statusCode == 200;
    } catch (_) {
      logDebug('[ApiService] restoreCredential exception for $credentialID');
      return false;
    }
  }

  //getHolderDetails
  static Future<List<HolderRecord>> getHolders({String search = ''}) async {
    if (!await _ensureConnection()) {
      logDebug('[ApiService] getHolders blocked: backend disconnected');
      return [];
    }

    try {
      final uri = Uri.parse(
        '$kApiBaseUrl/getHolders',
      ).replace(queryParameters: search.isNotEmpty ? {'search': search} : null);
      final res = await _client.get(uri);
      if (res.statusCode != 200) {
        logDebug('[ApiService] getHolders failed: HTTP ${res.statusCode}');
        return [];
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['holders'] as List? ?? [];
      return list
          .map((e) => _parseHolderRecord(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      logDebug('[ApiService] getHolders exception');
      return [];
    }
  }

  // verification history
  static Future<List<VerificationHistoryRecord>> getVerificationHistory({
    int page = 1,
    int limit = 25,
    String? result,
  }) async {
    if (!await _ensureConnection()) {
      logDebug('[ApiService] getVerificationHistory blocked: backend disconnected');
      return [];
    }

    try {
      final params = <String, String>{
        'page': '$page',
        'limit': '$limit',
        if (result != null) 'result': result,
      };
      final res = await _client.get(
        Uri.parse(
          '$kApiBaseUrl/getVerificationHistory',
        ).replace(queryParameters: params),
      );
      if (res.statusCode != 200) {
        logDebug('[ApiService] getVerificationHistory failed: HTTP ${res.statusCode}');
        return [];
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['records'] as List? ?? [];
      return list
          .map(
            (e) => _parseVerificationHistoryRecord(e as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      logDebug('[ApiService] getVerificationHistory exception');
      return [];
    }
  }

  //getDashboardStats
  static Future<Map<String, dynamic>> getDashboardStats() async {
    if (!await _ensureConnection()) {
      logDebug('[ApiService] getDashboardStats blocked: backend disconnected');
      return {};
    }

    try {
      final res = await _client.get(
        Uri.parse('$kApiBaseUrl/getDashboardStats'),
      );
      if (res.statusCode != 200) {
        logDebug('[ApiService] getDashboardStats failed: HTTP ${res.statusCode}');
        return {};
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      logDebug('[ApiService] getDashboardStats exception');
      return {};
    }
  }

  // parsers

  // Converts a JSON map from /getAllCredentials into a CredentialRecord
  static CredentialRecord _parseCredentialRecord(Map<String, dynamic> e) {
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
      auditTrail: const [],
      attributes: const {},
    );
  }

  // Converts a JSON map from /getHolders into a HolderRecord
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

  // Converts a JSON map from /getVerificationHistory into a VerificationHistoryRecord
  static VerificationHistoryRecord _parseVerificationHistoryRecord(
    Map<String, dynamic> e,
  ) {
    final dt =
        DateTime.tryParse(e['verifiedAt'] as String? ?? '') ?? DateTime.now();
    return VerificationHistoryRecord(
      id: e['id'] as String? ?? '',
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
    final issuer = body['issuer'] as String? ?? 'University of Sharjah';
    final status = body['status'] as String? ?? '';
    final credData =
        (body['credentialData'] as Map?)?.cast<String, dynamic>() ?? {};
    final attributes = credData.map((k, v) => MapEntry(k, v?.toString() ?? ''));

    final cred = CredentialRecord(
      holderEmiratesID: body['holderEID'] as String? ?? '',
      id: body['credentialID'] as String? ?? credentialID,
      holderName: holderName,
      holderEmail: '',
      holderId: body['holderID'] as String? ?? '',
      credentialType: credType,
      issuedBy: issuer,
      issueDate: issuedAt,
      status: _parseStatus(status),
      auditTrail: const [],
      attributes: attributes,
    );

    if (!verified) {
      final reason = body['reason'] as String?;
      InvalidReason invalidReason;
      if (reason == 'REVOKED') {
        invalidReason = InvalidReason.revoked;
      } else if (reason == 'SUSPENDED') {
        invalidReason = InvalidReason.suspended;
      } else if (reason == 'EXPIRED') {
        invalidReason = InvalidReason.expired;
      } else if (reason == 'TAMPERED') {
        invalidReason = InvalidReason.tampered;
      } else {
        invalidReason = InvalidReason.notFound;
      }
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
}
