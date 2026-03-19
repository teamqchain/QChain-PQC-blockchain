import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/constants/colors.dart';

class QOnboardDots extends StatelessWidget {
  final int active;
  const QOnboardDots({required this.active, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i + 1 == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? qPrimary : qBorder,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
