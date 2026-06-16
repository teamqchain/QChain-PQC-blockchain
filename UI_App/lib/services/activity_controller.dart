import 'package:get/get.dart';
import 'package:qwallet_mobileapp/model/activity_model.dart';
import 'package:qwallet_mobileapp/routes/app_config.dart';
import 'package:qwallet_mobileapp/services/app_api_service.dart';
import 'package:qwallet_mobileapp/services/logger.dart';

class ActivityController extends GetxController {
  var activities = <ActivityModel>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;

  // Assuming this is set upon user login (same as WalletController)
  // final String currentUserEID = '784-2004-7654321-1';

  var pendingSubscriptionsCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    logDebug('[ActivityController] onInit called');
    fetchActivity();
  }

  Future<void> fetchActivity() async {
    logDebug('[ActivityController] fetchActivity started');
    try {
      isLoading(true);
      errorMessage('');
      final data = await ApiService.getHolderActivity(userEmiratesID);

      // Ensure they are sorted newest first
      data.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      activities.value = data;

      final subs = await ApiService.getMobileSubscriptions(userEmiratesID);
      pendingSubscriptionsCount.value = subs
          .where((s) => s.status == 'pending')
          .length;
          
      logDebug(
        '[ActivityController] fetchActivity success: ${activities.length} records processed',
      );
    } on ConnectionException catch (e) {
      logDebug(
        '[ActivityController] fetchActivity ConnectionException: ${e.message}',
      );
      errorMessage(e.message);
    } catch (e) {
      logDebug('[ActivityController] fetchActivity generic exception: $e');
      errorMessage('An unexpected error occurred.');
    } finally {
      isLoading(false);
    }
  }
}
