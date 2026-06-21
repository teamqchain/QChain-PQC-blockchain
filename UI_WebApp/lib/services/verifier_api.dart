import 'dart:convert';
import 'package:qportal_webapp/models/VERIFIER/verificationDetail_model.dart';
import 'package:qportal_webapp/models/VERIFIER/verificationHistory_model.dart';
import 'package:qportal_webapp/models/VERIFIER/verificationResult_model.dart';
import 'package:qportal_webapp/services/core_api.dart';
import 'package:qportal_webapp/utils/webApp_config.dart';
import 'package:qportal_webapp/utils/logger.dart';

class VerifierApi {

  // POST /verifyCredential
  static Future<VerificationResult> verifyCredential(
    String credentialID,
  ) async {
    logDebug(
      '[VerifierApi] verifyCredential called for credentialID: $credentialID',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug('[VerifierApi] verifyCredential blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.post(
        Uri.parse('$kApiBaseUrl/verifyCredential'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'credentialID': credentialID}),
      );

      if (res.statusCode == 200) {
        logDebug('[VerifierApi] verifyCredential success');
        final Map<String, dynamic> body = jsonDecode(res.body);
        return VerificationResult.fromJson(body, credentialID);
      } else {
        logDebug(
          '[VerifierApi] verifyCredential failed: HTTP ${res.statusCode}',
        );
        throw ConnectionException('Server error (${res.statusCode})');
      }
    } catch (e) {
      logDebug('[VerifierApi] verifyCredential exception: $e');
      throw ConnectionException();
    }
  }

  // POST /resolveSession
  static Future<VerificationResult> resolveSession(String sessionToken) async {
    logDebug(
      '[VerifierApi] resolveSession called for sessionToken: $sessionToken',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug('[VerifierApi] resolveSession blocked: backend disconnected');
      throw ConnectionException();
    }

    try {
      final res = await ApiCore.client.post(
        Uri.parse('$kApiBaseUrl/resolveSession'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sessionToken': sessionToken}),
      );

      if (res.statusCode == 404) {
        logDebug(
          '[VerifierApi] resolveSession failed: HTTP 404 (Session not found)',
        );
        throw Exception('Session not found or invalid code.');
      }
      if (res.statusCode == 400) {
        logDebug(
          '[VerifierApi] resolveSession failed: HTTP 400 (Session expired)',
        );
        throw Exception('Session expired. Please generate a new QR code.');
      }
      if (res.statusCode != 200) {
        logDebug('[VerifierApi] resolveSession failed: HTTP ${res.statusCode}');
        throw Exception('Failed to resolve session (HTTP ${res.statusCode})');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      logDebug('[VerifierApi] resolveSession success');

      return VerificationResult.fromJson(
        body,
        body['credentialID'] as String? ?? '',
      );
    } catch (e) {
      logDebug('[VerifierApi] resolveSession exception: $e');
      rethrow;
    }
  }

  // GET /getVerificationHistory
  static Future<List<VerificationHistoryRecord>> getVerificationHistory({
    int page = 1,
    int limit = 25,
    String? result,
  }) async {
    logDebug(
      '[VerifierApi] getVerificationHistory called (page: $page, limit: $limit, result: ${result ?? "all"})',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug(
        '[VerifierApi] getVerificationHistory blocked: backend disconnected',
      );
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.get(
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
          '[VerifierApi] getVerificationHistory failed: HTTP ${res.statusCode}',
        );
        return [];
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['records'] as List? ?? [];
      logDebug(
        '[VerifierApi] getVerificationHistory success: fetched ${list.length} records',
      );

      return list
          .map(
            (e) =>
                VerificationHistoryRecord.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      logDebug('[VerifierApi] getVerificationHistory exception: $e');
      throw ConnectionException();
    }
  }

  // GET /getVerificationDetail
  static Future<VerificationDetailData?> getVerificationDetail(
    String id,
  ) async {
    logDebug('[VerifierApi] getVerificationDetail called for ID: $id');
    if (!await ApiCore.ensureConnection()) {
      logDebug(
        '[VerifierApi] getVerificationDetail blocked: backend disconnected',
      );
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.get(
        Uri.parse(
          '$kApiBaseUrl/getVerificationDetail',
        ).replace(queryParameters: {'id': id}),
      );
      if (res.statusCode == 404) {
        logDebug('[VerifierApi] getVerificationDetail failed: HTTP 404');
        return null;
      }
      if (res.statusCode != 200) {
        logDebug(
          '[VerifierApi] getVerificationDetail failed: HTTP ${res.statusCode}',
        );
        return null;
      }

      logDebug('[VerifierApi] getVerificationDetail success');
      return VerificationDetailData.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    } catch (e) {
      logDebug('[VerifierApi] getVerificationDetail exception: $e');
      throw ConnectionException();
    }
  }
}
