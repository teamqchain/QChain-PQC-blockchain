import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';


abstract class AppTextStyles {
  static const pageTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.white,
  );

  static const sectionLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
    // letterSpacing: 1.2,
  );

  static const bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
  );

  static const bodyTiny = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  static const statValue = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.white,
    fontFamily: 'SFPro',
  );

  static const navLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  static const navLabelActive = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );

  static const badge = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w800,
    // letterSpacing: 0.8,
  );

  static const linkText = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );
}
