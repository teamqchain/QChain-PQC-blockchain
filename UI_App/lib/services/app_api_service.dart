import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qwallet_mobileapp/model/activity_model.dart';
import 'package:qwallet_mobileapp/model/catalog_model.dart';
import 'package:qwallet_mobileapp/model/credential_model.dart';
import 'package:qwallet_mobileapp/model/subscription_model.dart';
import 'package:qwallet_mobileapp/services/crypto_service.dart';
import 'package:qwallet_mobileapp/utils/app_config.dart';
import 'package:qwallet_mobileapp/utils/alice_inspector.dart';
import 'package:qwallet_mobileapp/utils/logger.dart';

class ConnectionException implements Exception {
  final String message;
  ConnectionException([this.message = 'Unable to connect to the server.']);
  @override
  String toString() => message;
}

class ApiService {
  // Alice-backed client in debug; plain http.Client in release.
  static final http.Client _client = createAliceHttpClient();

  // GET /mobile/checkKeys — has this holder already registered PQC public keys?
  // May also include kemPublicKey / dsaPublicKey (public only) for mismatch checks.
  static Future<Map<String, dynamic>> checkKeys(String emiratesID) async {
    logDebug('[ApiService] checkKeys called for $emiratesID');
    try {
      final res = await _client
          .get(
            Uri.parse(
              '$kApiBaseUrl/mobile/checkKeys?emiratesID=$emiratesID',
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final hasKemKey = body['hasKemKey'] == true;
        final hasSigningKey = body['hasSigningKey'] == true;
        final kemPublicKey = body['kemPublicKey']?.toString() ?? '';
        final dsaPublicKey = body['dsaPublicKey']?.toString() ?? '';
        logDebug(
          '[ApiService] checkKeys success: hasKemKey=$hasKemKey hasSigningKey=$hasSigningKey '
          'kemPubLen=${kemPublicKey.length}',
        );
        return {
          'hasKemKey': hasKemKey,
          'hasSigningKey': hasSigningKey,
          if (kemPublicKey.isNotEmpty) 'kemPublicKey': kemPublicKey,
          if (dsaPublicKey.isNotEmpty) 'dsaPublicKey': dsaPublicKey,
        };
      }
      logDebug('[ApiService] checkKeys failed: HTTP ${res.statusCode}');
      throw ConnectionException('Failed to check wallet keys.');
    } catch (e) {
      if (e is ConnectionException) rethrow;
      logDebug('[ApiService] checkKeys exception: $e');
      throw ConnectionException('Failed to check wallet keys.');
    }
  }

  // POST /mobile/registerHolderKeys — public keys only. Never send private keys.
  static Future<bool> registerHolderKeys({
    required String emiratesID,
    required String kemPublicKey,
    required String dsaPublicKey,
  }) async {
    logDebug('[ApiService] registerHolderKeys called for $emiratesID');
    try {
      final res = await _client
          .post(
            Uri.parse('$kApiBaseUrl/mobile/registerHolderKeys'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'emiratesID': emiratesID,
              'kemPublicKey': kemPublicKey,
              'dsaPublicKey': dsaPublicKey,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final success = body['success'] == true;
        logDebug('[ApiService] registerHolderKeys result: success=$success');
        return success;
      }
      logDebug(
        '[ApiService] registerHolderKeys failed: HTTP ${res.statusCode}',
      );
      return false;
    } catch (e) {
      logDebug('[ApiService] registerHolderKeys exception: $e');
      throw ConnectionException('Failed to register wallet keys.');
    }
  }

  // GET /mobile/getEnvelope — encrypted credential body. Backend does not decrypt.
  static Future<Map<String, dynamic>> getEnvelope(String credentialID) async {
    logDebug('[ApiService] getEnvelope called for $credentialID');
    try {
      final res = await _client
          .get(
            Uri.parse(
              '$kApiBaseUrl/mobile/getEnvelope?credentialID=$credentialID',
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic>) {
          logDebug('[ApiService] getEnvelope success');
          return body;
        }
        if (body is Map) {
          return Map<String, dynamic>.from(body);
        }
        throw ConnectionException('Invalid envelope response.');
      }
      logDebug('[ApiService] getEnvelope failed: HTTP ${res.statusCode}');
      throw ConnectionException('Failed to load credential envelope.');
    } catch (e) {
      if (e is ConnectionException) rethrow;
      logDebug('[ApiService] getEnvelope exception: $e');
      throw ConnectionException('Failed to load credential envelope.');
    }
  }

  /// Fetch encrypted envelope + decrypt on-device. Plaintext stays in memory.
  /// Throws on network / missing key / decrypt failure.
  static Future<Map<String, dynamic>> fetchAndDecryptAttributes(
    String credentialID, {
    String? emiratesID,
  }) async {
    logDebug('[ApiService] fetchAndDecryptAttributes for $credentialID');
    final raw = await getEnvelope(credentialID);
    final envelope = CryptoService.unwrapEnvelopePayload(raw);
    final kemPrivHex = await CryptoService.readKemPrivateKey();
    if (kemPrivHex == null || kemPrivHex.isEmpty) {
      throw StateError('ML-KEM private key not found on this device');
    }
    try {
      final attrs = CryptoService.takeFieldSalts(
        credentialID,
        CryptoService.decryptEnvelope(envelope, kemPrivHex),
      );
      logDebug(
        '[ApiService] fetchAndDecryptAttributes success: ${attrs.length} fields',
      );
      return attrs;
    } catch (e) {
      // Surface the #1 real-world cause: wrong ML-KEM keypair on device.
      try {
        final localPub = await CryptoService.readKemPublicKey();
        logDebug(
          '[ApiService] decrypt failed. localKemPubLen=${localPub?.length ?? 0} '
          'privLen=${kemPrivHex.length} envelopeCredId=${envelope['credId']} '
          'err=$e',
        );
        if (localPub != null && localPub.isNotEmpty) {
          // Full pub so you can paste it next to holders.kem_public_key.
          logDebugLong('[ApiService] device kem_pub_key at decrypt fail', localPub);
        }
        if (emiratesID != null && emiratesID.isNotEmpty) {
          final status = await checkKeys(emiratesID);
          final backendPub = status['kemPublicKey']?.toString() ?? '';
          if (backendPub.isNotEmpty) {
            final diag = await CryptoService.verifyKemKeyMatch(backendPub);
            logDebug('[ApiService] key match after decrypt fail:\n$diag');
            logDebugLong(
              '[ApiService] backend kem_public_key at decrypt fail',
              backendPub,
            );
          } else {
            logDebug(
              '[ApiService] checkKeys has no kemPublicKey — deploy backend '
              'change that returns kemPublicKey from /mobile/checkKeys, then '
              'retry. Until then compare holders.kem_public_key with the '
              'device pub above. If they differ, CRED was sealed to another '
              'key → re-issue.',
            );
          }
        }
      } catch (_) {}
      rethrow;
    }
  }

  // GET /mobile/getHolderProfile — basic demographic info for a holder (full
  // name, email, Emirates ID, holder type, college). Works even before any
  // credential is issued, so the home screen can greet the holder by name right
  // after key generation.
  static Future<Map<String, dynamic>?> getHolderProfile(
    String emiratesID,
  ) async {
    logDebug('[ApiService] getHolderProfile called for $emiratesID');
    try {
      final res = await _client
          .get(
            Uri.parse(
              '$kApiBaseUrl/mobile/getHolderProfile?emiratesID=$emiratesID',
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body['success'] == true) {
          logDebug('[ApiService] getHolderProfile success: ${body['fullName']}');
          return body;
        }
        logDebug(
          '[ApiService] getHolderProfile failed: invalid body or success=false',
        );
        return null;
      }
      logDebug('[ApiService] getHolderProfile failed: HTTP ${res.statusCode}');
      return null;
    } catch (e) {
      logDebug('[ApiService] getHolderProfile exception: $e');
      return null;
    }
  }

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

  // POST /mobile/generateOTP — holder-signed disclosed payload. No expiresIn.
  static Future<Map<String, dynamic>?> generateVerificationOTP({
    required String credentialID,
    required List<String> hiddenFields,
    required String disclosedPayload,
    required String holderSignature,
  }) async {
    logDebug(
      '[ApiService] generateVerificationOTP called for $credentialID with ${hiddenFields.length} hidden fields',
    );
    try {
      final res = await _client
          .post(
            Uri.parse('$kApiBaseUrl/mobile/generateOTP'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'credentialID': credentialID,
              'hiddenFields': hiddenFields,
              'disclosedPayload': disclosedPayload,
              'holderSignature': holderSignature,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          logDebug('[ApiService] generateVerificationOTP success');
          return {
            'otp': body['otp']?.toString(),
            'expiresAt': body['expiresAt']?.toString(),
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

  // POST /mobile/generatePresentation — holder-signed disclosed payload. No expiresIn.
  static Future<Map<String, dynamic>?> generatePresentation({
    required String credentialID,
    required List<String> hiddenFields,
    required String disclosedPayload,
    required String holderSignature,
  }) async {
    logDebug(
      '[ApiService] generatePresentation called for $credentialID with ${hiddenFields.length} hidden fields',
    );
    try {
      final res = await _client
          .post(
            Uri.parse('$kApiBaseUrl/mobile/generatePresentation'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'credentialID': credentialID,
              'hiddenFields': hiddenFields,
              'disclosedPayload': disclosedPayload,
              'holderSignature': holderSignature,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          logDebug(
            '[ApiService] generatePresentation success: ID ${body['presentationID']}',
          );
          return {
            'presentationID': body['presentationID']?.toString(),
            'expiresAt': body['expiresAt']?.toString(),
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
      final alreadyInWallet = body['alreadyInWallet'] == true;
      logDebug(
        '[ApiService] fetchDocument HTTP ${res.statusCode}, success: $success, alreadyInWallet: $alreadyInWallet, message: ${body['message']}',
      );

      return {
        'success': success,
        'alreadyInWallet': alreadyInWallet,
        'message': body['message'] ??
            (success
                ? 'Success'
                : alreadyInWallet
                    ? 'This document is already in your wallet.'
                    : 'Document not found.'),
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
