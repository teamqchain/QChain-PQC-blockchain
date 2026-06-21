import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  // final SubStatus status;
  final Color fg;
  final String label;
  final bool iconPresent;
  final IconData? icon;
  const StatusBadge({super.key, required this.fg, required this.label, required this.iconPresent, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: fg.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!iconPresent)...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
            ),
          ]else...[
            Icon(
              icon,
              size: 12,
              color: fg,
            ),
          ],
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
