import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';

class QPrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const QPrimaryBtn(this.label, {this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: qPrimary,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: qBg,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
