import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';

class CountChip extends StatelessWidget {
  const CountChip({
    super.key,
    required this.count,
    required this.label,
    this.pluralLabel,
    this.zeroLabel,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
  });

  final int count;
  final String label;
  final String? pluralLabel;
  final String? zeroLabel;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;

  String get _displayLabel {
    if (count == 0 && zeroLabel != null) return zeroLabel!;
    if (count == 1) return label;
    return pluralLabel ?? '${label}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.issuingAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor ?? AppColors.issuingAccent.withOpacity(0.25),
        ),
      ),
      child: Text(
        '$count $_displayLabel',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor ?? AppColors.issuingLight,
        ),
      ),
    );
  }
}
