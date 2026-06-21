import 'dart:convert';
import 'package:qportal_webapp/models/ISSUER/issueResult_model.dart';
import 'package:qportal_webapp/models/ISSUER/credentials_model.dart';
import 'package:qportal_webapp/services/core_api.dart';
import 'package:qportal_webapp/utils/webApp_config.dart';
import 'package:qportal_webapp/utils/logger.dart';


class IssuerApi {

  
  // POST /issueCredential
  static Future<IssueResult> issueCredential({
    required String holderEmiratesID,
    required String credentialType,
    required String info,
  }) async {
    logDebug(
      '[IssuerApi] issueCredential called for EID: $holderEmiratesID, type: $credentialType',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug('[IssuerApi] issueCredential blocked: backend disconnected');
      return const IssueResult(
        success: false,
        credentialID: '',
        error: 'Backend is disconnected',
      );
    }
    try {
      final res = await ApiCore.client.post(
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
          '[IssuerApi] issueCredential success: credentialID ${body['credentialID']}',
        );
        return IssueResult(
          success: true,
          credentialID: body['credentialID'] as String? ?? '',
        );
      }
      logDebug(
        '[IssuerApi] issueCredential failed: ${body['error'] as String? ?? 'Server error (${res.statusCode})'}',
      );
      return IssueResult(
        success: false,
        credentialID: '',
        error: body['error'] as String? ?? 'Server error (${res.statusCode})',
      );
    } catch (e) {
      logDebug('[IssuerApi] issueCredential exception: $e');
      return IssueResult(success: false, credentialID: '', error: e.toString());
    }
  }

  // POST /revokeCredential
  static Future<bool> revokeCredential(String credentialID) async {
    logDebug(
      '[IssuerApi] revokeCredential called for credentialID: $credentialID',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug('[IssuerApi] revokeCredential blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.post(
        Uri.parse('$kApiBaseUrl/revokeCredential'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'credentialID': credentialID}),
      );

      if (res.statusCode == 200) {
        logDebug('[IssuerApi] revokeCredential success');
        return true;
      } else {
        logDebug('[IssuerApi] revokeCredential failed: HTTP ${res.statusCode}');
        return false;
      }
    } catch (e) {
      logDebug('[IssuerApi] revokeCredential exception for $credentialID: $e');
      throw ConnectionException();
    }
  }

  // GET /getAllCredentials
  static Future<List<CredentialRecord>> getAllCredentials({
    String? status,
    int page = 1,
    int limit = 25,
  }) async {
    logDebug(
      '[IssuerApi] getAllCredentials called (page: $page, limit: $limit, status: ${status ?? "all"})',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug('[IssuerApi] getAllCredentials blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.get(
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
          '[IssuerApi] getAllCredentials failed: HTTP ${res.statusCode}',
        );
        return [];
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['credentials'] as List? ?? []);
      logDebug(
        '[IssuerApi] getAllCredentials success: fetched ${list.length} credentials',
      );

      return list
          .map((e) => CredentialRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logDebug('[IssuerApi] getAllCredentials exception: $e');
      throw ConnectionException();
    }
  }

  // GET /getCredentialsByHolder
  static Future<List<Map<String, dynamic>>> getCredentialsByHolder(
    String emiratesID,
  ) async {
    logDebug(
      '[IssuerApi] getCredentialsByHolder called for emiratesID: $emiratesID',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug(
        '[IssuerApi] getCredentialsByHolder blocked: backend disconnected',
      );
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.get(
        Uri.parse('$kApiBaseUrl/getCredentialsByHolder?emiratesID=$emiratesID'),
      );
      if (res.statusCode != 200) {
        logDebug(
          '[IssuerApi] getCredentialsByHolder failed: HTTP ${res.statusCode}',
        );
        return [];
      }

      final body = jsonDecode(res.body);
      if (body is List) {
        logDebug(
          '[IssuerApi] getCredentialsByHolder success: fetched ${body.length} credentials',
        );
        return List<Map<String, dynamic>>.from(body);
      }
      if (body is Map && body['credentials'] is List) {
        logDebug(
          '[IssuerApi] getCredentialsByHolder success: fetched ${(body['credentials'] as List).length} credentials',
        );
        return List<Map<String, dynamic>>.from(body['credentials']);
      }

      logDebug(
        '[IssuerApi] getCredentialsByHolder failed: unexpected body structure',
      );
      return [];
    } catch (e) {
      logDebug('[IssuerApi] getCredentialsByHolder exception: $e');
      throw ConnectionException();
    }
  }

  // POST /suspendCredential
  static Future<bool> suspendCredential(
    String credentialID, {
    String reason = '',
  }) async {
    logDebug(
      '[IssuerApi] suspendCredential called for credentialID: $credentialID, reason: $reason',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug('[IssuerApi] suspendCredential blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.post(
        Uri.parse('$kApiBaseUrl/suspendCredential'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'credentialID': credentialID, 'reason': reason}),
      );

      if (res.statusCode == 200) {
        logDebug('[IssuerApi] suspendCredential success');
        return true;
      } else {
        logDebug(
          '[IssuerApi] suspendCredential failed: HTTP ${res.statusCode}',
        );
        return false;
      }
    } catch (e) {
      logDebug('[IssuerApi] suspendCredential exception for $credentialID: $e');
      throw ConnectionException();
    }
  }

  // POST /restoreCredential
  static Future<bool> restoreCredential(String credentialID) async {
    logDebug(
      '[IssuerApi] restoreCredential called for credentialID: $credentialID',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug('[IssuerApi] restoreCredential blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.post(
        Uri.parse('$kApiBaseUrl/restoreCredential'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'credentialID': credentialID}),
      );

      if (res.statusCode == 200) {
        logDebug('[IssuerApi] restoreCredential success');
        return true;
      } else {
        logDebug(
          '[IssuerApi] restoreCredential failed: HTTP ${res.statusCode}',
        );
        return false;
      }
    } catch (e) {
      logDebug('[IssuerApi] restoreCredential exception for $credentialID: $e');
      throw ConnectionException();
    }
  }

  // GET /getCredentialDetail
  static Future<CredentialRecord?> getCredentialDetail(
    String credentialID,
  ) async {
    logDebug(
      '[IssuerApi] getCredentialDetail called for credentialID: $credentialID',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug('[IssuerApi] getCredentialDetail blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.get(
        Uri.parse(
          '$kApiBaseUrl/getCredentialDetail',
        ).replace(queryParameters: {'credentialID': credentialID}),
      );
      if (res.statusCode == 404) {
        logDebug('[IssuerApi] getCredentialDetail failed: HTTP 404');
        return null;
      }
      if (res.statusCode != 200) {
        logDebug(
          '[IssuerApi] getCredentialDetail failed: HTTP ${res.statusCode}',
        );
        return null;
      }

      logDebug('[IssuerApi] getCredentialDetail success');
      return CredentialRecord.fromJsonWithAudit(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    } catch (e) {
      logDebug('[IssuerApi] getCredentialDetail exception: $e');
      throw ConnectionException();
    }
  }

  // POST /updateCredential
  static Future<bool> updateCredential({
    required String credentialID,
    required String holderEmail,
    String? expiryDate,
  }) async {
    logDebug(
      '[IssuerApi] updateCredential called for credentialID: $credentialID, email: $holderEmail',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug('[IssuerApi] updateCredential blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.post(
        Uri.parse('$kApiBaseUrl/updateCredential'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'credentialID': credentialID,
          'holderEmail': holderEmail,
          'expiryDate': expiryDate,
        }),
      );
      if (res.statusCode != 200) {
        logDebug('[IssuerApi] updateCredential failed: HTTP ${res.statusCode}');
        return false;
      }

      logDebug('[IssuerApi] updateCredential success');
      return true;
    } catch (e) {
      logDebug('[IssuerApi] updateCredential exception: $e');
      throw ConnectionException();
    }
  }
}
