import 'package:flutter/material.dart';
import 'package:qportal_webapp/dialog/addStaff_dialog.dart';
import 'package:qportal_webapp/dialog/editStaff_dialog.dart';
import 'package:qportal_webapp/components/toast.dart';
import 'package:qportal_webapp/models/IT_ADMIN/orgDirectory_model.dart';
import 'package:qportal_webapp/models/IT_ADMIN/staff/issuerStaff_enum.dart';
import 'package:qportal_webapp/models/IT_ADMIN/staff/staff_model.dart';
import 'package:qportal_webapp/models/IT_ADMIN/staff/verifierStaff_enum.dart';
import 'package:qportal_webapp/services/admin_api.dart';
import 'package:qportal_webapp/tables/manageStaff_table.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';

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
  List<StaffEntry> _all = [];
  List<StaffEntry> _filtered = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _query = '';
  final _searchCtrl = TextEditingController();
  String? _selectedId;

  StaffEntry? get _sel => _selectedId == null
      ? null
      : _all.where((s) => s.id == _selectedId).firstOrNull;

  List<OrgDirectoryRecord> _directoryPool = [];

  OverlayEntry? _toastEntry;

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
      final records = await AdminApi.getStaff();
      final directory = await AdminApi.getOrgDirectory();
      if (mounted) {
        setState(() {
          _all = records.map((r) => StaffEntry.fromLive(r)).toList();
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

  void _openAdd() {
    showDialog(
      context: context,
      builder: (_) => AddStaffDialog(
        existingEmails: _all.map((s) => s.email).toList(),
        directoryPool: _directoryPool,
        onInvite: (email, portal, roleStr) async {
          final success = await AdminApi.inviteStaff(
            email: email,
            portal: portal,
            role: roleStr,
          );
          if (success) {
            _fetchData();
            if (mounted) showToast('Invite sent to $email', Icons.email, false);
          } else {
            showToast(
              'Error 400: Failed to invite staff',
              Icons.error_outline,
              true,
            );
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
      builder: (_) => EditStaffDialog(
        entry: sel,
        onSave: (portal, roleStr) async {
          final success = await AdminApi.updateStaffRole(
            id: sel.id,
            portal: portal,
            role: roleStr,
          );
          if (success) {
            _fetchData();
          } else {
            showToast(
              'Error 400: Failed to update role.',
              Icons.error_outline,
              true,
            );
          }
        },
        onDelete: () async {
          final success = await AdminApi.deleteStaff(
            id: sel.id,
            portal: sel.portal,
          );
          if (success) {
            _fetchData();
          } else {
            showToast(
              'Error 400: Failed to remove staff.',
              Icons.error_outline,
              true,
            );
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
            ],
          ),
          const SizedBox(height: 18),

          Expanded(
            child: ManageTable(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              items: _filtered,
              query: _query,
              selectedId: _selectedId,
              searchCtrl: _searchCtrl,
              onRetry: _fetchData,
              onToggleRow: (id) {
                setState(() {
                  _selectedId = id == _selectedId ? null : id;
                });
              },
              onSearchChanged: (v) => setState(() {
                _query = v;
                _applyFilter();
              }),
              onClearSearch: () => setState(() {
                _query = '';
                _searchCtrl.clear();
                _applyFilter();
              }),
              onAddStaff: _openAdd,
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void showToast(String message, IconData reqIcons, bool isError) {
    _toastEntry?.remove();
    _toastEntry = OverlayEntry(
      builder: (_) => Toast(
        message: message,
        toastIcons: reqIcons,
        onDone: () {
          _toastEntry?.remove();
          _toastEntry = null;
        },
        bgColor: isError ? AppColors.revoked : AppColors.adminMid,
        iconColor: AppColors.text,
      ),
    );
    Overlay.of(context).insert(_toastEntry!);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ROLE DROPDOWNS
// ═════════════════════════════════════════════════════════════════════════════

class IssuerRoleDropdown extends StatelessWidget {
  final IssuerRole value;
  final bool enabled;
  final void Function(IssuerRole?) onChanged;
  const IssuerRoleDropdown({
    super.key,
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
      subtitle: (r) => r.description,
      onChanged: onChanged,
    );
  }
}

class VerifierRoleDropdown extends StatelessWidget {
  final VerifierRole value;
  final bool enabled;
  final void Function(VerifierRole?) onChanged;
  const VerifierRoleDropdown({
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
      subtitle: (r) => r.description,
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
                        letterSpacing: 0.4,
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

class PortalPickerBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color accent;
  final Color light;
  final VoidCallback onTap;

  const PortalPickerBtn({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.accent,
    required this.light,
    required this.onTap,
  });

  @override
  State<PortalPickerBtn> createState() => PortalPickerBtnState();
}

class PortalPickerBtnState extends State<PortalPickerBtn> {
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

class DlgLabel extends StatelessWidget {
  final String text;
  const DlgLabel(this.text, {super.key});

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

class DlgInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final Color accent;
  final bool enabled;
  final void Function(String)? onChanged;

  const DlgInput({
    required this.controller,
    required this.hint,
    required this.accent,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<DlgInput> createState() => DlgInputState();
}

class DlgInputState extends State<DlgInput> {
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
