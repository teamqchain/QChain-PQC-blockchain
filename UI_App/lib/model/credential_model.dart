import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';

class CredentialModel {
  final String credentialID;
  final String credentialType;
  final String holderName;
  final String holderEID;
  final String issuedBy;
  final String issuedAt;
  final String? expiryDate;
  final String status;
  bool isFavorite;
  final String category;

  CredentialModel({
    required this.credentialID,
    required this.credentialType,
    required this.holderName,
    required this.holderEID,
    required this.issuedBy,
    required this.issuedAt,
    this.expiryDate,
    required this.status,
    this.isFavorite = false,
    required this.category,
  });

  factory CredentialModel.fromJson(Map<String, dynamic> json) {
    return CredentialModel(
      credentialID: json['credentialID'] ?? '',
      credentialType: json['credentialType'] ?? 'Document',
      holderName: json['holderName'] ?? 'Unknown',
      holderEID: json['holderEID'] ?? '',
      issuedBy: json['issuedBy'] ?? 'Unknown Issuer',
      issuedAt: json['issuedAt'] ?? '',
      expiryDate: json['expiryDate'],
      status: json['status'] ?? 'active',
      isFavorite: json['isFavorite'] == true || json['isFavorite'] == 1,
      category: json['category'] ?? 'General',
    );
  }

  // ─── UI MAPPERS ────────────────────────────────────────────────────────────

  IconData get icon {
    final type = credentialType.toLowerCase();
    if (type.contains('bachelor') || type.contains('science'))
      return Icons.school;
    if (type.contains('health') || type.contains('medical'))
      return Icons.local_hospital;
    if (type.contains('passport') || type.contains('visa'))
      return Icons.menu_book;
    if (type.contains('insurance')) return Icons.shield;
    return Icons.badge;
  }

  Color get cardColor {
    final type = credentialType.toLowerCase();
    if (type.contains('bachelor') || type.contains('science')) return qAmethyst;
    if (type.contains('health') || type.contains('medical')) return qCherryRed;
    if (type.contains('visa') || type.contains('residence')) return qLeafGreen;
    if (type.contains('passport')) return qMagentaPink;
    return qAzureBlue; // Default
  }

  String get displayStatus {
    if (status.toLowerCase() == 'active') return 'Valid';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  String get formattedIssueDate {
    if (issuedAt.isEmpty) return 'Unknown';
    // Converts "2025-01-15T10:00:00" to "15 Jan 2025" logic can be expanded here
    try {
      final dt = DateTime.parse(issuedAt);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return issuedAt.split('T').first;
    }
  }

  String get formattedExpiryDate {
    if (expiryDate == null || expiryDate!.isEmpty) return 'No Expiry';
    try {
      final dt = DateTime.parse(expiryDate!);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return expiryDate!;
    }
  }
}
