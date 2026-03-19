// screens/issuer/manage_staff_page.dart
//
// Manage Staff & Permissions
//
// Single unified table listing ALL staff — both issuer and verifier — together.
// A PORTAL column shows a coloured badge (Issuer / Verifier) per row.
// ROLE column shows the role within that portal.
//
// Columns: NAME | EMAIL | PORTAL | ROLE | ADDED | STATUS
//
// Add dialog: user picks Issuer or Verifier first, then chooses the role.
// Edit dialog: role dropdown is scoped to the entry's portal type.
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   case RouteName.issuerStaff:
//     return ManageStaffPage(
//       onBack: () => _handleNavigate(RouteName.issuingSettings),
//     );

import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/filterButton.dart';
import 'package:qportal_webapp/components/searchBar.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/models/verifiying_models.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/app_button.dart';

// ─── CONSTANTS ────────────────────────────────────────────────────────────────

const _kOrgPool = [
  'a.rashidi@org.ae',
  'b.hassan@org.ae',
  'c.mansoor@org.ae',
  'd.khalil@org.ae',
  'e.saif@org.ae',
  'f.nour@org.ae',
  'g.tariq@org.ae',
  'h.layla@org.ae',
];

const _kIssuerRolePerms = <IssuerRole, List<String>>{
  IssuerRole.admin: ['Full issuing access · Manage staff · Settings'],
  IssuerRole.staff: ['Issue & revoke credentials · No staff access'],
  IssuerRole.schemaManager: ['Manage schemas only · Cannot issue'],
};

const _kVerifierRolePerms = <VerifierRole, List<String>>{
  VerifierRole.admin: ['Full verification access · Manage staff · Settings'],
  VerifierRole.verifier: ['Run verifications · No staff or policy access'],
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
  // exactly one of these is non-null
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

  _StaffEntry.issuer(StaffMember m)
    : id = m.id,
      name = m.name,
      email = m.email,
      addedDate = m.addedDate,
      status = m.status,
      portal = _Portal.issuer,
      issuerRole = m.role,
      verifierRole = null;

  _StaffEntry.verifier(VerifierStaffMember m)
    : id = m.id,
      name = m.name,
      email = m.email,
      addedDate = m.addedDate,
      status = m.status,
      portal = _Portal.verifier,
      issuerRole = null,
      verifierRole = m.role;
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
  late List<_StaffEntry> _all;
  late List<_StaffEntry> _filtered;

  String _query = '';
  final _searchCtrl = TextEditingController();
  String? _selectedId;

  // ── helpers ───────────────────────────────────────────────────────────────

  _StaffEntry? get _sel => _selectedId == null
      ? null
      : _all.where((s) => s.id == _selectedId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _all = [
      ...IssuingMockData.staff.map(_StaffEntry.issuer),
      ...kMockVerifierStaff.map(_StaffEntry.verifier),
    ];
    _applyFilter();
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

  String _today() {
    final n = DateTime.now();
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${n.day.toString().padLeft(2, '0')} ${m[n.month]} ${n.year}';
  }

  // ── toast ─────────────────────────────────────────────────────────────────

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

  // ── add dialog ────────────────────────────────────────────────────────────

  void _openAdd() {
    showDialog(
      context: context,
      builder: (_) => _AddStaffDialog(
        existingEmails: _all.map((s) => s.email).toList(),
        onInvite: (entry) {
          setState(() {
            _all.add(entry);
            _applyFilter();
          });
          if (mounted) _showToast(entry.email, entry.portal);
        },
        today: _today(),
      ),
    );
  }

  // ── edit dialog ───────────────────────────────────────────────────────────

  void _openEdit() {
    final sel = _sel;
    if (sel == null) return;
    showDialog(
      context: context,
      builder: (_) => _EditStaffDialog(
        entry: sel,
        onSave: (email, portal, issuerRole, verifierRole) {
          setState(() {
            sel.email = email;
            sel.portal = portal;
            sel.issuerRole = issuerRole;
            sel.verifierRole = verifierRole;
            _applyFilter();
          });
        },
        onDelete: () {
          setState(() {
            _all.removeWhere((s) => s.id == sel.id);
            if (_selectedId == sel.id) _selectedId = null;
            _applyFilter();
          });
        },
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
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
              // Total count chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.adminGlow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.adminAccent.withOpacity(0.35)),
                ),
                child: Text(
                  '${_all.length} members',
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.adminAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Main table container
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

          // Action bar
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
                enabled: _sel != null,
                tooltip: _sel == null ? 'Select a staff member first' : null,
                onTap: _openEdit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── TOOLBAR ───────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    final selCount = _selectedId != null ? 1 : 0;
    return Container(
      color: const Color(0xFF161616),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          // Issuer count chip
          _PortalChip(
            label:
                '${_all.where((s) => s.portal == _Portal.issuer).length} Issuer',
            color: AppColors.issuingAccent,
            light: AppColors.issuingLight,
          ),
          const SizedBox(width: 8),
          // Verifier count chip
          _PortalChip(
            label:
                '${_all.where((s) => s.portal == _Portal.verifier).length} Verifier',
            color: AppColors.verifyingAccent,
            light: AppColors.verifyingLight,
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

          // Filter
          ToolbarIconBtn(
            icon: Icons.filter_list_rounded,
            tooltip: 'Filter',
            onTap: () {},
          ),
          const SizedBox(width: 10),

          // Search
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

          // Add
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

  // ── COLUMN HEADER ─────────────────────────────────────────────────────────

  Widget _buildColHeader() {
    return Container(
      decoration:  BoxDecoration(
        color: AppColors.adminAccent.withOpacity(0.16),
        border: Border(
          top: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 36), // checkbox
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

  // ── ROWS ──────────────────────────────────────────────────────────────────

  Widget _buildRows() {
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
    final accent = s.portal.accent;
    final light = s.portal.light;

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
              // Checkbox
              SizedBox(
                width: 36,
                child: Checkbox(
                  value: widget.selected,
                  onChanged: (_) => widget.onTap(),
                  activeColor: AppColors.adminAccent,
                  checkColor: Colors.white,
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),

              // Name + avatar
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withOpacity(0.12),
                        border: Border.all(color: accent.withOpacity(0.30)),
                      ),
                      child: Center(
                        child: Text(
                          s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: light,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
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
                  ],
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

              // Portal badge
              Expanded(flex: 2, child: _PortalBadge(portal: s.portal)),

              const SizedBox(width: 60),

              // Role chip
              Expanded(
                flex: 3,
                child: _RoleChip(label: s.roleLabel, color: s.roleColor),
              ),

              const SizedBox(width: 32),

              // Added date
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

              // Status badge
              Expanded(flex: 3, child: _StatusBadge(status: s.status)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ADD STAFF DIALOG  (pick portal → pick role)
// ═════════════════════════════════════════════════════════════════════════════

class _AddStaffDialog extends StatefulWidget {
  final List<String> existingEmails;
  final void Function(_StaffEntry entry) onInvite;
  final String today;

  const _AddStaffDialog({
    required this.existingEmails,
    required this.onInvite,
    required this.today,
  });

  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final _emailCtrl = TextEditingController();
  _Portal _portal = _Portal.issuer;
  IssuerRole _issuerRole = IssuerRole.staff;
  VerifierRole _verifierRole = VerifierRole.verifier;
  List<String> _suggestions = [];

  bool get _canInvite => _emailCtrl.text.trim().isNotEmpty;

  void _onEmailChanged(String v) {
    final q = v.trim().toLowerCase();
    final pool = {..._kOrgPool, ...widget.existingEmails}.toList();
    setState(() {
      _suggestions = q.isEmpty
          ? []
          : pool
                .where(
                  (e) =>
                      e.toLowerCase().contains(q) &&
                      !widget.existingEmails.contains(e),
                )
                .toList();
    });
  }

  void _pickSuggestion(String e) {
    _emailCtrl.text = e;
    setState(() => _suggestions = []);
  }

  void _doInvite() {
    final email = _emailCtrl.text.trim();
    final entry = _portal == _Portal.issuer
        ? _StaffEntry.issuer(
            StaffMember(
              id: 'STF-${DateTime.now().millisecondsSinceEpoch}',
              name: email.split('@').first,
              email: email,
              role: _issuerRole,
              addedDate: widget.today,
              status: StaffStatus.invited,
            ),
          )
        : _StaffEntry.verifier(
            VerifierStaffMember(
              id: 'VST-${DateTime.now().millisecondsSinceEpoch}',
              name: email.split('@').first,
              email: email,
              role: _verifierRole,
              addedDate: widget.today,
              status: StaffStatus.invited,
            ),
          );
    widget.onInvite(entry);
    Navigator.pop(context);
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
            // Header
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

            // Portal picker
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
                    onTap: () => setState(() => _portal = _Portal.issuer),
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
                    onTap: () => setState(() => _portal = _Portal.verifier),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Email
            _DlgLabel('Email Address'),
            const SizedBox(height: 6),
            _DlgInput(
              controller: _emailCtrl,
              hint: 'staff@organisation.ae',
              accent: _portal.accent,
              onChanged: _onEmailChanged,
            ),
            if (_suggestions.isNotEmpty) ...[
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

            // Role
            _DlgLabel('Role'),
            const SizedBox(height: 6),
            if (_portal == _Portal.issuer)
              _IssuerRoleDropdown(
                value: _issuerRole,
                onChanged: (r) {
                  if (r != null) setState(() => _issuerRole = r);
                },
              )
            else
              _VerifierRoleDropdown(
                value: _verifierRole,
                onChanged: (r) {
                  if (r != null) setState(() => _verifierRole = r);
                },
              ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                AppButton(
                  label: 'Cancel',
                  onTap: () => Navigator.pop(context),
                  showBorder: true,
                  borderColor: AppColors.border,
                  hoverColor: AppColors.surfaceHover,
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Invite',
                  icon: Icons.send_outlined,
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
  final void Function(
    String email,
    _Portal portal,
    IssuerRole? issuerRole,
    VerifierRole? verifierRole,
  )
  onSave;
  final VoidCallback onDelete;

  const _EditStaffDialog({
    required this.entry,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditStaffDialog> createState() => _EditStaffDialogState();
}

class _EditStaffDialogState extends State<_EditStaffDialog> {
  late TextEditingController _emailCtrl;
  late _Portal _portal;
  IssuerRole? _issuerRole;
  VerifierRole? _verifierRole;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.entry.email);
    _portal = widget.entry.portal;
    _issuerRole = widget.entry.issuerRole;
    _verifierRole = widget.entry.verifierRole;
  }

  void _onPortalChanged(_Portal p) {
    if (p == _portal) return;
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
            // Header
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

            // Portal picker
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
            _DlgInput(
              controller: _emailCtrl,
              hint: 'staff@organisation.ae',
              accent: accent,
            ),
            const SizedBox(height: 16),

            _DlgLabel('Role'),
            const SizedBox(height: 6),
            if (_portal == _Portal.issuer)
              _IssuerRoleDropdown(
                value: _issuerRole ?? IssuerRole.staff,
                onChanged: (r) {
                  if (r != null) setState(() => _issuerRole = r);
                },
              )
            else
              _VerifierRoleDropdown(
                value: _verifierRole ?? VerifierRole.verifier,
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
                  onTap: () => Navigator.pop(context),
                  showBorder: true,
                  borderColor: AppColors.border,
                  hoverColor: AppColors.surfaceHover,
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  showBorder: true,
                  borderColor: AppColors.revoked,
                  textColor: AppColors.revoked,
                  hoverColor: AppColors.surfaceHover,
                  onTap: () {
                    widget.onDelete();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: 'Save',
                  icon: Icons.check_rounded,
                  backgroundColor: accent,
                  hoverColor: accent.withOpacity(0.82),
                  onTap: () {
                    widget.onSave(
                      _emailCtrl.text.trim(),
                      _portal,
                      _issuerRole,
                      _verifierRole,
                    );
                    Navigator.pop(context);
                  },
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
//  ROLE DROPDOWNS
// ═════════════════════════════════════════════════════════════════════════════

class _IssuerRoleDropdown extends StatelessWidget {
  final IssuerRole value;
  final void Function(IssuerRole?) onChanged;
  const _IssuerRoleDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => _DropdownShell<IssuerRole>(
    value: value,
    items: IssuerRole.values,
    label: (r) => r.label,
    subtitle: (r) => (_kIssuerRolePerms[r] ?? []).join(),
    onChanged: onChanged,
  );
}

class _VerifierRoleDropdown extends StatelessWidget {
  final VerifierRole value;
  final void Function(VerifierRole?) onChanged;
  const _VerifierRoleDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => _DropdownShell<VerifierRole>(
    value: value,
    items: VerifierRole.values,
    label: (r) => r.label,
    subtitle: (r) => (_kVerifierRolePerms[r] ?? []).join(),
    onChanged: onChanged,
  );
}

class _DropdownShell<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) label;
  final String Function(T) subtitle;
  final void Function(T?) onChanged;

  const _DropdownShell({
    required this.value,
    required this.items,
    required this.label,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.surfaceHover,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: AppColors.border),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        dropdownColor: const Color(0xFF1E1E1E),
        iconEnabledColor: AppColors.textDim,
        style: const TextStyle(fontSize: 13, color: AppColors.text),
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle(r),
                      style: AppTextStyles.bodyTiny.copyWith(
                        fontSize: 10,
                        color: AppColors.textDim,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ─── PORTAL BADGE ─────────────────────────────────────────────────────────────

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

// ─── PORTAL CHIP (toolbar count) ──────────────────────────────────────────────

class _PortalChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color light;
  const _PortalChip({
    required this.label,
    required this.color,
    required this.light,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: light),
    ),
  );
}

// ─── PORTAL PICKER BUTTON (add dialog) ───────────────────────────────────────

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

// ─── ROLE CHIP ────────────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  final String label;
  final Color color;
  const _RoleChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: color.withOpacity(0.30)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      overflow: TextOverflow.ellipsis,
    ),
  );
}

// ─── STATUS BADGE ─────────────────────────────────────────────────────────────

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

// ─── DIALOG LABEL ─────────────────────────────────────────────────────────────

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

// ─── DIALOG INPUT ─────────────────────────────────────────────────────────────

class _DlgInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final Color accent;
  final int maxLines;
  final void Function(String)? onChanged;

  const _DlgInput({
    required this.controller,
    required this.hint,
    required this.accent,
    this.maxLines = 1,
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
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: _focused ? widget.accent.withOpacity(0.6) : AppColors.border,
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        maxLines: widget.maxLines,
        style: const TextStyle(fontSize: 13, color: AppColors.text),
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

// ─── COLUMN HEADER CELL ───────────────────────────────────────────────────────

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

// ─── ICON BUTTON ──────────────────────────────────────────────────────────────

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _h ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _h ? AppColors.borderLight : AppColors.border,
            ),
          ),
          child: Icon(widget.icon, size: 16, color: AppColors.textMuted),
        ),
      ),
    ),
  );
}

// ─── SUGGESTION TILE ──────────────────────────────────────────────────────────

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

// ═════════════════════════════════════════════════════════════════════════════
//  INVITE TOAST
// ═════════════════════════════════════════════════════════════════════════════

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
                    child: Icon(
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
