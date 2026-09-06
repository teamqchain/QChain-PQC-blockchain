import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';

class EmptyState extends StatelessWidget {
  final String query;
  final String mainMessage;
  final String subMessage;

  final String resultMainMessage;
  final String resultSubMessage;

  const EmptyState({
    super.key,
    required this.query,
    required this.mainMessage,
    required this.subMessage,
    required this.resultMainMessage,
    required this.resultSubMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            query.isNotEmpty ? '🔍' : '📭',
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 14),
          Text(
            query.isNotEmpty ? resultMainMessage : mainMessage,
            style: TextStyle(
              color: qPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            query.isNotEmpty ? resultSubMessage : subMessage,
            style: TextStyle(color: Color(0xFF999999), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
