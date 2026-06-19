import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/Headers/QPageTitle.dart';
import 'package:qwallet_mobileapp/components/emptyState.dart';
import 'package:qwallet_mobileapp/components/shimmerWave.dart';
import 'package:qwallet_mobileapp/routes/main_shell.dart';
import 'package:qwallet_mobileapp/screens/add_document_screen.dart';
import 'package:qwallet_mobileapp/screens/home_screen.dart';
import 'package:qwallet_mobileapp/screens/manage_subscriptions_screen.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';
import 'package:qwallet_mobileapp/widgets/QSearchBar.dart';
import 'package:qwallet_mobileapp/model/activity_model.dart';
import 'package:qwallet_mobileapp/controllers/activity_controller.dart'; // <-- Import new controller

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final ActivityController controller = Get.put(ActivityController());
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      () =>
          setState(() => _query = _searchController.text.toLowerCase().trim()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ActivityModel> get _filtered {
    if (_query.isEmpty) return controller.activities;
    return controller.activities
        .where(
          (a) =>
              a.actionText.toLowerCase().contains(_query) ||
              a.credentialName.toLowerCase().contains(_query)||
              a.credentialID.toLowerCase().contains(_query),
        )
        .toList();
  }

  Map<String, List<ActivityModel>> get _grouped {
    final map = <String, List<ActivityModel>>{};
    for (final item in _filtered) {
      final key = _dayLabel(item.timestamp);
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCompare = DateTime(date.year, date.month, date.day);

    if (dateToCompare == today) return 'Today';
    if (dateToCompare == yesterday) return 'Yesterday';
    return 'Earlier';
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: qBg,
      body: Column(
        children: [
          _ActivityHeroBox(
            controller: _searchController,
            query: _query,
            onChanged: (v) {},
          ),

          // ─── NEW: MANAGE SUBSCRIPTIONS BANNER ───
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: GestureDetector(
              onTap: () {
                final mainShell = context
                    .findAncestorStateOfType<MainShellState>();
                if (mainShell != null) {
                  mainShell.switchTab(5);
                } else {
                  Get.to(
                    () => const ManageSubscriptionsScreen(),
                  ); // Safe fallback
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111), // Black container
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Manage\nSubscriptions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'See all subscription',
                            style: TextStyle(
                              color: const Color(0xFFAAAAAA),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Obx(() {
                      final count = controller.pendingSubscriptionsCount.value;
                      if (count > 0) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE86924,
                            ), // Orange action badge
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Action\nRequired',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    const SizedBox(width: 14),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ────────────────────────────────────────
          Expanded(
            child: Obx(() {
              // ─── SKELETON LOADING INJECTION ───
              if (controller.isLoading.value) {
                return const _SkeletonActivityList();
              }

              final grouped = _grouped;
              final groups = grouped.keys.toList();

              if (_filtered.isEmpty) {
                return EmptyState(
                  query: _query,
                  mainMessage: "No activity yet",
                  subMessage: "Your credential activity will appear here",
                  resultMainMessage: "No results found",
                  resultSubMessage: 'Nothing matches "$_query"',
                );
              }

              return RefreshIndicator(
                color: qPrimary,
                onRefresh: () async {
                  await controller.fetchActivity();
                  if (controller.errorMessage.value.isNotEmpty) {
                    Get.snackbar(
                      'Network Error',
                      controller.errorMessage.value,
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: qRed,
                      colorText: qSecondary,
                    );
                  }
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  itemCount: groups.fold<int>(
                    0,
                    (sum, g) => sum + 1 + grouped[g]!.length,
                  ),
                  itemBuilder: (context, index) {
                    int cursor = 0;
                    for (final group in groups) {
                      if (index == cursor) return _GroupHeader(label: group);
                      cursor++;

                      final items = grouped[group]!;
                      if (index < cursor + items.length) {
                        final item = items[index - cursor];
                        final isLast = index == cursor + items.length - 1;
                        return _ActivityTile(item: item, isLast: isLast);
                      }
                      cursor += items.length;
                    }
                    return const SizedBox();
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO BOX
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityHeroBox extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;

  const _ActivityHeroBox({
    required this.controller,
    required this.query,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: qPrimary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: QPageTitle(mainTitle: "Activity", subTitle: "History"),
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
            controller: controller,
            onChanged: onChanged,
            textInside: 'Search activity…',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFAAAAAA),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY TILE
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final ActivityModel item;
  final bool isLast;

  const _ActivityTile({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 16 : 8),
      child: Container(
        padding: const EdgeInsets.all(14),
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
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.iconBgColor,
              ),
              alignment: Alignment.center,
              child: Icon(item.icon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.credentialID,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.actionText,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.timeAgo,
                    style: const TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SKELETON LOADING WIDGETS ────────────────────────────────────────────────

// ─── SKELETON LOADING WIDGETS ────────────────────────────────────────────────

/// A custom animation wrapper that creates a left-to-right "wave" (shimmer) effect.
/// It uses a ShaderMask to add a sweeping highlight over the underlying shapes
/// while preserving your custom colors.

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
