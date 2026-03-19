// screens/issuer/issuer_settings_page.dart
//
// Issuer Settings — 2×2 grid of navigation cards.
// Each card is a placeholder that will route to its own page when built.
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   import 'package:qportal_webapp/screens/issuer/issuer_settings_page.dart';
//
//   case RouteName.issuingSettings:
//     return IssuerSettingsPage(
//       onManageProfile:            () => _handleNavigate(RouteName.issuerProfile),
//       onStaffAndPermissions:      () => _handleNavigate(RouteName.issuerStaff),
//       onCryptoSettings:           () => _handleNavigate(RouteName.issuerCrypto),
//       onRequestCapabilities:      () => _handleNavigate(RouteName.issuerCapabilities),
//     );

import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class IssuerSettingsPage extends StatelessWidget {
  final VoidCallback? onManageProfile;
  final VoidCallback? onStaffAndPermissions;
  final VoidCallback? onCryptoSettings;
  final VoidCallback? onRequestCapabilities;

  const IssuerSettingsPage({
    super.key,
    this.onManageProfile,
    this.onStaffAndPermissions,
    this.onCryptoSettings,
    this.onRequestCapabilities,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title
          Text(
            'Issuer Settings',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),

          // 2×2 grid
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800, maxHeight: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _SettingsCard(
                              icon: Icons.person_outline_rounded,
                              title: 'Manage Profile',
                              description:
                                  'Update your organisation name, logo, contact details, and public issuer information.',
                              accentColor: AppColors.issuingAccent,
                              onTap: onManageProfile,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _SettingsCard(
                              icon: Icons.group_outlined,
                              title: 'Staff & Permissions',
                              description:
                                  'Invite staff members, assign roles, and manage access levels for your issuing team.',
                              accentColor: const Color(0xFF8B5CF6),
                              onTap: onStaffAndPermissions,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Bottom row
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _SettingsCard(
                              icon: Icons.key_outlined,
                              title: 'Crypto Settings',
                              description:
                                  'Configure signing algorithms, manage cryptographic keys, and review PQC parameters.',
                              accentColor: const Color(0xFF06B6D4),
                              onTap: onCryptoSettings,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _SettingsCard(
                              icon: Icons.add_circle_outline_rounded,
                              title: 'Request Additional Capabilities',
                              description:
                                  'Apply to unlock additional credential types, higher issuance limits, or extended features.',
                              accentColor: AppColors.verifyingAccent,
                              onTap: onRequestCapabilities,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SETTINGS CARD
// ═════════════════════════════════════════════════════════════════════════════

class _SettingsCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
  final VoidCallback? onTap;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    this.onTap,
  });

  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          width: 380,
          height: 280,
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? widget.accentColor.withOpacity(0.45)
                  : AppColors.border,
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: widget.accentColor.withOpacity(0.28),
                  ),
                ),
                child: Icon(widget.icon, size: 22, color: widget.accentColor),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                widget.title,
                style: AppTextStyles.navLabelActive.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Expanded(
                child: Text(
                  widget.description,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.65,
                  ),
                  overflow: TextOverflow.fade,
                ),
              ),

              const SizedBox(height: 16),

              // Open arrow
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withOpacity(
                        _hovered ? 0.14 : 0.07,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: widget.accentColor.withOpacity(
                          _hovered ? 0.4 : 0.2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Open',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: widget.accentColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: widget.accentColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
