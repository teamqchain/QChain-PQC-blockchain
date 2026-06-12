import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';

class QSectionLabel extends StatelessWidget {
  final String label;
  const QSectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: qMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}
