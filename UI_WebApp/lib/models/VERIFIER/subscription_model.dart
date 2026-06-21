import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';


enum SubStatus { active, pending, unsubscribed, rejected, expired }

extension SubStatusX on SubStatus {
  String get label {
    switch (this) {
      case SubStatus.active:
        return 'Active';
      case SubStatus.pending:
        return 'Pending';
      case SubStatus.unsubscribed:
        return 'Unsubscribed';
      case SubStatus.rejected:
        return 'Rejected';
      case SubStatus.expired:
        return 'Expired';
    }
  }

  Color get fg {
    switch (this) {
      case SubStatus.active:
        return AppColors.valid;
      case SubStatus.pending:
        return const Color(0xFF60A5FA);
      case SubStatus.unsubscribed:
        return AppColors.textMuted;
      case SubStatus.rejected:
        return AppColors.revoked;
      case SubStatus.expired:
        return AppColors.expired;
    }
  }
}

class SubscriptionRecord {
  final String id;
  final String credentialID;
  final String holderName;
  final String holderId;
  final String credentialType;
  final String issuer;
  final String subscribedDate; // '—' when still pending / rejected
  final String expiryDate; // '—' when no expiry set yet
  final SubStatus status;

  const SubscriptionRecord({
    required this.id,
    required this.credentialID,
    required this.holderName,
    required this.holderId,
    required this.credentialType,
    required this.issuer,
    required this.subscribedDate,
    required this.expiryDate,
    required this.status,
  });

  factory SubscriptionRecord.fromJson(Map<String, dynamic> e) {
    return SubscriptionRecord(
      id: e['id'] as String? ?? '',
      credentialID: e['credentialID'] as String? ?? '',
      holderName: e['holderName'] as String? ?? '',
      holderId: e['holderID'] as String? ?? '',
      credentialType: e['credentialType'] as String? ?? '',
      issuer: e['issuer'] as String? ?? '',
      subscribedDate: e['subscribedDate'] as String? ?? '—',
      expiryDate: e['expiryDate'] as String? ?? '—',
      status: _parseSubStatus(e['status'] as String? ?? 'pending'),
    );
  }

  static SubStatus _parseSubStatus(String s) {
    switch (s.toLowerCase()) {
      case 'active':
        return SubStatus.active;
      case 'unsubscribed':
        return SubStatus.unsubscribed;
      case 'rejected':
        return SubStatus.rejected;
      case 'expired':
        return SubStatus.expired;
      default:
        return SubStatus.pending;
    }
  }
}
