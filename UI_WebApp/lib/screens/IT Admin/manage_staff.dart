// screens/issuer/manage_staff_page.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qportal_webapp/components/filterButton.dart';
import 'package:qportal_webapp/services/api_service.dart'; // Ensure correct path
import 'package:qportal_webapp/components/countChip.dart';
import 'package:qportal_webapp/components/searchBar.dart';
import 'package:qportal_webapp/components/connection_error.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/models/verifiying_models.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';

// ─── CONSTANTS ────────────────────────────────────────────────────────────────

const _kIssuerRolePerms = <IssuerRole, List<String>>{
  IssuerRole.staff: ['Issue & revoke credentials'],
  IssuerRole.schemaManager: ['Manage schemas only · Cannot issue'],
};

const _kVerifierRolePerms = <VerifierRole, List<String>>{
  VerifierRole.verifier: ['Run verifications'],
  VerifierRole.policyManager: [
    'Manage policies only · Cannot run verifications',
  ],
};

// ─── PORTAL TYPE ──────────────────────────────────────────────────────────────

enum _Portal { issuer, verifier }

extension _PortalX on _Portal {
  String get label => this == _Portal.issuer ? 'Issuer' : 'Verifier';
  Color get accent => this == _Portal.issuer
      ? AppColors.issuingAccent
      : AppColors.verifyingAccent;
  Color get light => this == _Portal.issuer
      ? AppColors.issuingLight
      : AppColors.verifyingLight;
}

// ─── UNIFIED MUTABLE ENTRY ────────────────────────────────────────────────────

class _StaffEntry {
  final String id;
  String name;
  String email;
  String addedDate;
  StaffStatus status;
  _Portal portal;
  IssuerRole? issuerRole;
  VerifierRole? verifierRole;

  String get roleLabel {
    if (issuerRole != null) return issuerRole!.label;
    if (verifierRole != null) return verifierRole!.label;
    return '—';
  }

  Color get roleColor {
    if (issuerRole != null) {
      switch (issuerRole!) {
        case IssuerRole.admin:
          return AppColors.issuingAccent;
        case IssuerRole.staff:
          return const Color(0xff00ccff);
        case IssuerRole.schemaManager:
          return const Color(0xffafdbf5);
      }
    }
    if (verifierRole != null) {
      switch (verifierRole!) {
        case VerifierRole.admin:
          return AppColors.verifyingAccent;
        case VerifierRole.verifier:
          return const Color(0xff77dd77);
        case VerifierRole.policyManager:
          return const Color(0xff9c9f84);
      }
    }
    return AppColors.textDim;
  }

  _StaffEntry.fromLive(LiveStaffRecord r)
    : id = r.id,
      name = r.name,
      email = r.email,
      addedDate = r.addedDate,
      status = _parseStatus(r.status),
      portal = r.portal == PortalType.issuer
          ? _Portal.issuer
          : _Portal.verifier,
      issuerRole = r.portal == PortalType.issuer
          ? _parseIssuerRole(r.role)
          : null,
      verifierRole = r.portal == PortalType.verifier
          ? _parseVerifierRole(r.role)
          : null;

  static StaffStatus _parseStatus(String s) {
    if (s == 'active') return StaffStatus.active;
    if (s == 'invited') return StaffStatus.invited;
    return StaffStatus.invited;
  }

  static IssuerRole _parseIssuerRole(String s) {
    if (s == 'admin') return IssuerRole.admin;
    if (s == 'schemaManager') return IssuerRole.schemaManager;
    return IssuerRole.staff;
  }

  static VerifierRole _parseVerifierRole(String s) {
    if (s == 'admin') return VerifierRole.admin;
    if (s == 'policyManager') return VerifierRole.policyManager;
    return VerifierRole.verifier;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class ManageStaffPage extends StatefulWidget {
  final VoidCallback onBack;
  const ManageStaffPage({super.key, required this.onBack});

  @override
  State<ManageStaffPage> createState() => _ManageStaffPageState();
}

class _ManageStaffPageState extends State<ManageStaffPage> {
  List<_StaffEntry> _all = [];
  List<_StaffEntry> _filtered = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _query = '';
  final _searchCtrl = TextEditingController();
  String? _selectedId;

  _StaffEntry? get _sel => _selectedId == null
      ? null
      : _all.where((s) => s.id == _selectedId).firstOrNull;

  List<OrgDirectoryRecord> _directoryPool = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final records = await ApiService.getStaff();
      final directory = await ApiService.getOrgDirectory();
      if (mounted) {
        setState(() {
          _all = records.map((r) => _StaffEntry.fromLive(r)).toList();
          _directoryPool = directory;
          _isLoading = false;
          _selectedId = null;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Connection Error: Unable to fetch staff records.';
        });
      }
    }
  }

  void _applyFilter() {
    final q = _query.toLowerCase().trim();
    _filtered = q.isEmpty
        ? List.from(_all)
        : _all
              .where(
                (s) =>
                    s.name.toLowerCase().contains(q) ||
                    s.email.toLowerCase().contains(q) ||
                    s.roleLabel.toLowerCase().contains(q) ||
                    s.portal.label.toLowerCase().contains(q) ||
                    s.status.label.toLowerCase().contains(q),
              )
              .toList();
  }

  void _showToast(String email, _Portal portal) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _InviteToast(
        email: email,
        portal: portal,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  void _showErrorSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.revoked,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openAdd() {
    showDialog(
      context: context,
      builder: (_) => _AddStaffDialog(
        existingEmails: _all.map((s) => s.email).toList(),
        directoryPool: _directoryPool,
        onInvite: (email, portal, roleStr) async {
          final success = await ApiService.inviteStaff(
            email: email,
            portal: portal == _Portal.issuer
                ? PortalType.issuer
                : PortalType.verifier,
            role: roleStr,
          );
          if (success) {
            _fetchData();
            if (mounted) _showToast(email, portal);
          } else {
            _showErrorSnackbar('Connection Error: Failed to invite staff.');
          }
        },
      ),
    );
  }

  void _openEdit() {
    final sel = _sel;
    if (sel == null) return;
    showDialog(
      context: context,
      builder: (_) => _EditStaffDialog(
        entry: sel,
        onSave: (portal, roleStr) async {
          final success = await ApiService.updateStaffRole(
            id: sel.id,
            portal: portal == _Portal.issuer
                ? PortalType.issuer
                : PortalType.verifier,
            role: roleStr,
          );
          if (success) {
            _fetchData();
          } else {
            _showErrorSnackbar('Connection Error: Failed to update role.');
          }
        },
        onDelete: () async {
          final success = await ApiService.deleteStaff(
            id: sel.id,
            portal: sel.portal == _Portal.issuer
                ? PortalType.issuer
                : PortalType.verifier,
          );
          if (success) {
            _fetchData();
          } else {
            _showErrorSnackbar('Connection Error: Failed to remove staff.');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Manage Staff and Permissions',
                style: AppTextStyles.navLabelActive.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 14),
              CountChip(
                count: _all.length,
                label: 'member',
                backgroundColor: AppColors.adminGlow,
                textColor: AppColors.adminAccent,
                borderColor: AppColors.adminAccent.withOpacity(0.35),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: [
                  _buildToolbar(),
                  _buildColHeader(),
                  Expanded(child: _buildRows()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              AppButton(
                label: 'Back',
                icon: Icons.arrow_back_rounded,
                onTap: widget.onBack,
                showBorder: true,
                borderColor: AppColors.border,
                hoverColor: AppColors.surfaceHover,
              ),
              const SizedBox(width: 10),
              AppButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                backgroundColor: AppColors.adminAccent,
                hoverColor: AppColors.adminAccent.withOpacity(0.82),
                disabledBackgroundColor: AppColors.adminAccent.withOpacity(
                  0.28,
                ),
                enabled: _sel != null && !_isLoading,
                tooltip: _sel == null ? 'Select a staff member first' : null,
                onTap: _openEdit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final selCount = _selectedId != null ? 1 : 0;
    return Container(
      color: const Color(0xFF161616),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          CountChip(
            count: _all.where((s) => s.portal == _Portal.issuer).length,
            label: 'Issuer',
            backgroundColor: AppColors.issuingAccent.withOpacity(0.1),
            textColor: AppColors.issuingAccent,
            borderColor: AppColors.issuingAccent.withOpacity(0.25),
          ),
          const SizedBox(width: 8),
          CountChip(
            count: _all.where((s) => s.portal == _Portal.verifier).length,
            label: 'Verifier',
            backgroundColor: AppColors.verifyingAccent.withOpacity(0.1),
            textColor: AppColors.verifyingAccent,
            borderColor: AppColors.verifyingAccent.withOpacity(0.25),
          ),

          const Spacer(),

          if (selCount > 0) ...[
            Text(
              '1 selected',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.adminAccent,
              ),
            ),
            const SizedBox(width: 12),
          ],

          // _IconBtn(
          //   icon: Icons.filter_list_rounded,
          //   tooltip: 'Filter',
          //   onTap: () {},
          // ),
          ToolbarIconBtn(
            icon: Icons.filter_list_rounded,
            tooltip: "Filter",
            onTap: () {},
          ),
          const SizedBox(width: 10),

          QSearchBar(
            controller: _searchCtrl,
            query: _query,
            searchLabel: 'Search by name, email, role, portal…',
            onChanged: (v) => setState(() {
              _query = v;
              _applyFilter();
            }),
            onClear: () => setState(() {
              _query = '';
              _searchCtrl.clear();
              _applyFilter();
            }),
            barWidth: 240,
          ),
          const SizedBox(width: 10),

          AppButton(
            label: 'Add',
            icon: Icons.person_add_outlined,
            backgroundColor: AppColors.adminAccent,
            hoverColor: AppColors.adminAccent.withOpacity(0.82),
            onTap: _openAdd,
          ),
        ],
      ),
    );
  }

  Widget _buildColHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1B2321), // AppColors.adminAccent.withOpacity(0.16)
        border: Border(
          top: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 17),
          _CH('NAME', flex: 4),
          _CH('EMAIL', flex: 4),
          _CH('PORTAL', flex: 2),
          const SizedBox(width: 60),
          _CH('ROLE', flex: 3),
          const SizedBox(width: 32),
          _CH('ADDED', flex: 3),
          _CH('STATUS', flex: 3),
        ],
      ),
    );
  }

  Widget _buildRows() {
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 80.0),
        child: ConnectionErrorWidget(onRetry: _fetchData),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.adminAccent),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _query.isEmpty ? Icons.group_outlined : Icons.search_off_rounded,
              size: 36,
              color: AppColors.textDim,
            ),
            const SizedBox(height: 12),
            Text(
              _query.isEmpty
                  ? 'No staff members found.'
                  : 'No results for "$_query".',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 13,
                color: AppColors.textDim,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _filtered.length,
      separatorBuilder: (_, __) =>
          Container(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final s = _filtered[i];
        return _StaffRow(
          entry: s,
          selected: s.id == _selectedId,
          onTap: () =>
              setState(() => _selectedId = s.id == _selectedId ? null : s.id),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STAFF ROW
// ═════════════════════════════════════════════════════════════════════════════

class _StaffRow extends StatefulWidget {
  final _StaffEntry entry;
  final bool selected;
  final VoidCallback onTap;

  const _StaffRow({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_StaffRow> createState() => _StaffRowState();
}

class _StaffRowState extends State<_StaffRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.entry;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: widget.selected
              ? AppColors.adminAccent.withOpacity(0.07)
              : _hovered
              ? AppColors.surfaceHover
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 3,
                height: 36,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: widget.selected
                      ? AppColors.adminAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Name
              Expanded(
                flex: 4,
                child: Text(
                  s.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Email
              Expanded(
                flex: 4,
                child: Text(
                  s.email,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Portal
              Expanded(
                flex: 2,
                child: Text(
                  s.portal.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: s.portal.accent,
                  ),
                ),
              ),

              const SizedBox(width: 60),

              // Role
              Expanded(
                flex: 3,
                child: Text(
                  s.roleLabel,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: 32),

              // Added
              Expanded(
                flex: 3,
                child: Text(
                  s.addedDate,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                ),
              ),

              // Status
              Expanded(flex: 3, child: _StatusBadge(status: s.status)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ADD STAFF DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _AddStaffDialog extends StatefulWidget {
  final List<String> existingEmails;
  final List<OrgDirectoryRecord> directoryPool;
  final Future<void> Function(String email, _Portal portal, String roleStr)
  onInvite;

  const _AddStaffDialog({required this.existingEmails, required this.directoryPool, required this.onInvite});

  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final _emailCtrl = TextEditingController();
  _Portal _portal = _Portal.issuer;
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
    final roleStr = _portal == _Portal.issuer
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

            _DlgLabel('Portal'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PortalPickerBtn(
                    label: 'Issuer',
                    icon: Icons.badge_outlined,
                    active: _portal == _Portal.issuer,
                    accent: AppColors.issuingAccent,
                    light: AppColors.issuingLight,
                    onTap: _isInviting
                        ? () {}
                        : () => setState(() => _portal = _Portal.issuer),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PortalPickerBtn(
                    label: 'Verifier',
                    icon: Icons.verified_user_outlined,
                    active: _portal == _Portal.verifier,
                    accent: AppColors.verifyingAccent,
                    light: AppColors.verifyingLight,
                    onTap: _isInviting
                        ? () {}
                        : () => setState(() => _portal = _Portal.verifier),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _DlgLabel('Email Address'),
            const SizedBox(height: 6),
            _DlgInput(
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

            _DlgLabel('Role'),
            const SizedBox(height: 6),
            if (_portal == _Portal.issuer)
              _IssuerRoleDropdown(
                value: _issuerRole,
                enabled: !_isInviting,
                onChanged: (r) {
                  if (r != null) setState(() => _issuerRole = r);
                },
              )
            else
              _VerifierRoleDropdown(
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

// ═════════════════════════════════════════════════════════════════════════════
//  EDIT STAFF DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _EditStaffDialog extends StatefulWidget {
  final _StaffEntry entry;
  final Future<void> Function(_Portal portal, String roleStr) onSave;
  final Future<void> Function() onDelete;

  const _EditStaffDialog({
    required this.entry,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditStaffDialog> createState() => _EditStaffDialogState();
}

class _EditStaffDialogState extends State<_EditStaffDialog> {
  late _Portal _portal;
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

  void _onPortalChanged(_Portal p) {
    if (p == _portal || _isSaving || _isDeleting) return;
    setState(() {
      _portal = p;
      if (p == _Portal.issuer) {
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

            _DlgLabel('Portal'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PortalPickerBtn(
                    label: 'Issuer',
                    icon: Icons.badge_outlined,
                    active: _portal == _Portal.issuer,
                    accent: AppColors.issuingAccent,
                    light: AppColors.issuingLight,
                    onTap: () => _onPortalChanged(_Portal.issuer),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PortalPickerBtn(
                    label: 'Verifier',
                    icon: Icons.verified_user_outlined,
                    active: _portal == _Portal.verifier,
                    accent: AppColors.verifyingAccent,
                    light: AppColors.verifyingLight,
                    onTap: () => _onPortalChanged(_Portal.verifier),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _DlgLabel('Email Address'),
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

            _DlgLabel('Role'),
            const SizedBox(height: 6),
            if (_portal == _Portal.issuer)
              _IssuerRoleDropdown(
                value: _issuerRole ?? IssuerRole.staff,
                enabled: !isBusy,
                onChanged: (r) {
                  if (r != null) setState(() => _issuerRole = r);
                },
              )
            else
              _VerifierRoleDropdown(
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
                    final roleStr = _portal == _Portal.issuer
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

// ═════════════════════════════════════════════════════════════════════════════
//  ROLE DROPDOWNS
// ═════════════════════════════════════════════════════════════════════════════

class _IssuerRoleDropdown extends StatelessWidget {
  final IssuerRole value;
  final bool enabled;
  final void Function(IssuerRole?) onChanged;
  const _IssuerRoleDropdown({
    required this.value,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = IssuerRole.values
        .where((r) => r != IssuerRole.admin)
        .toList();
    final safeValue = items.contains(value) ? value : IssuerRole.staff;
    return _DropdownShell<IssuerRole>(
      value: safeValue,
      items: items,
      enabled: enabled,
      label: (r) => r.label,
      subtitle: (r) => (_kIssuerRolePerms[r] ?? []).join(),
      onChanged: onChanged,
    );
  }
}

class _VerifierRoleDropdown extends StatelessWidget {
  final VerifierRole value;
  final bool enabled;
  final void Function(VerifierRole?) onChanged;
  const _VerifierRoleDropdown({
    required this.value,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = VerifierRole.values
        .where((r) => r != VerifierRole.admin)
        .toList();
    final safeValue = items.contains(value) ? value : VerifierRole.verifier;
    return _DropdownShell<VerifierRole>(
      value: safeValue,
      items: items,
      enabled: enabled,
      label: (r) => r.label,
      subtitle: (r) => (_kVerifierRolePerms[r] ?? []).join(),
      onChanged: onChanged,
    );
  }
}

class _DropdownShell<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final bool enabled;
  final String Function(T) label;
  final String Function(T) subtitle;
  final void Function(T?) onChanged;

  const _DropdownShell({
    required this.value,
    required this.items,
    this.enabled = true,
    required this.label,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: enabled ? AppColors.surfaceHover : AppColors.surface,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: AppColors.border),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        dropdownColor: const Color(0xFF1E1E1E),
        iconEnabledColor: enabled ? AppColors.textDim : AppColors.border,
        style: TextStyle(
          fontSize: 13,
          color: enabled ? AppColors.text : AppColors.textMuted,
        ),
        items: items
            .map(
              (r) => DropdownMenuItem<T>(
                value: r,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label(r),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: enabled ? AppColors.text : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle(r),
                      style: AppTextStyles.bodyTiny.copyWith(
                        fontSize: 10,
                        color: enabled ? AppColors.textDim : AppColors.border,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: enabled ? onChanged : null,
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _PortalBadge extends StatelessWidget {
  final _Portal portal;
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

class _PortalPickerBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color accent;
  final Color light;
  final VoidCallback onTap;

  const _PortalPickerBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.accent,
    required this.light,
    required this.onTap,
  });

  @override
  State<_PortalPickerBtn> createState() => _PortalPickerBtnState();
}

class _PortalPickerBtnState extends State<_PortalPickerBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: widget.active
              ? widget.accent.withOpacity(0.12)
              : _h
              ? AppColors.surfaceHover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.active
                ? widget.accent.withOpacity(0.45)
                : _h
                ? AppColors.borderLight
                : AppColors.border,
            width: widget.active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              size: 14,
              color: widget.active ? widget.light : AppColors.textMuted,
            ),
            const SizedBox(width: 7),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
                color: widget.active ? widget.light : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final StaffStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color c;
    final IconData icon;
    switch (status) {
      case StaffStatus.active:
        c = AppColors.verifyingAccent;
        icon = Icons.check_circle_outline_rounded;
        break;
      case StaffStatus.invited:
        c = AppColors.adminAccent;
        icon = Icons.mail_outline_rounded;
        break;
      default:
        c = AppColors.textDim;
        icon = Icons.help_outline_rounded;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          width: 80,
          decoration: BoxDecoration(
            color: c.withOpacity(0.10),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: c.withOpacity(0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 11, color: c),
              const SizedBox(width: 5),
              Text(
                status.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DlgLabel extends StatelessWidget {
  final String text;
  const _DlgLabel(this.text);

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

class _DlgInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final Color accent;
  final bool enabled;
  final void Function(String)? onChanged;

  const _DlgInput({
    required this.controller,
    required this.hint,
    required this.accent,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<_DlgInput> createState() => _DlgInputState();
}

class _DlgInputState extends State<_DlgInput> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (v) => setState(() => _focused = v),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: widget.enabled ? AppColors.surfaceHover : AppColors.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: _focused ? widget.accent.withOpacity(0.6) : AppColors.border,
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        enabled: widget.enabled,
        style: TextStyle(
          fontSize: 13,
          color: widget.enabled ? AppColors.text : AppColors.textDim,
        ),
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          border: InputBorder.none,
          hintText: widget.hint,
          hintStyle: AppTextStyles.bodyTiny.copyWith(
            fontSize: 12,
            color: AppColors.textDim,
          ),
        ),
      ),
    ),
  );
}

Widget _CH(String label, {int flex = 1}) => Expanded(
  flex: flex,
  child: Text(
    label,
    style: AppTextStyles.bodyTiny.copyWith(
      fontSize: 9,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
      color: AppColors.white,
    ),
  ),
);

// class _IconBtn extends StatefulWidget {
//   final IconData icon;
//   final String tooltip;
//   final VoidCallback onTap;
//   const _IconBtn({
//     required this.icon,
//     required this.tooltip,
//     required this.onTap,
//   });
//   @override
//   State<_IconBtn> createState() => _IconBtnState();
// }

// class _IconBtnState extends State<_IconBtn> {
//   bool _h = false;
//   @override
//   Widget build(BuildContext context) => Tooltip(
//     message: widget.tooltip,
//     child: MouseRegion(
//       cursor: SystemMouseCursors.click,
//       onEnter: (_) => setState(() => _h = true),
//       onExit: (_) => setState(() => _h = false),
//       child: GestureDetector(
//         onTap: widget.onTap,
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 130),
//           padding: const EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             color: _h ? AppColors.surfaceHover : Colors.transparent,
//             borderRadius: BorderRadius.circular(7),
//             border: Border.all(
//               color: _h ? AppColors.borderLight : AppColors.border,
//             ),
//           ),
//           child: Icon(widget.icon, size: 16, color: AppColors.textMuted),
//         ),
//       ),
//     ),
//   );
// }

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

class _InviteToast extends StatefulWidget {
  final String email;
  final _Portal portal;
  final VoidCallback onDismiss;

  const _InviteToast({
    required this.email,
    required this.portal,
    required this.onDismiss,
  });

  @override
  State<_InviteToast> createState() => _InviteToastState();
}

class _InviteToastState extends State<_InviteToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_ctrl);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    top: 28,
    left: 0,
    right: 0,
    child: Center(
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.adminAccent.withOpacity(0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.adminAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      size: 14,
                      color: AppColors.adminAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Invitation sent to ',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    widget.email,
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.adminAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
