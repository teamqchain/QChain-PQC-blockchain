import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/components/shimmerWave.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';


class SkeletonExploreList extends StatelessWidget {
  const SkeletonExploreList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics:
          const NeverScrollableScrollPhysics(), // Prevent scroll while loading
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      itemCount: 4, // Show 4 dummy categories to fill the screen
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Title Placeholder wrapped in ShimmerWave
              ShimmerWave(
                child: Container(
                  width: 140,
                  height: 20,
                  decoration: BoxDecoration(
                    color: qDivider, // Matches mockup light grey
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Issuer Tile Placeholders
              const SkeletonIssuerTile(isHome: false),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class SkeletonIssuerTile extends StatelessWidget {
  final bool isHome;

  const SkeletonIssuerTile({super.key, required this.isHome});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: qBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: qBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      // Wrap the inner row with ShimmerWave so the border stays static
      child: ShimmerWave(
        child: Row(
          children: [
            // Icon Box Placeholder
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: qDivider,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 14),
            // Text Lines Placeholder
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 180),
                    height: 14,
                    decoration: BoxDecoration(
                      color: qDivider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 110,
                    height: 12,
                    decoration: BoxDecoration(
                      color: qDivider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Chevron Down Placeholder
            !isHome
                ? const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.black,
                    size: 24,
                  )
                : const Icon(Icons.star, color: qDivider, size: 20),
          ],
        ),
      ),
    );
  }
}
