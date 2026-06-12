import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';
class QSearchBar extends StatelessWidget {
  const QSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.textInside
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String textInside;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: qBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search, color: qText, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                color: qPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              decoration:  InputDecoration(
                // hintText: 'Search categories...',
                hintText: textInside,
                hintStyle: TextStyle(color: qSub, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              cursorColor: qPrimary,
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}
