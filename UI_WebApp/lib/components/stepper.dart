// widgets/issuer/issuer_step_strip.dart
//
// Reusable step-progress strip used by:
//   • IssueSingleCredentialPage
//   • IssueBatchCredentialPage
//
// Usage:
//   IssuerStepStrip(
//     currentStep : _step,          // 1-based
//     stepLabels  : _kStepLabels,   // List<String>
//     accentColor : AppColors.issuingAccent,
//   )

import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/view/responsive_layout.dart';

class IssuerStepStrip extends StatelessWidget {
  final int currentStep;
  final List<String> stepLabels;
  final Color accentColor;

  const IssuerStepStrip({
    super.key,
    required this.currentStep,
    required this.stepLabels,
    this.accentColor = AppColors.issuingAccent,
  });

  @override
  Widget build(BuildContext context) {
    final small = isSmallScreen(context);
    final total = stepLabels.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(total, (i) {
          final n = i + 1;
          final isActive = n == currentStep;
          final isDone = n < currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: small ? 2 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ── circle ────────────────────────────────────────
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone
                                ? Colors.white.withOpacity(0.9)
                                : isActive
                                ? Colors.white
                                : Colors.white.withOpacity(0.28),
                          ),
                          child: Center(
                            child: isDone
                                ? Icon(
                                    Icons.check,
                                    size: 11,
                                    color: accentColor,
                                  )
                                : Text(
                                    '$n',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: isActive
                                          ? accentColor
                                          : Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                          ),
                        ),
                        // ── label (hidden on small screens) ───────────────
                        if (!small) ...[
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              stepLabels[i],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isActive || isDone
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.5),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // ── connector line ─────────────────────────────────────
                if (i < total - 1)
                  Container(
                    width: 10,
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: Colors.white.withOpacity(0.22),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
