import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/dashboard_Model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/widgets/dashboard_widgets.dart';

class StatChipsRow extends StatelessWidget {
  final DashboardVariant variant;
  final Map<String, dynamic> stats; // Added

  const StatChipsRow({super.key, required this.variant, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (variant.canIssue) ...[
          StatChip(
            label: 'Issued Today',
            value: stats['totalIssued'] ?? 0,
            accent: AppColors.issuingAccent,
          ),
          StatChip(
            label: 'Alerts Unread',
            value: stats['totalSuspended'] ?? 0,
            accent: AppColors.suspended,
          ),
          StatChip(
            label: 'Expiring Soon',
            value: stats['totalExpired'] ?? 0,
            accent: AppColors.revoked,
          ),
        ] else if (variant.canVerify) ...[
          StatChip(
            label: 'Verified Today',
            value: stats['totalVerified'] ?? 0,
            accent: AppColors.verifyingAccent,
          ),
          StatChip(
            label: 'Alerts Unread',
            value: stats['totalSuspended'] ?? 0,
            accent: AppColors.suspended,
          ),
          StatChip(
            label: 'Expiring Soon',
            value: stats['totalExpired'] ?? 0,
            accent: AppColors.revoked,
          ),
        ] else ...[
          StatChip(
            label: 'Issuing Staffs',
            value: stats['issuerStaffCount'] ?? 6,
            accent: AppColors.adminAccent,
          ),
          StatChip(
            label: 'Verifying Staffs',
            value: stats['verifierStaffCount'] ?? 6,
            accent: AppColors.verifyingAccent,
          ),
        ],
      ],
    );
  }
}
