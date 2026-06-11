// screens/issuer/manage_profile_page.dart
//
// Manage Profile — view and edit organisation profile information.
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   import 'package:qportal_webapp/screens/issuer/manage_profile_page.dart';
//
//   // In IssuerSettingsPage:
//   IssuerSettingsPage(
//     onManageProfile: () => _handleNavigate(RouteName.issuerProfile),
//     ...
//   );
//
//   // Add route constant:
//   static const issuerProfile = '/issue/settings/profile';
//
//   // In _buildPage():
//   case RouteName.issuerProfile:
//     return ManageProfilePage(
//       onBack: () => _handleNavigate(RouteName.issuingSettings),
//     );

import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';

// ─── MOCK DATA ────────────────────────────────────────────────────────────────

const _kOrgName = 'University of Sharjah';
const _kLogoFile = 'uos_logo.png';
const _kOrgType = 'University';
const _kOrgCountry = 'United Arab Emirates';

const _kOrgTypes = [
  'University',
  'College',
  'School',
  'Government Agency',
  'Hospital',
  'Clinic',
  'Corporate',
  'Non-Profit',
  'Other',
];

const _kCountries = [
  'United Arab Emirates',
  'Saudi Arabia',
  'Kuwait',
  'Qatar',
  'Bahrain',
  'Oman',
  'Jordan',
  'Egypt',
  'United Kingdom',
  'United States',
  'Canada',
  'Australia',
  'Germany',
  'France',
  'Singapore',
  'India',
  'Other',
];

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class ManageProfilePage extends StatefulWidget {
  final VoidCallback onBack;

  const ManageProfilePage({super.key, required this.onBack});

  @override
  State<ManageProfilePage> createState() => _ManageProfilePageState();
}

class _ManageProfilePageState extends State<ManageProfilePage> {
  // ── edit mode ──────────────────────────────────────────────────────────────
  bool _editing = false;

  // ── org name ───────────────────────────────────────────────────────────────
  late TextEditingController _nameCtrl;

  // ── logo state ─────────────────────────────────────────────────────────────
  // true  = logo is present (show logo box + green file row)
  // false = logo deleted (show upload area)
  bool _hasLogo = true;
  String _logoFileName = _kLogoFile;

  // ── dropdowns ──────────────────────────────────────────────────────────────
  String _orgType = _kOrgType;
  String _orgCountry = _kOrgCountry;

  // ── snapshot for cancel ────────────────────────────────────────────────────
  late String _snapName;
  late bool _snapHasLogo;
  late String _snapLogoFileName;
  late String _snapOrgType;
  late String _snapOrgCountry;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _kOrgName);
    _saveSnapshot();
  }

  void _saveSnapshot() {
    _snapName = _nameCtrl.text;
    _snapHasLogo = _hasLogo;
    _snapLogoFileName = _logoFileName;
    _snapOrgType = _orgType;
    _snapOrgCountry = _orgCountry;
  }

  void _enterEdit() {
    _saveSnapshot();
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    setState(() {
      _nameCtrl.text = _snapName;
      _hasLogo = _snapHasLogo;
      _logoFileName = _snapLogoFileName;
      _orgType = _snapOrgType;
      _orgCountry = _snapOrgCountry;
      _editing = false;
    });
  }

  void _requestSave() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _SaveDialog(onConfirm: () => setState(() => _editing = false)),
    );
  }

  void _deleteLogo() => setState(() => _hasLogo = false);

  void _simulateUpload() {
    // Simulates a successful file pick — sets a placeholder filename.
    setState(() {
      _hasLogo = true;
      _logoFileName = 'new_logo.png';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title
          Text(
            'Manage Profile',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // Main container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.hardEdge,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Organisation Name ────────────────────────────────
                    _SectionLabel('Organisation Name'),
                    const SizedBox(height: 8),
                    _OrgNameField(controller: _nameCtrl, enabled: _editing),
                    const SizedBox(height: 28),

                    // ── Organisation Logo ────────────────────────────────
                    _SectionLabel('Organisation Logo'),
                    const SizedBox(height: 8),
                    _hasLogo
                        ? _LogoPresent(
                            fileName: _logoFileName,
                            editing: _editing,
                            onDelete: _deleteLogo,
                          )
                        : _LogoUpload(
                            enabled: _editing,
                            onBrowse: _simulateUpload,
                            onOneDrive: _simulateUpload,
                          ),
                    const SizedBox(height: 28),

                    // ── Organisation Type ────────────────────────────────
                    _SectionLabel('Organisation Type'),
                    const SizedBox(height: 8),
                    _ProfileDropdown(
                      value: _orgType,
                      items: _kOrgTypes,
                      enabled: _editing,
                      onChanged: (v) {
                        if (v != null) setState(() => _orgType = v);
                      },
                    ),
                    const SizedBox(height: 28),

                    // ── Organisation Country ─────────────────────────────
                    _SectionLabel('Organisation Country'),
                    const SizedBox(height: 8),
                    _ProfileDropdown(
                      value: _orgCountry,
                      items: _kCountries,
                      enabled: _editing,
                      onChanged: (v) {
                        if (v != null) setState(() => _orgCountry = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              AppButton(
                label: 'Back',
                icon: Icons.arrow_back_rounded,
                onTap: widget.onBack,
                showBorder: true,
                borderColor: AppColors.border,
              ),
              const SizedBox(width: 10),
              if (!_editing)
                AppButton(
                  label: 'Edit',
                  backgroundColor: AppColors.adminAccent,
                  icon: Icons.edit_outlined,
                  onTap: _enterEdit,
                )
              else ...[
                AppButton(
                  label: 'Save',
                  backgroundColor: AppColors.verifyingAccent,
                  icon: Icons.save_outlined,
                  onTap: _requestSave,
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Cancel',
                  onTap: _cancelEdit,
                  showBorder: true,
                  borderColor: AppColors.revoked,
                  textColor: AppColors.revoked,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ORG NAME FIELD
// ═════════════════════════════════════════════════════════════════════════════

class _OrgNameField extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;

  const _OrgNameField({required this.controller, required this.enabled});

  @override
  State<_OrgNameField> createState() => _OrgNameFieldState();
}

class _OrgNameFieldState extends State<_OrgNameField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: widget.enabled ? AppColors.surfaceHover : AppColors.surface,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: !widget.enabled
                ? AppColors.border.withOpacity(0.5)
                : _focused
                ? AppColors.adminAccent.withOpacity(0.8)
                : AppColors.adminAccent.withOpacity(0.5),
            width: _focused && widget.enabled ? 1.5 : 1,
          ),
        ),
        child: TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          style: TextStyle(
            fontSize: 13,
            color: widget.enabled ? AppColors.text : AppColors.textMuted,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            border: InputBorder.none,
            hintStyle: AppTextStyles.bodyTiny.copyWith(
              fontSize: 12,
              color: AppColors.textDim,
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  LOGO — PRESENT STATE
// ═════════════════════════════════════════════════════════════════════════════

class _LogoPresent extends StatelessWidget {
  final String fileName;
  final bool editing;
  final VoidCallback onDelete;

  const _LogoPresent({
    required this.fileName,
    required this.editing,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo square
        Container(
          width: 200,
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Image.asset(
            'assets/images/unilogo_short.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 16),

        // File info row — green pill
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            decoration: BoxDecoration(
              color: AppColors.verifyingAccent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: AppColors.verifyingAccent.withOpacity(0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: AppColors.verifyingAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fileName,
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.verifyingLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (editing) ...[
                  const SizedBox(width: 10),
                  _DeleteLogoBtn(onTap: onDelete),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── DELETE LOGO BUTTON ───────────────────────────────────────────────────────

class _DeleteLogoBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _DeleteLogoBtn({required this.onTap});

  @override
  State<_DeleteLogoBtn> createState() => _DeleteLogoBtnState();
}

class _DeleteLogoBtnState extends State<_DeleteLogoBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _h
              ? AppColors.revoked.withOpacity(0.18)
              : AppColors.revoked.withOpacity(0.10),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColors.revoked.withOpacity(0.35)),
        ),
        child: const Text(
          'Delete',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.revoked,
          ),
        ),
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  LOGO — UPLOAD STATE
// ═════════════════════════════════════════════════════════════════════════════

class _LogoUpload extends StatefulWidget {
  final bool enabled;
  final VoidCallback onBrowse;
  final VoidCallback onOneDrive;

  const _LogoUpload({
    required this.enabled,
    required this.onBrowse,
    required this.onOneDrive,
  });

  @override
  State<_LogoUpload> createState() => _LogoUploadState();
}

class _LogoUploadState extends State<_LogoUpload> {
  final bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 130,
      decoration: BoxDecoration(
        color: _dragging && widget.enabled
            ? AppColors.adminAccent.withOpacity(0.06)
            : AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _dragging && widget.enabled
              ? AppColors.adminAccent.withOpacity(0.5)
              : widget.enabled
              ? AppColors.adminAccent.withOpacity(0.5)
              : AppColors.border.withOpacity(0.5),
          style: BorderStyle.solid,
          width: _dragging ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 28,
            color: widget.enabled ? AppColors.textMuted : AppColors.textDim,
          ),
          const SizedBox(height: 8),
          Text(
            'Only PNG format is accepted. Maximum 1 file allowed.',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 11,
              color: widget.enabled ? AppColors.textMuted : AppColors.textDim,
            ),
          ),
          if (widget.enabled) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _UploadBtn(
                  icon: Icons.folder_open_outlined,
                  label: 'Browse from Computer',
                  onTap: widget.onBrowse,
                ),
                const SizedBox(width: 10),
                _UploadBtn(
                  icon: Icons.cloud_outlined,
                  label: 'Upload from OneDrive',
                  onTap: widget.onOneDrive,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── UPLOAD BUTTON ────────────────────────────────────────────────────────────

class _UploadBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _UploadBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_UploadBtn> createState() => _UploadBtnState();
}

class _UploadBtnState extends State<_UploadBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _h
              ? AppColors.adminAccent.withOpacity(0.12)
              : AppColors.adminAccent.withOpacity(0.07),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.adminAccent.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 13, color: AppColors.adminAccent),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.adminAccent,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  PROFILE DROPDOWN
// ═════════════════════════════════════════════════════════════════════════════

class _ProfileDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final bool enabled;
  final void Function(String?) onChanged;

  const _ProfileDropdown({
    required this.value,
    required this.items,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? AppColors.surfaceHover : AppColors.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: !enabled
              ? AppColors.border.withOpacity(0.5)
              : AppColors.adminAccent.withOpacity(0.5),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          iconEnabledColor: enabled ? AppColors.textMuted : AppColors.textDim,
          iconDisabledColor: AppColors.textDim,
          dropdownColor: const Color(0xFF1E1E1E),
          style: TextStyle(
            fontSize: 13,
            color: enabled ? AppColors.text : AppColors.textMuted,
          ),
          items: enabled
              ? items
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList()
              : [DropdownMenuItem(value: value, child: Text(value))],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SAVE CONFIRMATION DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _SaveDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  const _SaveDialog({required this.onConfirm});

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
              color: Colors.black.withOpacity(0.6),
              blurRadius: 48,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.verifyingAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.save_outlined,
                    size: 20,
                    color: AppColors.verifyingAccent,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    'Save Profile Changes',
                    style: AppTextStyles.navLabelActive.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Message
            RichText(
              text: TextSpan(
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.7,
                ),
                children: const [
                  TextSpan(
                    text:
                        'These changes will affect future credentials issued by this organisation.\n',
                  ),
                  TextSpan(
                    text:
                        'Previously issued credentials will remain valid and unchanged.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(label: 'Cancel', onTap: () => Navigator.pop(context)),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Confirm Save',
                  backgroundColor: AppColors.verifyingAccent,
                  onTap: () {
                    Navigator.pop(context);
                    onConfirm();
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

// ═════════════════════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTextStyles.bodyTiny.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: AppColors.textMuted,
    ),
  );
}
