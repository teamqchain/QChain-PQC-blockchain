import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/components/shimmerWave.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';

/// A custom animation wrapper that creates a left-to-right "wave" (shimmer) effect.
/// It uses a ShaderMask to add a sweeping highlight over the underlying shapes
/// while preserving your custom colors.

class SkeletonActivityList extends StatelessWidget {
  const SkeletonActivityList({super.key});

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
