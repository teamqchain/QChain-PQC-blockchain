import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';

class Label extends StatelessWidget {
  final String text;
  final bool required;
  final String? counter;
  final bool counterExceeded;

  const Label({
    required this.text,
    this.required = false,
    this.counter,
    this.counterExceeded = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        text,
        style: AppTextStyles.bodyTiny.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: AppColors.textMuted,
        ),
      ),
      if (required) ...[
        const SizedBox(width: 3),
        const Text(
          '*',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.revoked,
          ),
        ),
      ],
      const Spacer(),
      if (counter != null)
        Text(
          counter!,
          style: TextStyle(
            fontSize: 10,
            color: counterExceeded ? AppColors.revoked : AppColors.textDim,
            fontWeight: counterExceeded ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
    ],
  );
}
