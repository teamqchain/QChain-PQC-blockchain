import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/models/IT_ADMIN/orgDirectory_model.dart';
import 'package:qportal_webapp/models/IT_ADMIN/staff/issuerStaff_enum.dart';
import 'package:qportal_webapp/models/IT_ADMIN/staff/staff_model.dart';
import 'package:qportal_webapp/models/IT_ADMIN/staff/verifierStaff_enum.dart';
import 'package:qportal_webapp/screens/IT%20Admin/manage_staff.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
// ═════════════════════════════════════════════════════════════════════════════
//  ADD STAFF DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class AddStaffDialog extends StatefulWidget {
  final List<String> existingEmails;
  final List<OrgDirectoryRecord> directoryPool;
  final Future<void> Function(String email, PortalType portal, String roleStr)
  onInvite;

  const AddStaffDialog({
    required this.existingEmails,
    required this.directoryPool,
    required this.onInvite,
  });

  @override
  State<AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<AddStaffDialog> {
  final _emailCtrl = TextEditingController();
  PortalType _portal = PortalType.issuer;
  IssuerRole _issuerRole = IssuerRole.staff;
  VerifierRole _verifierRole = VerifierRole.verifier;
  List<String> _suggestions = [];
  bool _isInviting = false;

  bool get _canInvite {
    final emailStr = _emailCtrl.text.trim();
    final isInDirectory = widget.directoryPool.any((e) => e.email == emailStr);
    return emailStr.isNotEmpty && !_isInviting && isInDirectory;
  }

  void _onEmailChanged(String v) {
    final q = v.trim().toLowerCase();

    setState(() {
      _suggestions = q.isEmpty
          ? []
          : widget.directoryPool
                .map((e) => e.email)
                .where(
                  (email) =>
                      email.toLowerCase().contains(q) &&
                      !widget.existingEmails.contains(email),
                )
                .toList();
    });
  }

  void _pickSuggestion(String e) {
    _emailCtrl.text = e;
    setState(() => _suggestions = []);
  }

  void _doInvite() async {
    setState(() => _isInviting = true);
    final roleStr = _portal == PortalType.issuer
        ? _issuerRole.name
        : _verifierRole.name;
    await widget.onInvite(_emailCtrl.text.trim(), _portal, roleStr);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.adminAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_add_outlined,
                    size: 19,
                    color: AppColors.adminAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Invite Staff Member',
                  style: AppTextStyles.navLabelActive.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
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
                    onTap: _isInviting
                        ? () {}
                        : () => setState(() => _portal = PortalType.issuer),
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
                    onTap: _isInviting
                        ? () {}
                        : () => setState(() => _portal = PortalType.verifier),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            DlgLabel('Email Address'),
            const SizedBox(height: 6),
            DlgInput(
              controller: _emailCtrl,
              hint: 'staff@organisation.ae',
              accent: _portal.accent,
              onChanged: _onEmailChanged,
              enabled: !_isInviting,
            ),
            if (_suggestions.isNotEmpty && !_isInviting) ...[
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: _suggestions
                      .take(5)
                      .map(
                        (e) => _SuggestionTile(
                          email: e,
                          accent: _portal.accent,
                          onTap: () => _pickSuggestion(e),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 16),

            DlgLabel('Role'),
            const SizedBox(height: 6),
            if (_portal == PortalType.issuer)
              IssuerRoleDropdown(
                value: _issuerRole,
                enabled: !_isInviting,
                onChanged: (r) {
                  if (r != null) setState(() => _issuerRole = r);
                },
              )
            else
              VerifierRoleDropdown(
                value: _verifierRole,
                enabled: !_isInviting,
                onChanged: (r) {
                  if (r != null) setState(() => _verifierRole = r);
                },
              ),
            const SizedBox(height: 24),

            Row(
              children: [
                AppButton(
                  label: 'Cancel',
                  onTap: _isInviting ? () {} : () => Navigator.pop(context),
                  showBorder: true,
                  borderColor: AppColors.border,
                  hoverColor: AppColors.surfaceHover,
                  enabled: !_isInviting,
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: _isInviting ? 'Inviting...' : 'Invite',
                  icon: _isInviting ? null : Icons.send_outlined,
                  backgroundColor: AppColors.adminAccent,
                  hoverColor: AppColors.adminAccent.withOpacity(0.82),
                  enabled: _canInvite,
                  tooltip: _canInvite ? null : 'Enter an email address first',
                  onTap: _doInvite,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }
}

class _SuggestionTile extends StatefulWidget {
  final String email;
  final Color accent;
  final VoidCallback onTap;
  const _SuggestionTile({
    required this.email,
    required this.accent,
    required this.onTap,
  });
  @override
  State<_SuggestionTile> createState() => _SuggestionTileState();
}

class _SuggestionTileState extends State<_SuggestionTile> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        color: _h ? widget.accent.withOpacity(0.08) : Colors.transparent,
        child: Row(
          children: [
            const Icon(
              Icons.person_outline,
              size: 13,
              color: AppColors.textDim,
            ),
            const SizedBox(width: 8),
            Text(
              widget.email,
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
