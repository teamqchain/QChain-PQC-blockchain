import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qwallet_mobileapp/model/activity_model.dart';
import 'package:qwallet_mobileapp/model/catalog_model.dart';
import 'package:qwallet_mobileapp/model/credential_model.dart';
import 'package:qwallet_mobileapp/model/subscription_model.dart';
import 'package:qwallet_mobileapp/utils/app_config.dart';
import 'package:qwallet_mobileapp/utils/logger.dart';

class ConnectionException implements Exception {
  final String message;
  ConnectionException([this.message = 'Unable to connect to the server.']);
  @override
  String toString() => message;
}

class ApiService {
  static final _client = http.Client();

  // Fetch live credentials for the dashboard
  static Future<List<CredentialModel>> getMyCredentials(
    String emiratesID,
  ) async {
    logDebug('[ApiService] getMyCredentials called for $emiratesID');
    try {
      final res = await _client
          .get(
            Uri.parse(
              '$kApiBaseUrl/mobile/getCredentialsByHolder?emiratesID=$emiratesID',
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final List<dynamic> body = jsonDecode(res.body);
        logDebug(
          '[ApiService] getMyCredentials success: fetched ${body.length} credentials',
        );
        return body.map((json) => CredentialModel.fromJson(json)).toList();
      }
      logDebug('[ApiService] getMyCredentials failed: HTTP ${res.statusCode}');
      return [];
    } catch (e) {
      logDebug('[ApiService] getMyCredentials exception: $e');
      throw ConnectionException('Failed to load wallet data.');
    }
  }

  // Request a live OTP for verification (Now with Selective Disclosure)
  static Future<Map<String, dynamic>?> generateVerificationOTP(
    String credentialID,
    List<String> hiddenFields, // <-- ADD THIS PARAMETER
    int expiresIn,
  ) async {
    logDebug(
      '[ApiService] generateVerificationOTP called for $credentialID with ${hiddenFields.length} hidden fields',
    );
    logDebug('[ApiService] OTP time-to-live: $expiresIn seconds');
    try {
      final res = await _client
          .post(
            Uri.parse('$kApiBaseUrl/mobile/generateOTP'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'credentialID': credentialID,
              'hiddenFields': hiddenFields, // <-- SEND TO BACKEND
              'expiresIn': expiresIn,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          logDebug('[ApiService] generateVerificationOTP success');
          return {
            'otp': body['otp']?.toString(),
            'expiresAt': body['expiresAt'],
          };
        } else {
          logDebug(
            '[ApiService] generateVerificationOTP failed: backend returned success=false',
          );
        }
      } else {
        logDebug(
          '[ApiService] generateVerificationOTP failed: HTTP ${res.statusCode}',
        );
      }
      return null;
    } catch (e) {
      logDebug('[ApiService] generateVerificationOTP exception: $e');
      throw ConnectionException('Failed to generate verification code.');
    }
  }

  // Send the favorite toggle to the backend
  static Future<bool> toggleFavorite(
    String holderEID,
    String credentialID,
  ) async {
    logDebug(
      '[ApiService] toggleFavorite called for holder: $holderEID, credential: $credentialID',
    );
    try {
      final res = await _client
          .post(
            Uri.parse('$kApiBaseUrl/mobile/toggleFavorite'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'holderEID': holderEID,
              'credentialID': credentialID,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final success = body['success'] == true;
        logDebug('[ApiService] toggleFavorite result: success=$success');
        return success;
      }
      logDebug('[ApiService] toggleFavorite failed: HTTP ${res.statusCode}');
      return false;
    } catch (e) {
      logDebug('[ApiService] toggleFavorite exception: $e');
      throw ConnectionException('Failed to update favorite status.');
    }
  }

  // Fetch live activity history for the holder
  static Future<List<ActivityModel>> getHolderActivity(
    String emiratesID,
  ) async {
    logDebug('[ApiService] getHolderActivity called for $emiratesID');
    try {
      final res = await _client
          .get(
            Uri.parse('$kApiBaseUrl/mobile/getActivity?emiratesID=$emiratesID'),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['activity'] != null) {
          final List<dynamic> acts = body['activity'];
          logDebug(
            '[ApiService] getHolderActivity success: fetched ${acts.length} activities',
          );
          return acts.map((json) => ActivityModel.fromJson(json)).toList();
        } else {
          logDebug(
            '[ApiService] getHolderActivity failed: invalid body structure or success=false',
          );
        }
      } else {
        logDebug(
          '[ApiService] getHolderActivity failed: HTTP ${res.statusCode}',
        );
      }
      return [];
    } catch (e) {
      logDebug('[ApiService] getHolderActivity exception: $e');
      throw ConnectionException('Failed to load activity history.');
    }
  }

  // Generate a selective disclosure presentation session
  static Future<Map<String, dynamic>?> generatePresentation(
    String credentialID,
    List<String> hiddenFields,
    int expiresIn,
  ) async {
    logDebug(
      '[ApiService] generatePresentation called for $credentialID with ${hiddenFields.length} hidden fields',
    );
    logDebug('[ApiService] qr time-to-live: $expiresIn seconds');
    try {
      final res = await _client
          .post(
            Uri.parse('$kApiBaseUrl/mobile/generatePresentation'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'credentialID': credentialID,
              'hiddenFields': hiddenFields,
              'expiresIn': expiresIn,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          logDebug(
            '[ApiService] generatePresentation success: ID ${body['presentationID']}',
          );
          return {
            'presentationID': body['presentationID'],
            'expiresAt': body['expiresAt'],
          };
        } else {
          logDebug(
            '[ApiService] generatePresentation failed: backend returned success=false',
          );
        }
      } else {
        logDebug(
          '[ApiService] generatePresentation failed: HTTP ${res.statusCode}',
        );
      }
      return null;
    } catch (e) {
      logDebug('[ApiService] generatePresentation exception: $e');
      throw ConnectionException('Failed to generate secure presentation.');
    }
  }

  // Fetch the public directory of issuers in QPortal
  static Future<List<CatalogCategory>> getCatalog() async {
    logDebug('[ApiService] getCatalog called');
    try {
      final res = await _client
          .get(Uri.parse('$kApiBaseUrl/mobile/getCatalog'))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['categories'] != null) {
          final List<dynamic> cats = body['categories'];
          logDebug(
            '[ApiService] getCatalog success: fetched ${cats.length} categories',
          );
          return cats.map((json) => CatalogCategory.fromJson(json)).toList();
        } else {
          logDebug(
            '[ApiService] getCatalog failed: invalid body structure or success=false',
          );
        }
      } else {
        logDebug('[ApiService] getCatalog failed: HTTP ${res.statusCode}');
      }
      return [];
    } catch (e) {
      logDebug('[ApiService] getCatalog exception: $e');
      throw ConnectionException('Failed to load issuer directory.');
    }
  }

  // Attempt to fetch an issued document from an organization
  static Future<Map<String, dynamic>> fetchDocument(
    String holderEID,
    String issuerID,
    String serviceName,
    // String serviceID
  ) async {
    logDebug(
      '[ApiService] fetchDocument called for issuerID: $issuerID, service: $serviceName',
    );
    try {
      final res = await _client
          .post(
            Uri.parse('$kApiBaseUrl/mobile/fetchDocument'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'holderEID': holderEID,
              'issuerID': issuerID,
              'serviceName': serviceName,
              // 'serviceID': serviceID,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(res.body);
      final success = body['success'] == true;
      logDebug(
        '[ApiService] fetchDocument HTTP ${res.statusCode}, success: $success, message: ${body['message']}',
      );

      return {
        'success': success,
        'message':
            body['message'] ?? (success ? 'Success' : 'Document not found.'),
      };
    } catch (e) {
      logDebug('[ApiService] fetchDocument exception: $e');
      throw ConnectionException('Network error occurred.');
    }
  }

  static Future<List<SubscriptionModel>> getMobileSubscriptions(
    String emiratesID,
  ) async {
    try {
      final res = await _client
          .get(
            Uri.parse(
              '$kApiBaseUrl/mobile/getSubscriptions?emiratesID=$emiratesID',
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          final List<dynamic> subs = body['subscriptions'];
          return subs.map((s) => SubscriptionModel.fromJson(s)).toList();
        }
      }
      return [];
    } catch (e) {
      throw ConnectionException('Failed to load subscriptions.');
    }
  }

  static Future<bool> approveSubscription(
    String subscriptionID,
    String emiratesID,
  ) async {
    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/mobile/approveSubscription'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'subscriptionID': subscriptionID,
          'emiratesID': emiratesID,
        }),
      );
      return res.statusCode == 200 && jsonDecode(res.body)['success'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> rejectSubscription(
    String subscriptionID,
    String emiratesID,
  ) async {
    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl/mobile/rejectSubscription'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'subscriptionID': subscriptionID,
          'emiratesID': emiratesID,
        }),
      );
      return res.statusCode == 200 && jsonDecode(res.body)['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
