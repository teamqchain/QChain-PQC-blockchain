import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/controllers/activity_controller.dart';
import 'package:qwallet_mobileapp/controllers/manage_subscriptions_controller.dart';
import 'package:qwallet_mobileapp/routes/QBottomNav.dart';
import 'package:qwallet_mobileapp/screens/activity_screen.dart';
import 'package:qwallet_mobileapp/screens/add_document_screen.dart';
import 'package:qwallet_mobileapp/screens/home_screen.dart';
import 'package:qwallet_mobileapp/screens/manage_subscriptions_screen.dart';
import 'package:qwallet_mobileapp/screens/settings_screen.dart';
import 'package:qwallet_mobileapp/screens/wallet_screen.dart';
import 'package:qwallet_mobileapp/widgets/ios_activity_banner.dart';

/// Shell for a live holder session (post onboarding / keys).
/// Hosts tab UI + foreground-only activity / subscription banner polling.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  late final ActivityController _activity;
  late final ManageSubscriptionsController _subscriptions;

  void switchTab(int index) {
    setState(() => _index = index);
  }

  // All your tab screens live here, pre-built
  static const _screens = [
    HomeScreen(),
    WalletScreen(),
    AddDocumentScreen(),
    ActivityScreen(),
    SettingsScreen(),
    ManageSubscriptionsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activity = Get.isRegistered<ActivityController>()
        ? Get.find<ActivityController>()
        : Get.put(ActivityController(), permanent: true);
    _subscriptions = Get.isRegistered<ManageSubscriptionsController>()
        ? Get.find<ManageSubscriptionsController>()
        : Get.put(ManageSubscriptionsController(), permanent: true);
    _activity.startActivityPolling();
    _subscriptions.startSubscriptionPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activity.stopActivityPolling();
    _subscriptions.stopSubscriptionPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only poll while the app is visibly in the foreground with a session.
    if (state == AppLifecycleState.resumed) {
      _activity.startActivityPolling(catchUp: true);
      _subscriptions.startSubscriptionPolling(catchUp: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      // Don't stop on inactive — that fires during control center / brief blurs.
      _activity.stopActivityPolling();
      _subscriptions.stopSubscriptionPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(
              key: ValueKey(_index),
              child: _screens[_index],
            ),
          ),
          // One iOS-style banner at a time. Activity wins if both are pending.
          // Read both Rx values first so Obx always tracks each source.
          Obx(() {
            final activity = _activity.pendingBanner.value;
            final sub = _subscriptions.pendingBanner.value;

            if (activity != null) {
              return IosActivityBanner(
                key: ValueKey('activity_${activity.id}'),
                title: activity.bannerTitle,
                subtitle: activity.bannerSubtitle,
                onDismiss: _activity.dismissBanner,
                onTap: () {
                  _activity.dismissBanner();
                  switchTab(3); // Activity tab
                },
              );
            }

            if (sub == null) return const SizedBox.shrink();
            return IosActivityBanner(
              key: ValueKey('sub_${sub.id}'),
              title: ManageSubscriptionsController.bannerTitle(sub),
              subtitle: ManageSubscriptionsController.bannerSubtitle(sub),
              onDismiss: _subscriptions.dismissBanner,
              onTap: () {
                _subscriptions.dismissBanner();
                switchTab(5); // Manage subscriptions
              },
            );
          }),
        ],
      ),
      bottomNavigationBar: QBottomNav(
        currentIndex: _index == 5 ? 3 : _index,
        onTap: switchTab,
      ),
    );
  }
}
