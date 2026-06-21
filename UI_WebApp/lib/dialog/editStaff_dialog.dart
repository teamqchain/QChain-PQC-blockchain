import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/models/IT_ADMIN/staff/issuerStaff_enum.dart';
import 'package:qportal_webapp/models/IT_ADMIN/staff/staff_model.dart';
import 'package:qportal_webapp/models/IT_ADMIN/staff/verifierStaff_enum.dart';
import 'package:qportal_webapp/screens/IT%20Admin/manage_staff.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
// ═════════════════════════════════════════════════════════════════════════════
//  EDIT STAFF DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class EditStaffDialog extends StatefulWidget {
  final StaffEntry entry;
  final Future<void> Function(PortalType portal, String roleStr) onSave;
  final Future<void> Function() onDelete;

  const EditStaffDialog({
    required this.entry,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<EditStaffDialog> createState() => _EditStaffDialogState();
}

class _EditStaffDialogState extends State<EditStaffDialog> {
  late PortalType _portal;
  IssuerRole? _issuerRole;
  VerifierRole? _verifierRole;

  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _portal = widget.entry.portal;
    _issuerRole = widget.entry.issuerRole;
    _verifierRole = widget.entry.verifierRole;
  }

  void _onPortalChanged(PortalType p) {
    if (p == _portal || _isSaving || _isDeleting) return;
    setState(() {
      _portal = p;
      if (p == PortalType.issuer) {
        _issuerRole = IssuerRole.staff;
        _verifierRole = null;
      } else {
        _verifierRole = VerifierRole.verifier;
        _issuerRole = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final accent = _portal.accent;
    final portalChanged = _portal != e.portal;
    final bool isBusy = _isSaving || _isDeleting;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 48,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.manage_accounts_outlined,
                    size: 19,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Staff Member',
                      style: AppTextStyles.navLabelActive.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          e.name,
                          style: AppTextStyles.bodyTiny.copyWith(
                            fontSize: 11,
                            color: AppColors.textDim,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PortalBadge(portal: e.portal),
                        if (portalChanged) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: AppColors.textDim,
                          ),
                          const SizedBox(width: 4),
                          _PortalBadge(portal: _portal),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 22),

            DlgLabel('Portal'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PortalPickerBtn(
                    label: 'Issuer',
                    icon: Icons.badge_outlined,
                    active: _portal == PortalType.issuer,
                    accent: AppColors.issuingAccent,
                    light: AppColors.issuingLight,
                    onTap: () => _onPortalChanged(PortalType.issuer),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PortalPickerBtn(
                    label: 'Verifier',
                    icon: Icons.verified_user_outlined,
                    active: _portal == PortalType.verifier,
                    accent: AppColors.verifyingAccent,
                    light: AppColors.verifyingLight,
                    onTap: () => _onPortalChanged(PortalType.verifier),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            DlgLabel('Email Address'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                e.email,
                style: const TextStyle(fontSize: 13, color: AppColors.textDim),
              ),
            ),
            const SizedBox(height: 16),

            DlgLabel('Role'),
            const SizedBox(height: 6),
            if (_portal == PortalType.issuer)
              IssuerRoleDropdown(
                value: _issuerRole ?? IssuerRole.staff,
                enabled: !isBusy,
                onChanged: (r) {
                  if (r != null) setState(() => _issuerRole = r);
                },
              )
            else
              VerifierRoleDropdown(
                value: _verifierRole ?? VerifierRole.verifier,
                enabled: !isBusy,
                onChanged: (r) {
                  if (r != null) setState(() => _verifierRole = r);
                },
              ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppButton(
                  label: 'Cancel',
                  onTap: isBusy ? () {} : () => Navigator.pop(context),
                  showBorder: true,
                  borderColor: AppColors.border,
                  hoverColor: AppColors.surfaceHover,
                  enabled: !isBusy,
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: _isDeleting ? 'Deleting...' : 'Delete',
                  icon: _isDeleting ? null : Icons.delete_outline_rounded,
                  showBorder: true,
                  borderColor: AppColors.revoked,
                  textColor: AppColors.revoked,
                  hoverColor: AppColors.surfaceHover,
                  enabled: !isBusy,
                  onTap: () async {
                    setState(() => _isDeleting = true);
                    await widget.onDelete();
                    if (mounted) Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: _isSaving ? 'Saving...' : 'Save',
                  icon: _isSaving ? null : Icons.check_rounded,
                  backgroundColor: AppColors.adminAccent,
                  hoverColor: AppColors.adminAccent.withOpacity(0.82),
                  enabled: !isBusy,
                  onTap: () async {
                    setState(() => _isSaving = true);
                    final roleStr = _portal == PortalType.issuer
                        ? _issuerRole!.name
                        : _verifierRole!.name;
                    await widget.onSave(_portal, roleStr);
                    if (mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalBadge extends StatelessWidget {
  final PortalType portal;
  const _PortalBadge({required this.portal});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: portal.accent.withOpacity(0.10),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: portal.accent.withOpacity(0.30)),
    ),
    child: Text(
      portal.label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: portal.light,
        letterSpacing: 0.2,
      ),
    ),
  );
}
