import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/utils/dateFormatter.dart';

enum AlertSeverity { revoked, expired, suspended, tampered, renewed, reissued }

extension AlertSeverityX on AlertSeverity {
  Color get color {
    switch (this) {
      case AlertSeverity.revoked:
        return AppColors.revoked;
      case AlertSeverity.expired:
        return AppColors.expired;
      case AlertSeverity.suspended:
        return AppColors.suspended;
      case AlertSeverity.tampered:
        return const Color(0xFFF97316);
      case AlertSeverity.renewed:
        return AppColors.valid;
      case AlertSeverity.reissued:
        return const Color(0xFF60A5FA);
    }
  }

  IconData get icon {
    switch (this) {
      case AlertSeverity.revoked:
        return Icons.block_rounded;
      case AlertSeverity.expired:
        return Icons.schedule_rounded;
      case AlertSeverity.suspended:
        return Icons.pause_circle_outline_rounded;
      case AlertSeverity.tampered:
        return Icons.warning_amber_rounded;
      case AlertSeverity.renewed:
        return Icons.autorenew_rounded;
      case AlertSeverity.reissued:
        return Icons.refresh_rounded;
    }
  }
}

class LiveAlertRecord {
  final String id;
  final String credentialID;
  final String holderName;
  final String credentialName;
  final AlertSeverity severity;
  final String description;
  final String dateTime;
  bool acknowledged;

  LiveAlertRecord({
    required this.id,
    required this.credentialID,
    required this.holderName,
    required this.credentialName,
    required this.severity,
    required this.description,
    required this.dateTime,
    this.acknowledged = false,
  });

  factory LiveAlertRecord.fromJson(Map<String, dynamic> e) {
    return LiveAlertRecord(
      id: e['id'] as String? ?? '',
      credentialID: e['credentialID'] as String? ?? '',
      holderName: e['holderName'] as String? ?? '',
      credentialName: e['credentialName'] as String? ?? '',
      severity: _parseAlertSeverity(e['severity'] as String? ?? 'revoked'),
      description: e['description'] as String? ?? '',
      // Format the date string as it comes in
      dateTime: DateFormatter.formatDateTime(e['dateTime'] as String? ?? ''),
      acknowledged: e['acknowledged'] as bool? ?? false,
    );
  }

  static AlertSeverity _parseAlertSeverity(String s) {
    switch (s.toLowerCase()) {
      case 'revoked':
        return AlertSeverity.revoked;
      case 'expired':
        return AlertSeverity.expired;
      case 'suspended':
        return AlertSeverity.suspended;
      case 'tampered':
        return AlertSeverity.tampered;
      case 'renewed':
        return AlertSeverity.renewed;
      case 'reissued':
        return AlertSeverity.reissued;
      default:
        return AlertSeverity.revoked;
    }
  }
}
