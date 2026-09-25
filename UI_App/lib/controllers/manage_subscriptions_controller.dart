import 'dart:async';

import 'package:get/get.dart';
import 'package:qwallet_mobileapp/model/subscription_model.dart';
import 'package:qwallet_mobileapp/services/app_api_service.dart';
import 'package:qwallet_mobileapp/utils/logger.dart';
import 'package:qwallet_mobileapp/utils/runtime_config.dart';

class ManageSubscriptionsController extends GetxController {
  static const _pollInterval = Duration(seconds: 20);

  var subscriptions = <SubscriptionModel>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;

  /// Latest unseen subscription for the in-app iOS-style banner (null = hide).
  final Rxn<SubscriptionModel> pendingBanner = Rxn<SubscriptionModel>();

  /// Newest subscription id we've already accepted (seeded on first poll).
  String? _lastSeenId;
  String? _lastSeenEid;
  Timer? _pollTimer;
  bool _pollInFlight = false;
  int _pollGeneration = 0;

  /// Single source of truth for the activity banner pending badge.
  int get pendingCount =>
      subscriptions.where((s) => s.status == 'pending').length;

  @override
  void onInit() {
    super.onInit();
    logDebug('[ManageSubscriptionsController] onInit called');
    fetchSubscriptions();
  }

  @override
  void onClose() {
    stopSubscriptionPolling();
    super.onClose();
  }

  /// Start foreground polling while MainShell is alive (session selected).
  void startSubscriptionPolling({bool catchUp = false}) {
    _pollTimer?.cancel();
    logDebug(
      '[ManageSubscriptionsController] subscription polling started '
      '(catchUp=$catchUp, hasBaseline=${_lastSeenId != null})',
    );

    if (_lastSeenId == null) {
      unawaited(_pollOnce(notify: false));
    } else if (catchUp) {
      unawaited(_pollOnce(notify: true));
    }

    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_pollOnce(notify: true));
    });
  }

  void stopSubscriptionPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    logDebug('[ManageSubscriptionsController] subscription polling stopped');
  }

  void dismissBanner() {
    pendingBanner.value = null;
  }

  /// Short primary line for the in-app notification banner.
  static String bannerTitle(SubscriptionModel s) {
    switch (s.status.toLowerCase()) {
      case 'pending':
        return 'New subscription request';
      case 'approved':
      case 'active':
        return 'Subscription approved';
      case 'rejected':
        return 'Subscription rejected';
      default:
        return 'Subscription updated';
    }
  }

  /// Secondary line under [bannerTitle].
  static String bannerSubtitle(SubscriptionModel s) {
    return '${s.credentialType} · ${s.verifierName}';
  }

  Future<void> fetchSubscriptions() async {
    logDebug('[ManageSubscriptionsController] fetchSubscriptions started');
    try {
      isLoading(true);
      errorMessage('');
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
        '[ManageSubscriptionsController] poll ConnectionException: ${e.message}',
      );
      if (surfaceErrors) errorMessage(e.message);
    } catch (e) {
      logDebug('[ManageSubscriptionsController] poll failed: $e');
      if (surfaceErrors) errorMessage('Failed to fetch subscriptions.');
    } finally {
      if (gen == _pollGeneration) _pollInFlight = false;
    }
  }

  Future<void> _loadAndApply({required bool notify}) async {
    final eid = RuntimeConfig.to.emiratesID;
    final data = await ApiService.getMobileSubscriptions(eid);
    // API already returns newest first (ORDER BY created_at DESC); sort defensively.
    data.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    subscriptions.value = data;

    final top = data.isEmpty ? null : data.first;
    final topId = top?.id ?? '';

    if (_lastSeenEid != eid) {
      _lastSeenEid = eid;
      _lastSeenId = topId.isEmpty ? null : topId;
      logDebug(
        '[ManageSubscriptionsController] seeded lastSeen for $eid → '
        '${_lastSeenId ?? "(empty)"}',
      );
      return;
    }

    if (top == null || topId.isEmpty) {
      _lastSeenId ??= '';
      return;
    }

    if (_lastSeenId == null) {
      _lastSeenId = topId;
      logDebug(
        '[ManageSubscriptionsController] baseline lastSeen=$topId (no banner)',
      );
      return;
    }

    if (topId == _lastSeenId) return;

    _lastSeenId = topId;
    logDebug(
      '[ManageSubscriptionsController] new subscription tip $topId '
      'status=${top.status} notify=$notify',
    );

    if (!notify) return;
    pendingBanner.value = top;
  }

  Future<void> approve(String id) async {
    final success = await ApiService.approveSubscription(
      id,
      RuntimeConfig.to.emiratesID,
    );
    // Quiet refresh: user already acted — don't raise a self-banner.
    if (success) await fetchSubscriptions();
    logDebug(
      '[ManageSubscriptionsController] approveSubscription for ID $id completed with success: $success',
    );
  }

  Future<void> reject(String id) async {
    final success = await ApiService.rejectSubscription(
      id,
      RuntimeConfig.to.emiratesID,
    );
    if (success) await fetchSubscriptions();
    logDebug(
      '[ManageSubscriptionsController] rejectSubscription for ID $id completed with success: $success',
    );
  }
}
