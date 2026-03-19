import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/dashboard_Model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/widgets/dashboard_widgets.dart';


class StatChipsRow extends StatelessWidget {
  final DashboardVariant variant;
  const StatChipsRow({super.key, required this.variant});

  @override
  Widget build(BuildContext context) {
    // Wrap handles both large (single row) and small (wraps to 2x2 grid)
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (variant.canIssue)...[
          StatChip(
            label: 'Issued Today',
            value: 12,
            accent: AppColors.issuingAccent,
          ),
          StatChip(label: 'Alerts Unread', value: 3, accent: AppColors.suspended),
          StatChip(label: 'Expiring Soon', value: 5, accent: AppColors.revoked),
        ]else if (variant.canVerify)...[
          StatChip(
            label: 'Verified Today',
            value: 47,
            accent: AppColors.verifyingAccent,
          ),
          StatChip(
            label: 'Alerts Unread',
            value: 3,
            accent: AppColors.suspended,
          ),
          StatChip(label: 'Expiring Soon', value: 5, accent: AppColors.revoked),
        ]else ...[
          StatChip(
            label: 'Issuing Staffs',
            value: 3,
            accent: AppColors.adminAccent,
          ),
          StatChip(
            label: 'Verifying Staffs',
            value: 5,
            accent: AppColors.verifyingAccent,
          )
        ]
        
        
      ],
    );
  }
}
