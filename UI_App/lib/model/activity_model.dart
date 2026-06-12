import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';

class ActivityModel {
  final String id;
  final String type;
  final String credentialName;
  final String actor;
  final DateTime timestamp;

  ActivityModel({
    required this.id,
    required this.type,
    required this.credentialName,
    required this.actor,
    required this.timestamp,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'] ?? '',
      type: json['type']?.toString().toLowerCase() ?? 'unknown',
      credentialName: json['credentialName'] ?? 'Credential',
      actor: json['actor'] ?? 'System',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  // ─── UI MAPPERS ────────────────────────────────────────────────────────────

  String get actionText {
    switch (type) {
      case 'issued':
        return '$credentialName issued by $actor';
      case 'verified':
        return '$credentialName verified by $actor';
      case 'revoked':
        return '$credentialName revoked by $actor';
      case 'suspended':
        return '$credentialName suspended by $actor';
      case 'restored':
        return '$credentialName restored by $actor';
      default:
        return '$credentialName updated';
    }
  }

  IconData get icon {
    switch (type) {
      case 'issued':
      case 'restored':
        return Icons.download;
      case 'verified':
        return Icons.verified_user;
      case 'revoked':
        return Icons.block;
      case 'suspended':
        return Icons.pause_circle_outline;
      default:
        return Icons.info_outline;
    }
  }

  Color get iconBgColor {
    switch (type) {
      case 'issued':
      case 'restored':
        return qCredDownload;
      case 'verified':
        return qValid;
      case 'revoked':
        return Colors.red;
      case 'suspended':
        return Colors.orange;
      default:
        return qPrimary;
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }
}
