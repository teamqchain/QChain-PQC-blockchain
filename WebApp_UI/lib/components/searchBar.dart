import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';

class QSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final void Function(String) onChanged;
  final VoidCallback onClear;
  final double? barWidth;
  final searchLabel;
  final Color? activeColor;

  const QSearchBar({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
    this.barWidth,
    required this.searchLabel,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.white;
    final fg = AppColors.bg;
    final borderColor =
        (activeColor != null && query.isNotEmpty) ? activeColor! : AppColors.border;

    return Container(
      width: barWidth,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 14, color: AppColors.textDim),
          const SizedBox(width: 7),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(fontSize: 12, color: fg),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: searchLabel,
                hintStyle: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 12,
                  color: AppColors.textDim,
                ),
              ),
              onChanged: onChanged,
            ),
          ),
          if (query.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 13, color: AppColors.textDim),
            ),
        ],
      ),
    );
  }
}
