import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';

class ActivityModel {
  final String id;
  final String credentialID;
  final String type;
  final String credentialName;
  final String actor;
  final DateTime timestamp;

  ActivityModel({
    required this.id,
    required this.credentialID,
    required this.type,
    required this.credentialName,
    required this.actor,
    required this.timestamp,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'] ?? '',
      credentialID: json['credentialID'] ?? '',
      type: json['type']?.toString().toLowerCase() ?? 'unknown',
      credentialName: json['credentialName'] ?? 'Credential',
      actor: json['actor'] ?? 'System',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  // ─── UI MAPPERS ────────────────────────────────────────────────────────────

  /// Full sentence used in the activity feed list.
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

  /// Short primary line for the in-app notification banner.
  String get bannerTitle {
    final id = credentialID.trim();
    final hasId = id.isNotEmpty;
    switch (type) {
      case 'issued':
        return 'New Credential Issued';
      case 'verified':
        return hasId ? '$id verified' : 'Credential Verified';
      case 'revoked':
        return hasId ? '$id revoked' : 'Credential Revoked';
      case 'suspended':
        return hasId ? '$id suspended' : 'Credential Suspended';
      case 'restored':
        return hasId ? '$id restored' : 'Credential Restored';
      default:
        return hasId ? '$id updated' : 'Credential updated';
    }
  }

  /// Secondary line under [bannerTitle] (who / which credential).
  String get bannerSubtitle {
    switch (type) {
      case 'issued':
        return '$credentialName · $actor';
      case 'verified':
      case 'revoked':
      case 'suspended':
      case 'restored':
        return '$credentialName · $actor';
      default:
        return credentialName;
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

  // ActivityModel in activity_model.dart
  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);

    // Safeguard against negative differences (future times)
    if (diff.isNegative) return 'Negative Time'; // Or handle it however you prefer

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }
}
