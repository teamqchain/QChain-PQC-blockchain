import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/model/credential_model.dart';
import 'package:qwallet_mobileapp/utils/app_config.dart';
import 'package:qwallet_mobileapp/services/app_api_service.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';
import 'package:qwallet_mobileapp/widgets/wallet_category.dart';
import 'package:qwallet_mobileapp/utils/logger.dart'; // Added logger import

class WalletController extends GetxController {
  var credentials = <CredentialModel>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;

  // Replace this with actual authenticated user state later
  // final String currentUserEID = '784-2004-7654321-1';

  @override
  void onInit() {
    super.onInit();
    logDebug('[WalletController] onInit called');
    fetchMyCredentials();
  }

  Future<void> fetchMyCredentials() async {
    logDebug('[WalletController] fetchMyCredentials started');
    try {
      isLoading(true);
      errorMessage('');
      final data = await ApiService.getMyCredentials(userEmiratesID);
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

  Future<Map<String, dynamic>?> requestOTP(String credentialID, [List<String> hiddenFields = const []]) async {
    logDebug(
      '[WalletController] requestOTP started for credential: $credentialID',
    );
    try {
      final result = await ApiService.generateVerificationOTP(credentialID, hiddenFields, 300);
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
