import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';

// ignore: must_be_immutable
class QPageTitle extends StatelessWidget {
  final String mainTitle;
  final String subTitle;
  double mainFontSize;
  double subFontSize;

  QPageTitle({
    super.key,
    required this.mainTitle,
    required this.subTitle,
    this.mainFontSize = 26,
    this.subFontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subTitle,
          style: TextStyle(
            color: qSub,
            fontSize: subFontSize,
            letterSpacing: 0.2,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 2),
        Text(
          mainTitle,
          style: TextStyle(
            color: qSecondary,
            fontSize: mainFontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
          overflow: TextOverflow.ellipsis,

        ),
      ],
    );
  }
}
