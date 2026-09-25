import 'package:get/get.dart';
import 'package:qwallet_mobileapp/model/subscription_model.dart';
import 'package:qwallet_mobileapp/services/app_api_service.dart';
import 'package:qwallet_mobileapp/utils/runtime_config.dart';
import 'package:qwallet_mobileapp/utils/logger.dart';

class ManageSubscriptionsController extends GetxController {
  var subscriptions = <SubscriptionModel>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;

  /// Single source of truth for the activity banner pending badge.
  int get pendingCount =>
      subscriptions.where((s) => s.status == 'pending').length;

  @override
  void onInit() {
    super.onInit();
    logDebug('[ManageSubscriptionsController] onInit called');
    fetchSubscriptions();
  }

  Future<void> fetchSubscriptions() async {
    logDebug('[ManageSubscriptionsController] fetchSubscriptions started');

    try {
      isLoading(true);
      errorMessage('');
      final data = await ApiService.getMobileSubscriptions(
        RuntimeConfig.to.emiratesID,
      );
      subscriptions.value = data;
      logDebug(
        '[ManageSubscriptionsController] fetchSubscriptions success: ${subscriptions.length} subscriptions loaded (pending: $pendingCount)',
      );
    } on ConnectionException catch (e) {
      logDebug(
        '[ManageSubscriptionsController] fetchSubscriptions ConnectionException: ${e.message}',
      );
      errorMessage(e.message);
    } catch (e) {
      logDebug('[ManageSubscriptionsController] fetchSubscriptions error: $e');
      errorMessage('Failed to fetch subscriptions.');
    } finally {
      isLoading(false);
    }
  }

  Future<void> approve(String id) async {
    final success = await ApiService.approveSubscription(
      id,
      RuntimeConfig.to.emiratesID,
    );
    if (success) fetchSubscriptions();
    logDebug(
      '[ManageSubscriptionsController] approveSubscription for ID $id completed with success: $success',
    );
  }

  Future<void> reject(String id) async {
    final success = await ApiService.rejectSubscription(
      id,
      RuntimeConfig.to.emiratesID,
    );
    if (success) fetchSubscriptions();
    logDebug(
      '[ManageSubscriptionsController] rejectSubscription for ID $id completed with success: $success',
    );
  }
}
