import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/constants/colors.dart';

class QOutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const QOutlineBtn(this.label, {this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: qBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: qSub,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
