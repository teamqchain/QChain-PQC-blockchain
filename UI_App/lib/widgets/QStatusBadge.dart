import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';


class QStatusBadge extends StatelessWidget {
  final String status;
  const QStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, String label) = switch (status) {
      'Valid' => (qValid, qValidBg, '● Valid'),
      'Expired' => (qAmber, qAmberBg, '● Expired'),
      'Revoked' => (qRed, qRedBg, '● Revoked'),
      _ => (qMuted, qCard, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
