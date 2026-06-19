import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/components/emptyState.dart';
import 'package:qwallet_mobileapp/components/shimmerWave.dart';
import 'package:qwallet_mobileapp/routes/main_shell.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';
import 'package:qwallet_mobileapp/model/subscription_model.dart';
import 'package:qwallet_mobileapp/controllers/manage_subscriptions_controller.dart';
import 'package:qwallet_mobileapp/Headers/QPageTitle.dart';
import 'package:qwallet_mobileapp/widgets/QSearchBar.dart';

class ManageSubscriptionsScreen extends StatefulWidget {
  const ManageSubscriptionsScreen({super.key});

  @override
  State<ManageSubscriptionsScreen> createState() =>
      _ManageSubscriptionsScreenState();
}

class _ManageSubscriptionsScreenState extends State<ManageSubscriptionsScreen> {
  final ManageSubscriptionsController controller = Get.put(
    ManageSubscriptionsController(),
  );
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Listen to text changes and update local state
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

   // ─── FILTER LOGIC ───
  // final filteredList = controller.subscriptions.where((s) {
  //   if (_query.isEmpty) return true;
  //   return s.credentialType.toLowerCase().contains(_query) ||
  //       s.verifierName.toLowerCase().contains(_query) ||
  //       s.status.toLowerCase().contains(_query);
  // }).toList();

  List<SubscriptionModel> get _filtered {
    return controller.subscriptions.where((s) {
      if (_query.isEmpty) return true;
      return s.credentialType.toLowerCase().contains(_query) ||
          s.verifierName.toLowerCase().contains(_query) ||
          s.status.toLowerCase().contains(_query)||
          s.credentialID.toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: qBg,
      body: Column(
        children: [
          // Screen Hero
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: qPrimary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 16,
              24,
              28,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    
                    // Back Button
                    GestureDetector(
                      onTap: () {
                        // Tell the shell to switch back to the Activity tab (index 3)
                        final mainShell = context
                            .findAncestorStateOfType<MainShellState>();
                        if (mainShell != null) {
                          mainShell.switchTab(3);
                        } else {
                          Get.back(); // Safe fallback
                        }
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1A1A1A),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: QPageTitle(
                        mainTitle: "Subscriptions",
                        subTitle: "Manage",
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: qAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.tune, color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Filter',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                QSearchBar(
                  controller:
                      _searchController, // Pass the TextEditingController
                  onChanged: (v) {}, // Handled by listener in initState
                  textInside: 'Search subscriptions…',
                ),
              ],
            ),
          ),

          // Main List
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const _SkeletonActivityList();
              }

              // if (controller.subscriptions.isEmpty) {
              //   return const Center(
              //     child: Text(
              //       'No subscriptions found.',
              //       style: TextStyle(color: Colors.grey),
              //     ),
              //   );
              // }

              if (_filtered.isEmpty) {
                return EmptyState(
                  query: _query,
                  mainMessage: "No subscriptions yet",
                  subMessage: "Your subscriptions will appear here",
                  resultMainMessage: "No results found",
                  resultSubMessage: 'Nothing matches "$_query"',
                );
              }

              // if (filteredList.isEmpty) {
              //   return Center(
              //     child: Text(
              //       'No results for "$_query".',
              //       style: const TextStyle(color: Colors.grey),
              //     ),
              //   );
              // }

              final pending = _filtered
                  .where((s) => s.status == 'pending')
                  .toList();
              final activeAndPast = _filtered
                  .where((s) => s.status != 'pending')
                  .toList();

              return RefreshIndicator(
                color: qPrimary,
                onRefresh: () => controller.fetchSubscriptions(),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (pending.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10, top: 4),
                        child: Text(
                          'PENDING REQUESTS',
                          style: TextStyle(
                            color: Color(0xFFAAAAAA),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      ...pending.map(
                        (s) => _SubscriptionTile(
                          subscription: s,
                          isPending: true,
                          controller: controller,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (activeAndPast.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10, top: 4),
                        child: Text(
                          'ACTIVE & PAST SUBSCRIPTIONS',
                          style: TextStyle(
                            color: Color(0xFFAAAAAA),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      ...activeAndPast.map(
                        (s) => _SubscriptionTile(
                          subscription: s,
                          isPending: false,
                          controller: controller,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  final SubscriptionModel subscription;
  final bool isPending;
  final ManageSubscriptionsController controller;

  const _SubscriptionTile({
    required this.subscription,
    required this.isPending,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEBEBEB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getIconColor(subscription.status).withOpacity(0.1),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _getIcon(subscription.status),
                    color: _getIconColor(subscription.status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscription.credentialID,
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subscription.credentialType,
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Requested by ${subscription.verifierName}',
                        style: const TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subscription.timeAgo,
                        style: const TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getIconColor(
                        subscription.status,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      subscription.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _getIconColor(subscription.status),
                      ),
                    ),
                  ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => controller.reject(subscription.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Reject',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => controller.approve(subscription.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: qValid,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Approve',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getIconColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
      case 'expired':
        return Colors.red;
      case 'unsubscribed':
        return Colors.grey;
      case 'pending':
      default:
        return const Color(0xFFE86924);
    }
  }

  IconData _getIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.verified_user_rounded;
      case 'rejected':
      case 'expired':
        return Icons.block_rounded;
      case 'unsubscribed':
        return Icons.notifications_off_rounded;
      case 'pending':
      default:
        return Icons.schedule_rounded;
    }
  }
}
class _SkeletonActivityList extends StatelessWidget {
  const _SkeletonActivityList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics:
          const NeverScrollableScrollPhysics(), // Prevent scrolling while loading
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: const [
        _SkeletonGroupHeader(),
        SkeletonActivityTile(),
        SizedBox(height: 8), // Replaces the 'isLast' padding logic temporarily
        _SkeletonGroupHeader(),
        SkeletonActivityTile(),
        SizedBox(height: 8),
        _SkeletonGroupHeader(),
        SkeletonActivityTile(),
        SkeletonActivityTile(),
      ],
    );
  }
}

class _SkeletonGroupHeader extends StatelessWidget {
  const _SkeletonGroupHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4, right: 320),
      // Wrap the header container in ShimmerWave
      child: ShimmerWave(
        child: Container(
          width: 60,
          height: 15, // Match the visual weight of the 10px text
          decoration: BoxDecoration(
            color: qDivider,
            borderRadius: BorderRadius.circular(4),
          ),
          // Alignment hack to make it stay on the left like the text
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}

class SkeletonActivityTile extends StatelessWidget {
  final double myheight; // Made final for best practices
  const SkeletonActivityTile({super.key, this.myheight = 40});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: qBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: qBorder),
          boxShadow: const [
            BoxShadow(color: qShadow, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        // Wrap the inner Row in ShimmerWave so the border stays static
        child: ShimmerWave(
          child: Row(
            children: [
              // Icon Placeholder
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: qDivider,
                ),
              ),
              const SizedBox(width: 14),
              // Text placeholders
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: myheight,
                      decoration: BoxDecoration(
                        color: qDivider,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80, // Shorter line representing the "time ago"
                      height: 12,
                      decoration: BoxDecoration(
                        color: qDivider,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
