import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/utils/dateFormatter.dart';



class AuditEntry {
  final String action;
  final String performedBy;
  final String date;
  final String? note;
  const AuditEntry({
    required this.action,
    required this.performedBy,
    required this.date,
    this.note,
  });
}

enum LiveAuditAction {
  issued,
  revoked,
  suspended,
  verified,
  policy,
  system,
  error,
  restore,
  management,
}

extension LiveAuditActionX on LiveAuditAction {
  String get label {
    switch (this) {
      case LiveAuditAction.issued:
        return 'Issued';
      case LiveAuditAction.revoked:
        return 'Revoked';
      case LiveAuditAction.suspended:
        return 'Suspended';
      case LiveAuditAction.verified:
        return 'Verified';
      case LiveAuditAction.policy:
        return 'Policy Change';
      case LiveAuditAction.system:
        return 'System Config';
      case LiveAuditAction.restore:
        return 'Restored';
      case LiveAuditAction.management:
        return 'Management';
      case LiveAuditAction.error:
        return 'Error';
    }
  }

  Color get colour {
    switch (this) {
      case LiveAuditAction.issued:
        return AppColors.issuingAccent;
      case LiveAuditAction.revoked:
        return AppColors.revoked;
      case LiveAuditAction.suspended:
        return AppColors.suspended;
      case LiveAuditAction.verified:
        return AppColors.verifyingAccent;
      case LiveAuditAction.policy:
        return const Color(0xFFF97316);
      case LiveAuditAction.system:
        return AppColors.adminAccent;
      case LiveAuditAction.restore:
        return AppColors.expired;
      case LiveAuditAction.management:
        return AppColors.adminLight;
      case LiveAuditAction.error:
        return AppColors.revoked;
    }
  }
}

class LiveAuditLogRecord {
  final String id;
  final LiveAuditAction action;
  final String details;
  final String performedBy;
  final String performedByRole;
  final String ipAddress;
  final String timestamp;

  LiveAuditLogRecord({
    required this.id,
    required this.action,
    required this.details,
    required this.performedBy,
    required this.performedByRole,
    required this.ipAddress,
    required this.timestamp,
  });

  factory LiveAuditLogRecord.fromJson(Map<String, dynamic> e) {
    final detailsStr = e['details'] as String? ?? '';

    return LiveAuditLogRecord(
      id: e['id'] as String? ?? '',
      action: _parseAuditAction(e['action'] as String? ?? '', detailsStr),
      details: detailsStr,
      performedBy: e['performedBy'] as String? ?? '',
      performedByRole: e['performedByRole'] as String? ?? '',
      ipAddress: e['ipAddress'] as String? ?? '',
      timestamp: DateFormatter.formatIsoDateAndTime(e['timestamp'] as String? ?? ''),
    );
  }

  static LiveAuditAction _parseAuditAction(String action, String details) {
    final normalizedAction = action.toLowerCase();
    final normalizedDetails = details.toLowerCase();

    switch (normalizedAction) {
      case 'issued':
        return LiveAuditAction.issued;
      case 'revoked':
        return LiveAuditAction.revoked;
      case 'suspended':
        return LiveAuditAction.suspended;
      case 'verified':
        return LiveAuditAction.verified;
      case 'policy_changed':
        return LiveAuditAction.policy;
      case 'system_config':
        return LiveAuditAction.system;
      default:
        // --- Keyword Fallbacks from Details ---
        if (normalizedDetails.contains('restored')) {
          return LiveAuditAction
              .restore; // Make sure .restore exists in your LiveAuditAction enum!
        }
        if (normalizedDetails.contains('invited') ||
            normalizedDetails.contains('removed')) {
          return LiveAuditAction
              .management; // Example of mapping keywords to existing enums
        }
        // Add any other specific keyword checks here...

        // Ultimate fallback if no keywords match
        return LiveAuditAction.error;
    }
  }
}
