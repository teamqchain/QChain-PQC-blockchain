import 'dart:async';

import 'package:get/get.dart';
import 'package:qwallet_mobileapp/controllers/wallet_controller.dart';
import 'package:qwallet_mobileapp/model/activity_model.dart';
import 'package:qwallet_mobileapp/services/app_api_service.dart';
import 'package:qwallet_mobileapp/utils/logger.dart';
import 'package:qwallet_mobileapp/utils/runtime_config.dart';

class ActivityController extends GetxController {
  static const _pollInterval = Duration(seconds: 20);

  var activities = <ActivityModel>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;

  /// Latest unseen activity for the in-app iOS-style banner (null = hide).
  final Rxn<ActivityModel> pendingBanner = Rxn<ActivityModel>();

  /// Newest activity id we've already accepted (seeded on first poll — no banner).
  String? _lastSeenId;
  String? _lastSeenEid;
  Timer? _pollTimer;
  bool _pollInFlight = false;
  int _pollGeneration = 0;

  @override
  void onInit() {
    super.onInit();
    logDebug('[ActivityController] onInit called');
    fetchActivity();
  }

  @override
  void onClose() {
    stopActivityPolling();
    super.onClose();
  }

  /// Start foreground polling while MainShell is alive (session selected).
  ///
  /// [catchUp]: when true (app resumed), one poll may raise a banner for
  /// anything that arrived while the app was backgrounded.
  void startActivityPolling({bool catchUp = false}) {
    _pollTimer?.cancel();
    logDebug(
      '[ActivityController] activity polling started (catchUp=$catchUp, '
      'hasBaseline=${_lastSeenId != null})',
    );

    if (_lastSeenId == null) {
      // Quiet baseline — never banner historical rows on first open.
      unawaited(_pollOnce(notify: false));
    } else if (catchUp) {
      unawaited(_pollOnce(notify: true));
    }

    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_pollOnce(notify: true));
    });
  }

  void stopActivityPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    logDebug('[ActivityController] activity polling stopped');
  }

  void dismissBanner() {
    pendingBanner.value = null;
  }

  Future<void> fetchActivity() async {
    logDebug('[ActivityController] fetchActivity started');
    try {
      isLoading(true);
      errorMessage('');
      // Explicit refresh: update the feed, seed/advance baseline, no banner.
      await _pollOnce(notify: false, surfaceErrors: true);
    } finally {
      isLoading(false);
    }
  }

  Future<void> _pollOnce({
    required bool notify,
    bool surfaceErrors = false,
  }) async {
    if (_pollInFlight) return;
    _pollInFlight = true;
    final gen = ++_pollGeneration;
    try {
      await _loadAndApply(notify: notify);
    } on ConnectionException catch (e) {
      logDebug(
        '[ActivityController] poll ConnectionException: ${e.message}',
      );
      if (surfaceErrors) errorMessage(e.message);
    } catch (e) {
      logDebug('[ActivityController] poll failed: $e');
      if (surfaceErrors) errorMessage('An unexpected error occurred.');
    } finally {
      if (gen == _pollGeneration) _pollInFlight = false;
    }
  }

  Future<void> _loadAndApply({required bool notify}) async {
    final eid = RuntimeConfig.to.emiratesID;
    final data = await ApiService.getHolderActivity(eid);
    data.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    activities.value = data;

    final top = data.isEmpty ? null : data.first;
    final topId = top?.id ?? '';

    // New holder in this process → reseed, never banner stale history.
    if (_lastSeenEid != eid) {
      _lastSeenEid = eid;
      _lastSeenId = topId.isEmpty ? null : topId;
      logDebug(
        '[ActivityController] seeded lastSeen for $eid → ${_lastSeenId ?? "(empty)"}',
      );
      return;
    }

    if (top == null || topId.isEmpty) {
      _lastSeenId ??= '';
      return;
    }

    if (_lastSeenId == null) {
      // First successful load for this EID: baseline only.
      _lastSeenId = topId;
      logDebug('[ActivityController] baseline lastSeen=$topId (no banner)');
      return;
    }

    if (topId == _lastSeenId) return;

    _lastSeenId = topId;
    logDebug(
      '[ActivityController] new activity tip $topId type=${top.type} notify=$notify',
    );

    if (!notify) return;

    pendingBanner.value = top;
    // Issued / restored → refresh wallet list so the new card appears.
    if ((top.type == 'issued' || top.type == 'restored') &&
        Get.isRegistered<WalletController>()) {
      unawaited(Get.find<WalletController>().fetchMyCredentials());
    }
  }
}
