import 'package:flutter/widgets.dart';

class WalletCategory {
  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final String id;

  const WalletCategory({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
  });
}
