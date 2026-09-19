import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/model/credential_model.dart';
import 'package:qwallet_mobileapp/utils/app_config.dart';
import 'package:qwallet_mobileapp/services/app_api_service.dart';
import 'package:qwallet_mobileapp/services/crypto_service.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';
import 'package:qwallet_mobileapp/widgets/wallet_category.dart';
import 'package:qwallet_mobileapp/utils/logger.dart'; // Added logger import

class WalletController extends GetxController {
  var credentials = <CredentialModel>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;

  // Holder demographic profile — fetched from /mobile/getHolderProfile so the
  // home screen can greet the holder by name even before any credential is
  // issued (e.g. right after key generation). Falls back to 'Holder'.
  var holderName = ''.obs;
  var holderEmail = ''.obs;
  var holderType = ''.obs;
  var holderCollege = ''.obs;

  // Replace this with actual authenticated user state later
  // final String currentUserEID = '784-2004-7654321-1';

  @override
  void onInit() {
    super.onInit();
    logDebug('[WalletController] onInit called');
    fetchHolderProfile();
    fetchMyCredentials();
  }

  // Fetch the holder's basic demographic info by Emirates ID. Non-fatal: on any
  // failure holderName stays empty and the UI falls back to 'Holder'.
  Future<void> fetchHolderProfile() async {
    logDebug('[WalletController] fetchHolderProfile started');
    try {
      final profile = await ApiService.getHolderProfile(userEmiratesID);
      if (profile != null) {
        holderName.value = (profile['fullName'] ?? '').toString().trim();
        holderEmail.value = (profile['email'] ?? '').toString().trim();
        holderType.value = (profile['holderType'] ?? '').toString().trim();
        holderCollege.value = (profile['college'] ?? '').toString().trim();
        logDebug(
          '[WalletController] fetchHolderProfile success: ${holderName.value}',
        );
      } else {
        logDebug('[WalletController] fetchHolderProfile returned null');
      }
    } catch (e) {
      logDebug('[WalletController] fetchHolderProfile exception: $e');
    }
  }

  // The display name to show on the home screen. Prefers the demographic
  // profile; if that's empty, falls back to the first credential's holderName;
  // if neither is available, returns 'Holder'.
  String get displayHolderName {
    if (holderName.value.isNotEmpty) return holderName.value;
    if (credentials.isNotEmpty) return credentials.first.holderName;
    return 'Holder';
  }

  Future<void> fetchMyCredentials() async {
    logDebug('[WalletController] fetchMyCredentials started');
    try {
      isLoading(true);
      errorMessage('');
      final data = await ApiService.getMyCredentials(userEmiratesID);
      // Metadata only — body attributes are decrypted on demand in the detail
      // screen, never at list load. Envelope-shaped `attributes` are discarded
      // by CredentialModel.fromJson so ciphertext never paints as rows.
      credentials.value = data;
      logDebug(
        '[WalletController] fetchMyCredentials success: ${credentials.length} items',
      );
    } on ConnectionException catch (e) {
      logDebug(
        '[WalletController] fetchMyCredentials ConnectionException: ${e.message}',
      );
      errorMessage(e.message);
    } catch (e) {
      logDebug('[WalletController] fetchMyCredentials generic exception: $e');
      errorMessage('An unexpected error occurred.');
    } finally {
      isLoading(false);
    }
  }

  /// Decrypt one credential on demand (e.g. opening the detail screen or
  /// retry). Returns true when local decrypt succeeded and the in-memory model
  /// was updated. Plaintext stays in memory only — never written to disk.
  Future<bool> decryptCredentialById(String credentialID) async {
    if (credentialID.isEmpty) return false;
    final index = credentials.indexWhere((c) => c.credentialID == credentialID);
    try {
      final attrs = await ApiService.fetchAndDecryptAttributes(credentialID);
      if (index >= 0) {
        credentials[index] = credentials[index].copyWith(
          attributes: attrs,
          attributesDecrypted: true,
        );
        credentials.refresh();
      }
      return true;
    } catch (e) {
      logDebug(
        '[WalletController] decryptCredentialById failed for $credentialID: $e',
      );
      // Diagnostic: check if the device's ML-KEM key matches the backend's.
      // The publicKey field on the credential is the ISSUER's signing key, not
      // the holder's KEM key — but the backend can tell us the registered KEM
      // public key for this holder. For now, log the device's stored public key
      // so it can be compared manually with what the backend registered.
      try {
        final devPub = await CryptoService.readKemPrivateKey();
        logDebug(
          '[WalletController] device kem_priv present=${devPub != null && devPub.isNotEmpty} '
          'len=${devPub?.length ?? 0}',
        );
      } catch (_) {}
      if (index >= 0) {
        credentials[index] = credentials[index].copyWith(
          attributes: const {},
          attributesDecrypted: false,
        );
        credentials.refresh();
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> requestOTP(
    String credentialID, [
    List<String> hiddenFields = const [],
  ]) async {
    logDebug(
      '[WalletController] requestOTP started for credential: $credentialID',
    );
    try {
      final cred = credentials.firstWhereOrNull(
        (c) => c.credentialID == credentialID,
      );
      final hidden = hiddenFields.toSet();
      final disclosed = <String, dynamic>{};
      if (cred != null) {
        if (!hidden.contains('credentialType')) {
          disclosed['credentialType'] = cred.credentialType;
        }
        if (!hidden.contains('status')) disclosed['status'] = cred.status;
        if (!hidden.contains('issuedBy')) disclosed['issuedBy'] = cred.issuedBy;
        if (!hidden.contains('holderEID')) {
          disclosed['holderEID'] = cred.holderEID;
        }
        if (!hidden.contains('holderName')) {
          disclosed['holderName'] = cred.holderName;
        }
        if (!hidden.contains('issuedAt')) disclosed['issuedAt'] = cred.issuedAt;
        if (cred.expiryDate != null && !hidden.contains('expiryDate')) {
          disclosed['expiryDate'] = cred.expiryDate;
        }
        cred.attributes.forEach((k, v) {
          if (!hidden.contains(k)) disclosed[k] = v;
        });
      }

      final signed = await CryptoService.buildSignedDisclosedPayload(
        credentialID: credentialID,
        disclosedFields: disclosed,
      );
      final result = await ApiService.generateVerificationOTP(
        credentialID: credentialID,
        hiddenFields: hiddenFields,
        disclosedPayload: signed.disclosedPayloadJson,
        holderSignature: signed.holderSignatureHex,
      );
      if (result == null) {
        logDebug('[WalletController] requestOTP failed: API returned null');
        Get.snackbar(
          'Error',
          'Could not generate OTP. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        logDebug('[WalletController] requestOTP success');
      }
      return result;
    } catch (e) {
      logDebug('[WalletController] requestOTP exception: $e');
      Get.snackbar(
        'Network Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }
  }

  // Computed Stats for the Home Screen
  int get validCount =>
      credentials.where((c) => c.status.toLowerCase() == 'active').length;
  int get suspendedCount =>
      credentials.where((c) => c.status.toLowerCase() == 'suspended').length;
  int get revokedCount =>
      credentials.where((c) => c.status.toLowerCase() == 'revoked').length;
  int get expiryCount =>
      credentials.where((c) => c.status.toLowerCase() == 'expired').length;

  List<CredentialModel> get favourites => credentials
      .where((c) => c.isFavorite == true && c.status.toLowerCase() == 'active')
      .toList();

  // List<CredentialModel> get recentActivity {
  //   var sorted = List<CredentialModel>.from(credentials);
  //   sorted.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  //   return sorted.take(2).toList();
  // }

  Future<void> toggleFavoriteStatus(CredentialModel cred) async {
    logDebug(
      '[WalletController] toggleFavoriteStatus started for ${cred.credentialID}',
    );

    // 1. Optimistic Update (Immediate UI change)
    final index = credentials.indexWhere(
      (c) => c.credentialID == cred.credentialID,
    );
    if (index == -1) {
      logDebug(
        '[WalletController] toggleFavoriteStatus abort: credential not found in list',
      );
      return;
    }

    final originalState = credentials[index].isFavorite;

    // Flip the boolean locally and refresh the UI instantly
    credentials[index].isFavorite = !originalState;
    credentials.refresh();
    logDebug(
      '[WalletController] toggleFavoriteStatus optimistic update applied (isFavorite: ${!originalState})',
    );

    // 2. Background Sync
    try {
      final success = await ApiService.toggleFavorite(
        userEmiratesID,
        cred.credentialID,
      );
      if (!success) throw Exception('API returned success=false');
      logDebug(
        '[WalletController] toggleFavoriteStatus sync completed successfully',
      );
    } catch (e) {
      // 3. Rollback on failure
      logDebug(
        '[WalletController] toggleFavoriteStatus sync failed: $e. Rolling back to $originalState.',
      );
      credentials[index].isFavorite = originalState;
      credentials.refresh();
      Get.snackbar('Sync Error', 'Could not update favorites.');
    }
  }

  List<WalletCategory> get dynamicCategories {
    // 1. Group credentials by their exact backend category
    final Map<String, int> categoryCounts = {};
    for (var cred in credentials) {
      categoryCounts[cred.category] = (categoryCounts[cred.category] ?? 0) + 1;
    }

    // 2. Build the UI models dynamically
    return categoryCounts.entries.map((entry) {
      final catName = entry.key;
      final count = entry.value;

      return WalletCategory(
        id: catName, // Using the name itself as the ID
        title: catName,
        subtitle: count > 1 ? '$count credentials' : '$count credential',
        count: count,
        icon: _getIconForCategory(catName),
        color: _getColorForCategory(catName),
      );
    }).toList();
  }

  Color _getColorForCategory(String category) {
    final c = category.toLowerCase();

    // Map specific keywords to your colors.dart palette
    if (c.contains('education') || c.contains('academic')) return qAmethyst;
    if (c.contains('health') || c.contains('medical')) return qCherryRed;
    if (c.contains('bank') || c.contains('finance')) return qOceanTeal;
    if (c.contains('government') || c.contains('official')) return qBurntOrange;
    if (c.contains('identity') || c.contains('personal')) return qAzureBlue;
    if (c.contains('travel') || c.contains('visa')) return qLeafGreen;
    if (c.contains('professional') || c.contains('work')) return qSlateBlue;

    // Fallback: Use the string's hashcode to consistently assign a dynamic color
    // to unknown categories so they aren't all the same default color.
    final fallbackColors = [qDeepViolet, qVibrantIndigo, qMagentaPink];
    return fallbackColors[category.hashCode % fallbackColors.length];
  }

  // Helper to assign icons to backend strings
  IconData _getIconForCategory(String category) {
    final c = category.toLowerCase();
    if (c.contains('education') || c.contains('academic')) return Icons.school;
    if (c.contains('health') || c.contains('medical'))
      return Icons.local_hospital;
    if (c.contains('bank') || c.contains('finance'))
      return Icons.account_balance;
    if (c.contains('government') || c.contains('official')) return Icons.gavel;
    if (c.contains('identity') || c.contains('personal')) return Icons.badge;
    if (c.contains('travel') || c.contains('visa')) return Icons.flight;
    if (c.contains('professional') || c.contains('work')) return Icons.work;
    return Icons.folder_shared; // Default icon for unknown future categories!
  }
}
