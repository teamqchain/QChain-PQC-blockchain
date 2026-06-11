import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/dashboard_Model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/utils/webApp_shell.dart';
import 'package:qportal_webapp/view/responsive_layout.dart';
import 'package:qportal_webapp/widgets/dashboard_widgets.dart';

// ─── VARIANT A: BOTH ISSUING + VERIFYING ─────────────────────────────────────

// class VariantBothContent extends StatelessWidget {
//   const VariantBothContent({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return ResponsiveColumns(
//       left: Column(
//         children: [
//           DashCard(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SectionHeader(
//                   title: 'Recent Issuing Activity',
//                   accent: AppColors.issuingAccent,
//                   linkText: 'View All Credentials',
//                 ),
//                 ...MockData.recentIssued.map(
//                   (item) =>
//                       ActivityRow(item: item, accent: AppColors.issuingAccent),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 14),
//           DashCard(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SectionHeader(
//                   title: 'Expiry Warnings',
//                   accent: AppColors.issuingAccent,
//                   linkText: 'View All Expiring',
//                 ),
//                 ...MockData.expiryWarnings.map((item) => ExpiryRow(item: item)),
//               ],
//             ),
//           ),
//         ],
//       ),
//       right: Column(
//         children: [
//           DashCard(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SectionHeader(
//                   title: 'Recent Verifications',
//                   accent: AppColors.verifyingAccent,
//                   linkText: 'View Full History',
//                 ),
//                 ...MockData.recentVerifications.map(
//                   (item) => VerificationRow(item: item),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 14),
//           DashCard(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SectionHeader(
//                   title: 'Status Alerts',
//                   accent: AppColors.verifyingAccent,
//                   linkText: 'Manage Subscriptions',
//                 ),
//                 ...MockData.statusAlerts.map((item) => AlertRow(item: item)),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─── VARIANT B: ISSUER ONLY ───────────────────────────────────────────────────

// class VariantIssuerContent extends StatelessWidget {
//   const VariantIssuerContent({super.key, required Map<String, dynamic> stats});

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         DashCard(
//           backgroundColor: AppColors.issuingAccent.withOpacity(0.06),
//           borderColor: AppColors.issuingAccent.withOpacity(0.3),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'QUICK ACTIONS',
//                 style: AppTextStyles.bodyTiny.copyWith(letterSpacing: 0.8),
//               ),
//               const SizedBox(height: 14),
//               Wrap(
//                 spacing: 12,
//                 runSpacing: 12,
//                 children: [
//                   DashActionButton(
//                     label: 'Issue Single Credential',
//                     icon: Icons.person,
//                     accent: AppColors.issuingAccent,
//                     onTap: () => ShellNav.push(RouteName.issueSingle),
//                   ),
//                   DashActionButton(
//                     label: 'Issue Batch',
//                     icon: Icons.group,
//                     accent: AppColors.issuingAccent,
//                     onTap: () => ShellNav.push(RouteName.issueBatch),
//                   ),
//                   DashActionButton(
//                     label: 'Manage Schemas',
//                     icon: Icons.schema,
//                     accent: AppColors.issuingAccent,
//                     onTap: () => ShellNav.push(RouteName.schemas),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         ResponsiveColumns(
//           left: DashCard(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SectionHeader(
//                   title: 'Recent Issuing Activity',
//                   accent: AppColors.issuingAccent,
//                   linkText: 'View All',
//                 ),
//                 ...MockData.recentIssued.map(
//                   (item) =>
//                       ActivityRow(item: item, accent: AppColors.issuingAccent),
//                 ),
//               ],
//             ),
//           ),
//           right: Column(
//             children: [
//               DashCard(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     SectionHeader(
//                       title: 'Expiry Warnings',
//                       accent: AppColors.issuingAccent,
//                       linkText: 'View All',
//                     ),
//                     ...MockData.expiryWarnings.map(
//                       (item) => ExpiryRow(item: item),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 14),
//               DashCard(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const SectionHeader(
//                       title: 'Credentials Issued — Last 4 Weeks',
//                       accent: AppColors.issuingAccent,
//                     ),
//                     const SizedBox(height: 10),
//                     MiniBarChart(
//                       data: MockData.weeklyIssuedData,
//                       accent: AppColors.issuingAccent,
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ─── VARIANT C: VERIFIER ONLY ─────────────────────────────────────────────────

// class VariantVerifierContent extends StatelessWidget {
//   const VariantVerifierContent({super.key, required Map<String, dynamic> stats});

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         DashCard(
//           backgroundColor: AppColors.verifyingAccent.withOpacity(0.06),
//           borderColor: AppColors.verifyingAccent.withOpacity(0.3),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'QUICK ACTIONS',
//                 style: AppTextStyles.bodyTiny.copyWith(letterSpacing: 0.8),
//               ),
//               const SizedBox(height: 14),
//               Wrap(
//                 spacing: 12,
//                 runSpacing: 12,
//                 children: [
//                   DashActionButton(
//                     label: 'Scan QR Code',
//                     icon: Icons.qr_code_scanner_rounded,
//                     accent: AppColors.verifyingAccent,
//                     large: false,
//                     onTap: () => ShellNav.push(
//                       RouteName.scanQR,
//                     ), // TODO: add verifier route
//                   ),
//                   DashActionButton(
//                     label: 'Manual Verify',
//                     icon: Icons.keyboard,
//                     accent: AppColors.verifyingAccent,
//                     onTap: () => ShellNav.push(
//                       RouteName.manualVerify,
//                     ), // TODO: add verifier route
//                   ),
//                   // DashActionButton(
//                   //   label: 'Upload File',
//                   //   icon: Icons.upload,
//                   //   accent: AppColors.verifyingAccent,
//                   //   onTap: () => ShellNav.push(RouteName.uploadFile), // TODO: add verifier route
//                   // ),
//                   DashActionButton(
//                     label: 'Batch Verify',
//                     icon: Icons.group,
//                     accent: AppColors.verifyingAccent,
//                     onTap: () => ShellNav.push(
//                       RouteName.batchVerify,
//                     ), // TODO: add verifier route
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         ResponsiveColumns(
//           left: DashCard(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SectionHeader(
//                   title: 'Recent Verifications',
//                   accent: AppColors.verifyingAccent,
//                   linkText: 'View Full History',
//                 ),
//                 ...MockData.recentVerifications.map(
//                   (item) => VerificationRow(item: item),
//                 ),
//               ],
//             ),
//           ),
//           right: Column(
//             children: [
//               DashCard(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     SectionHeader(
//                       title: 'Status Alerts',
//                       accent: AppColors.verifyingAccent,
//                       linkText: 'Manage Subscriptions',
//                     ),
//                     ...MockData.statusAlerts.map(
//                       (item) => AlertRow(item: item),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 14),
//               DashCard(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const SectionHeader(
//                       title: 'Verifications — Last 7 Days',
//                       accent: AppColors.verifyingAccent,
//                     ),
//                     const SizedBox(height: 10),
//                     MiniBarChart(
//                       data: MockData.dailyVerifiedData,
//                       accent: AppColors.verifyingAccent,
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }


// ─── VARIANT B: ISSUER ONLY ───────────────────────────────────────────────────

class VariantIssuerContent extends StatelessWidget {
  final Map<String, dynamic> stats;
  const VariantIssuerContent({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    // Parse JSON lists to Typed objects
    final recentIssuedList = (stats['recentActivity'] as List? ?? [])
        .map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final expiryWarningsList = (stats['expiryWarnings'] as List? ?? [])
        .map((e) => ExpiryItem.fromJson(e as Map<String, dynamic>))
        .toList();

    // 🔄 CHANGED: Now looking for 'dailyIssued' instead of 'weeklyIssued'
    final dailyIssuedList = (stats['dailyIssued'] as List? ?? [])
        .map((e) => BarDataPoint.fromJson(e as Map<String, dynamic>))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashCard(
          backgroundColor: AppColors.issuingAccent.withOpacity(0.06),
          borderColor: AppColors.issuingAccent.withOpacity(0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QUICK ACTIONS',
                style: AppTextStyles.bodyTiny.copyWith(letterSpacing: 0.8),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  DashActionButton(
                    label: 'Issue Single Credential',
                    icon: Icons.person,
                    accent: AppColors.issuingAccent,
                    onTap: () => ShellNav.push(RouteName.issueSingle),
                  ),
                  DashActionButton(
                    label: 'Issue Batch',
                    icon: Icons.group,
                    accent: AppColors.issuingAccent,
                    onTap: () => ShellNav.push(RouteName.issueBatch),
                  ),
                  DashActionButton(
                    label: 'Manage Schemas',
                    icon: Icons.schema,
                    accent: AppColors.issuingAccent,
                    onTap: () => ShellNav.push(RouteName.schemas),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ResponsiveColumns(
          left: DashCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Recent Issuing Activity',
                  accent: AppColors.issuingAccent,
                  linkText: 'View All',
                ),
                ...recentIssuedList.map(
                  (item) =>
                      ActivityRow(item: item, accent: AppColors.issuingAccent),
                ),
              ],
            ),
          ),
          right: Column(
            children: [
              DashCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Expiry Warnings',
                      accent: AppColors.issuingAccent,
                      linkText: 'View All',
                    ),
                    ...expiryWarningsList.map((item) => ExpiryRow(item: item)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              DashCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔄 CHANGED: Updated the title to match the 7-day layout
                    const SectionHeader(
                      title: 'Credentials Issued — Last 7 Days',
                      accent: AppColors.issuingAccent,
                    ),
                    const SizedBox(height: 10),
                    MiniBarChart(
                      // 🔄 CHANGED: Passing the daily list here
                      data: dailyIssuedList,
                      accent: AppColors.issuingAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── VARIANT C: VERIFIER ONLY ─────────────────────────────────────────────────

class VariantVerifierContent extends StatelessWidget {
  final Map<String, dynamic> stats;
  const VariantVerifierContent({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    // Parse JSON lists to Typed objects
    final recentVerificationsList = (stats['recentVerifications'] as List? ?? [])
        .map((e) => VerificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final statusAlertsList = (stats['statusAlerts'] as List? ?? [])
        .map((e) => AlertItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final dailyVerifiedList = (stats['dailyVerified'] as List? ?? [])
        .map((e) => BarDataPoint.fromJson(e as Map<String, dynamic>))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashCard(
          backgroundColor: AppColors.verifyingAccent.withOpacity(0.06),
          borderColor: AppColors.verifyingAccent.withOpacity(0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QUICK ACTIONS',
                style: AppTextStyles.bodyTiny.copyWith(letterSpacing: 0.8),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  DashActionButton(
                    label: 'Scan QR Code',
                    icon: Icons.qr_code_scanner_rounded,
                    accent: AppColors.verifyingAccent,
                    large: false,
                    onTap: () => ShellNav.push(RouteName.scanQR),
                  ),
                  DashActionButton(
                    label: 'Manual Verify',
                    icon: Icons.keyboard,
                    accent: AppColors.verifyingAccent,
                    onTap: () => ShellNav.push(RouteName.manualVerify),
                  ),
                  DashActionButton(
                    label: 'Batch Verify',
                    icon: Icons.group,
                    accent: AppColors.verifyingAccent,
                    onTap: () => ShellNav.push(RouteName.batchVerify),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ResponsiveColumns(
          left: DashCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Recent Verifications',
                  accent: AppColors.verifyingAccent,
                  linkText: 'View Full History',
                ),
                ...recentVerificationsList.map(
                  (item) => VerificationRow(item: item),
                ),
              ],
            ),
          ),
          right: Column(
            children: [
              DashCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Status Alerts',
                      accent: AppColors.verifyingAccent,
                      linkText: 'Manage Subscriptions',
                    ),
                    ...statusAlertsList.map((item) => AlertRow(item: item)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              DashCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Verifications — Last 7 Days',
                      accent: AppColors.verifyingAccent,
                    ),
                    const SizedBox(height: 10),
                    MiniBarChart(
                      data: dailyVerifiedList,
                      accent: AppColors.verifyingAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── VARIANT D: IT ADMIN ──────────────────────────────────────────────────────

class VariantITAdminContent extends StatelessWidget {
  final Map<String, dynamic> stats;
  const VariantITAdminContent({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    // ── Parse Live Data ──
    final totalStaff = stats['adminTotalStaff'] ?? 0;
    final activeStaff = stats['adminActiveStaff'] ?? 0;
    final invitedStaff = stats['adminInvitedStaff'] ?? 0;
    final issuerStaffCount = stats['issuerStaffCount'] ?? 0;
    final verifierStaffCount = stats['verifierStaffCount'] ?? 0;

    final recentAudit = (stats['recentAudit'] as List? ?? [])
        .map((e) => AdminAuditItem.fromJson(e as Map<String, dynamic>))
        .take(3)
        .toList();

    final issuerRoles = (stats['issuerRoles'] as List? ?? [])
        .map((e) => AdminRoleSplit.fromJson(e as Map<String, dynamic>))
        .toList();

    final verifierRoles = (stats['verifierRoles'] as List? ?? [])
        .map((e) => AdminRoleSplit.fromJson(e as Map<String, dynamic>))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatTileRow(
          totalStaff: totalStaff,
          activeStaff: activeStaff,
          invitedStaff: invitedStaff,
          issuerStaffCount: issuerStaffCount,
          verifierStaffCount: verifierStaffCount,
        ),
        const SizedBox(height: 16),
        ResponsiveColumns(
          left: _OrgProfileCard(), // Retained as mock per request
          right: _RecentAuditCard(auditLogs: recentAudit),
        ),
        const SizedBox(height: 14),
        ResponsiveColumns(
          left: _StaffBreakdownCard(
            totalStaff: totalStaff,
            activeStaff: activeStaff,
            invitedStaff: invitedStaff,
            issuerTotal: issuerStaffCount,
            verifierTotal: verifierStaffCount,
            issuerRoles: issuerRoles,
            verifierRoles: verifierRoles,
          ),
          right: _CapabilityRequestsCard(), // Retained as mock per request
        ),
      ],
    );
  }
}

// ── MOCK DATA (Retained for Org Profile & Capabilities ONLY) ──────────────────

class _AdminMock {
  // Org profile (from ManageProfilePage mock)
  static const String orgName = 'University of Sharjah';
  static const String orgType = 'University';
  static const String orgCountry = 'United Arab Emirates';
  static const String orgDid = 'did:qportal:uae:uos-2024-001';
  static const String orgSince = '01 Jan 2024';

  // Capability requests (from RequestCapabilitiesPage mock)
  static const capRequests = [
    _CapSummary(
      'REQ-2025-001',
      'Request Verifier Access',
      'Mohammed A.',
      '14 Jan 2025',
      _CapStatus.rejected,
    ),
    _CapSummary(
      'REQ-2025-002',
      'Request Issuer Access',
      'Registrar Ali',
      '03 Mar 2025',
      _CapStatus.rejected,
    ),
    _CapSummary(
      'REQ-2025-003',
      'Request Verifier Access',
      'Mohammed A.',
      '18 Jun 2025',
      _CapStatus.pending,
    ),
  ];
}

class _CapSummary {
  final String id;
  final String type;
  final String requestedBy;
  final String date;
  final _CapStatus status;
  const _CapSummary(
    this.id,
    this.type,
    this.requestedBy,
    this.date,
    this.status,
  );
}

enum _CapStatus { accepted, rejected, pending }

// ═════════════════════════════════════════════════════════════════════════════
//  STAT TILE ROW
// ═════════════════════════════════════════════════════════════════════════════

class _StatTileRow extends StatelessWidget {
  final int totalStaff;
  final int activeStaff;
  final int invitedStaff;
  final int issuerStaffCount;
  final int verifierStaffCount;

  const _StatTileRow({
    required this.totalStaff,
    required this.activeStaff,
    required this.invitedStaff,
    required this.issuerStaffCount,
    required this.verifierStaffCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(
          icon: Icons.group_outlined,
          label: 'Total Staff',
          value: '$totalStaff',
          sub: '$issuerStaffCount issuer · $verifierStaffCount verifier',
          color: AppColors.adminAccent,
          light: AppColors.adminLight,
        ),
        const SizedBox(width: 12),
        _StatTile(
          icon: Icons.check_circle_outline_rounded,
          label: 'Active Members',
          value: '$activeStaff',
          sub: '$invitedStaff pending invitation',
          color: AppColors.verifyingAccent,
          light: AppColors.verifyingLight,
        ),
        const SizedBox(width: 12),
        _StatTile(
          icon: Icons.hourglass_top_rounded,
          label: 'Pending Requests',
          value: '1',
          sub: '2 resolved this year',
          color: AppColors.suspended,
          light: AppColors.suspended,
        ),
        const SizedBox(width: 12),
        _StatTile(
          icon: Icons.lock_outlined,
          label: 'Crypto Algorithm',
          value: 'Dilithium',
          sub: 'CRYSTALS-Dilithium3 · Active',
          color: const Color(0xFF06B6D4),
          light: const Color(0xFF22D3EE),
        ),
      ],
    );
  }
}

class _StatTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final Color light;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.light,
  });

  @override
  State<_StatTile> createState() => _StatTileState();
}

class _StatTileState extends State<_StatTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? widget.color.withOpacity(0.4)
                  : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon box
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, size: 17, color: widget.light),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: AppTextStyles.bodyTiny.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.textDim,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.sub,
                      style: AppTextStyles.bodyTiny.copyWith(
                        fontSize: 10,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ORGANISATION PROFILE CARD (MOCKED)
// ═════════════════════════════════════════════════════════════════════════════

class _OrgProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Organisation Profile',
            accent: AppColors.adminAccent,
          ),
          const SizedBox(height: 2),

          // Logo / avatar row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.adminAccent.withOpacity(0.25),
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/unilogo_short.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    _AdminMock.orgName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _AdminMock.orgType,
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 14),

          // Info rows
          _OrgInfoRow(
            icon: Icons.flag_outlined,
            label: 'Country',
            value: _AdminMock.orgCountry,
          ),
          const _OrgInfoRow(
            icon: Icons.fingerprint_rounded,
            label: 'DID',
            value: _AdminMock.orgDid,
            mono: true,
          ),
          const _OrgInfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Registered',
            value: _AdminMock.orgSince,
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Crypto row
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Crypto: Dilithium (CRYSTALS-Dilithium3)',
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrgInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  const _OrgInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppColors.textDim),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textDim,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontFamily: mono ? 'monospace' : null,
                color: mono ? AppColors.adminLight : AppColors.textMuted,
                overflow: TextOverflow.ellipsis,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  RECENT AUDIT ACTIVITY CARD (LIVE)
// ═════════════════════════════════════════════════════════════════════════════

class _RecentAuditCard extends StatelessWidget {
  final List<AdminAuditItem> auditLogs;
  const _RecentAuditCard({required this.auditLogs});

  @override
  Widget build(BuildContext context) {
    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Recent Audit Activity',
            accent: AppColors.adminAccent,
            linkText: 'View Full Log',
          ),
          const SizedBox(height: 4),
          if (auditLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text("No recent activity.", style: AppTextStyles.bodyTiny),
            )
          else
            ...auditLogs.map((e) => _AuditRow(entry: e)),
        ],
      ),
    );
  }
}

class _AuditRow extends StatefulWidget {
  final AdminAuditItem entry;
  const _AuditRow({required this.entry});

  @override
  State<_AuditRow> createState() => _AuditRowState();
}

class _AuditRowState extends State<_AuditRow> {
  bool _hovered = false;

  IconData _getIcon(String action) {
    switch (action.toLowerCase()) {
      case 'issued':
        return Icons.badge_outlined;
      case 'verified':
        return Icons.verified_outlined;
      case 'revoked':
        return Icons.block_outlined;
      case 'suspended':
        return Icons.pause_circle_outline;
      case 'policy_changed':
        return Icons.policy_outlined;
      default:
        return Icons.settings_outlined;
    }
  }

  Color _getColor(String action) {
    switch (action.toLowerCase()) {
      case 'issued':
        return const Color(0xFF3B82F6);
      case 'verified':
        return const Color(0xFF22C55E);
      case 'revoked':
        return const Color(0xFFEF4444);
      case 'suspended':
        return AppColors.suspended;
      case 'policy_changed':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF818CF8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(widget.entry.action);
    final icon = _getIcon(widget.entry.action);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surfaceHover : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: _hovered ? color : Colors.transparent,
              width: 2,
            ),
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 13, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.entry.details,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        widget.entry.performedBy,
                        style: AppTextStyles.bodyTiny.copyWith(
                          fontSize: 10,
                          color: AppColors.textDim,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '-',
                        style: AppTextStyles.bodyTiny.copyWith(
                          fontSize: 10,
                          color: AppColors.textDim,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.entry.role,
                        style: AppTextStyles.bodyTiny.copyWith(
                          fontSize: 10,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.entry.timestamp,
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 10,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STAFF BREAKDOWN CARD (LIVE)
// ═════════════════════════════════════════════════════════════════════════════

class _StaffBreakdownCard extends StatelessWidget {
  final int totalStaff;
  final int activeStaff;
  final int invitedStaff;
  final int issuerTotal;
  final int verifierTotal;
  final List<AdminRoleSplit> issuerRoles;
  final List<AdminRoleSplit> verifierRoles;

  const _StaffBreakdownCard({
    required this.totalStaff,
    required this.activeStaff,
    required this.invitedStaff,
    required this.issuerTotal,
    required this.verifierTotal,
    required this.issuerRoles,
    required this.verifierRoles,
  });

  @override
  Widget build(BuildContext context) {
    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Staff Overview',
            accent: AppColors.adminAccent,
            linkText: 'Manage Staff',
            onLinkTap: () => ShellNav.push(RouteName.staffAndPermissions),
          ),
          const SizedBox(height: 8),

          // Summary row
          Row(
            children: [
              _MiniStatBox(
                label: 'Total',
                value: '$totalStaff',
                color: AppColors.adminAccent,
                light: AppColors.adminLight,
              ),
              const SizedBox(width: 10),
              _MiniStatBox(
                label: 'Active',
                value: '$activeStaff',
                color: AppColors.verifyingAccent,
                light: AppColors.verifyingLight,
              ),
              const SizedBox(width: 10),
              _MiniStatBox(
                label: 'Invited',
                value: '$invitedStaff',
                color: AppColors.issuingAccent,
                light: AppColors.issuingLight,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 14),

          // Issuer breakdown
          _PortalRoleSection(
            portalLabel: 'Issuer Portal',
            portalColor: AppColors.issuingAccent,
            portalLight: AppColors.issuingLight,
            total: issuerTotal,
            roles: issuerRoles,
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 14),

          // Verifier breakdown
          _PortalRoleSection(
            portalLabel: 'Verifier Portal',
            portalColor: AppColors.verifyingAccent,
            portalLight: AppColors.verifyingLight,
            total: verifierTotal,
            roles: verifierRoles,
          ),
        ],
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color light;

  const _MiniStatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.light,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: light,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 10,
                color: color.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalRoleSection extends StatelessWidget {
  final String portalLabel;
  final Color portalColor;
  final Color portalLight;
  final int total;
  final List<AdminRoleSplit> roles;

  const _PortalRoleSection({
    required this.portalLabel,
    required this.portalColor,
    required this.portalLight,
    required this.total,
    required this.roles,
  });

  // Assign distinct colors based on index for the live data mapping
  Color _getRoleColor(int index) {
    final colors = [
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
      const Color(0xFF818CF8),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: portalColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: portalColor.withOpacity(0.28)),
              ),
              child: Text(
                portalLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: portalLight,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '$total members',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 10,
                color: AppColors.textDim,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (roles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text("No staff data.", style: AppTextStyles.bodyTiny),
          )
        else
          ...roles.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getRoleColor(entry.key),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value.label,
                      style: AppTextStyles.bodyTiny.copyWith(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  Text(
                    '${entry.value.count}',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _getRoleColor(entry.key),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CAPABILITY REQUESTS CARD (MOCKED)
// ═════════════════════════════════════════════════════════════════════════════

class _CapabilityRequestsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Capability Requests',
            accent: AppColors.adminAccent,
            linkText: 'View All',
          ),
          const SizedBox(height: 4),
          ..._AdminMock.capRequests.map((r) => _CapRow(req: r)),
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Pending notice
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: AppColors.suspended.withOpacity(0.8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '1 request is awaiting review by the platform administrator.',
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapRow extends StatefulWidget {
  final _CapSummary req;
  const _CapRow({required this.req});

  @override
  State<_CapRow> createState() => _CapRowState();
}

class _CapRowState extends State<_CapRow> {
  bool _hovered = false;

  Color get _statusColor {
    switch (widget.req.status) {
      case _CapStatus.accepted:
        return AppColors.verifyingAccent;
      case _CapStatus.rejected:
        return AppColors.revoked;
      case _CapStatus.pending:
        return AppColors.suspended;
    }
  }

  String get _statusLabel {
    switch (widget.req.status) {
      case _CapStatus.accepted:
        return 'Accepted';
      case _CapStatus.rejected:
        return 'Rejected';
      case _CapStatus.pending:
        return 'Pending';
    }
  }

  IconData get _statusIcon {
    switch (widget.req.status) {
      case _CapStatus.accepted:
        return Icons.check_circle_outline_rounded;
      case _CapStatus.rejected:
        return Icons.cancel_outlined;
      case _CapStatus.pending:
        return Icons.hourglass_top_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surfaceHover : const Color(0xFF161616),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _hovered ? _statusColor.withOpacity(0.4) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(_statusIcon, size: 14, color: _statusColor),
            ),
            const SizedBox(width: 10),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.req.type,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.req.requestedBy}  ·  ${widget.req.date}',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 10,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: _statusColor.withOpacity(0.30)),
              ),
              child: Text(
                _statusLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
