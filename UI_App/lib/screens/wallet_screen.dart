import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/Headers/walletHeader.dart';
import 'package:qwallet_mobileapp/components/categoryTile.dart';
import 'package:qwallet_mobileapp/components/emptyState.dart';
import 'package:qwallet_mobileapp/components/shimmerWave.dart';
import 'package:qwallet_mobileapp/controllers/wallet_controller.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';

  // Inject the WalletController
  final WalletController _walletController = Get.find<WalletController>();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Obx(() {
        final totalDocs = _walletController.credentials.length;
        final liveCategories = _walletController.dynamicCategories;
        final isLoading =
            _walletController.isLoading.value; // Store loading state

        final filteredList = _query.trim().isEmpty
            ? liveCategories
            : liveCategories
                  .where(
                    (c) =>
                        c.title.toLowerCase().contains(_query.toLowerCase()) ||
                        c.subtitle.toLowerCase().contains(_query.toLowerCase()),
                  )
                  .toList();

        return Column(
          children: [
            WalletHeader(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              totalDocs: totalDocs,
              isLoading: isLoading, // Pass loading state to header
            ),
            Expanded(
              child: isLoading
                  ? const _SkeletonCategoryGrid() // Use skeleton grid here
                  : filteredList.isEmpty
                  ? EmptyState(
                      query: _query,
                      mainMessage: "No categories found",
                      subMessage: 'Your credential categories will appear here',
                      resultMainMessage: 'No results found',
                      resultSubMessage: 'Nothing matches "$_query"',
                    )
                  : RefreshIndicator(
                      color: qPrimary,
                      onRefresh: () async {
                        await _walletController.fetchMyCredentials();
                        if (_walletController.errorMessage.value.isNotEmpty) {
                          Get.snackbar(
                            'Network Error',
                            _walletController.errorMessage.value,
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: qRed,
                            colorText: qSecondary,
                          );
                        }
                      },
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        thickness: 6,
                        radius: const Radius.circular(10),
                        child: GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                mainAxisExtent: 160,
                              ),
                          itemCount: filteredList.length,
                          itemBuilder: (_, i) =>
                              CategoryTile(category: filteredList[i]),
                        ),
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }
}

// ─── SKELETON WIDGETS ────────────────────────────────────────────────────────

class _SkeletonCategoryGrid extends StatelessWidget {
  const _SkeletonCategoryGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics:
          const NeverScrollableScrollPhysics(), // Prevent scrolling while loading
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: 160,
      ),
      itemCount: 6, // Show 6 dummy tiles
      itemBuilder: (_, __) => const _SkeletonTile(),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: qBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qBorder),
        boxShadow: const [
          BoxShadow(color: qShadow, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      // Wrap the inner column with ShimmerWave so only the placeholders shimmer
      child: ShimmerWave(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Placeholder
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: qDivider,
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                // Count Badge Placeholder
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 4, right: 4),
                  decoration: const BoxDecoration(
                    color: qPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Title Placeholder
            Container(
              width: 50,
              height: 12,
              decoration: BoxDecoration(
                color: qDivider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle Placeholder
            Container(
              width: 80,
              height: 10,
              decoration: BoxDecoration(
                color: qDivider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
