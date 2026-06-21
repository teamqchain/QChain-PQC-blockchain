// screens/verifier/policies_page.dart
//
// Policies — define custom rules credentials must meet in addition to
// cryptographic validation.
//
// Layout contract (mirrors subscription_page.dart exactly):
//   Padding → Column
//     Title (fixed)
//     Expanded container (toolbar → header → list)
//     Pagination bar (fixed)
//     Action bar (fixed)
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   case RouteName.policies:
//     return PoliciesPage(
//       onBack:   () => _handleNavigate(RouteName.dashboard),
//       onView:   (id) => _handleNavigate(RouteName.policyDetail, arg: id),
//     );

import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/filterButton.dart';
import 'package:qportal_webapp/components/searchBar.dart';
import 'package:qportal_webapp/models/VERIFIER/policy_model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/components/paginationBar.dart';
import 'package:qportal_webapp/components/statusBadge.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class PoliciesPage extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(String policyId)? onView;
  final VoidCallback? onCreatePolicy;

  const PoliciesPage({super.key, required this.onBack, this.onView, this.onCreatePolicy});

  @override
  State<PoliciesPage> createState() => _PoliciesPageState();
}

class _PoliciesPageState extends State<PoliciesPage> {
  // ── data ──────────────────────────────────────────────────────────────────
  late List<PolicyRecord> _allRows;
  late List<PolicyRecord> _filtered;

  // ── selection (single row) ────────────────────────────────────────────────
  String? _selectedId;
  PolicyRecord? get _sel => _selectedId == null
      ? null
      : _allRows.firstWhere(
          (r) => r.id == _selectedId,
          orElse: () => _allRows.first,
        );

  // ── search ────────────────────────────────────────────────────────────────
  String _query = '';
  final _searchCtrl = TextEditingController();

  // ── pagination ────────────────────────────────────────────────────────────
  int _rowsPerPage = 25;
  int _currentPage = 1;

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _allRows = List.from(kMockPolicies);
    _applyFilter();
  }

  void _applyFilter() {
    final q = _query.toLowerCase().trim();
    _filtered = q.isEmpty
        ? List.from(_allRows)
        : _allRows.where((r) {
            return r.id.toLowerCase().contains(q) ||
                r.policyName.toLowerCase().contains(q) ||
                r.appliesTo.toLowerCase().contains(q) ||
                r.createdBy.toLowerCase().contains(q) ||
                r.status.label.toLowerCase().contains(q);
          }).toList();

    final maxPage = (_filtered.length / _rowsPerPage).ceil().clamp(1, 99999);
    if (_currentPage > maxPage) _currentPage = maxPage;
  }

  List<PolicyRecord> get _pageRows {
    final start = (_currentPage - 1) * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  int get _totalPages =>
      (_filtered.length / _rowsPerPage).ceil().clamp(1, 99999);

  // ── button enablement ─────────────────────────────────────────────────────

  bool get _deleteEnabled => _selectedId != null;
  bool get _viewEnabled => _selectedId != null;

  String? get _deleteTooltip =>
      _selectedId == null ? 'Select a policy to delete' : null;

  String? get _viewTooltip =>
      _selectedId == null ? 'Select a policy to view details' : null;

  // ── actions ───────────────────────────────────────────────────────────────

  void _onDelete() {
    final record = _sel!;
    showDialog(
      context: context,
      builder: (_) => _DeleteDialog(
        policyName: record.policyName,
        policyId: record.id,
        onConfirm: () {
          setState(() {
            _allRows.removeWhere((r) => r.id == record.id);
            _selectedId = null;
            _applyFilter();
          });
        },
      ),
    );
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() => _currentPage = page);
  }

  void _changeRowsPerPage(int rpp) {
    setState(() {
      _rowsPerPage = rpp;
      _currentPage = 1;
      _applyFilter();
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ────────────────────────────────────────────────────────
          Text(
            'Policies',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // ── Main container ───────────────────────────────────────────────
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
                  Container(height: 1, color: AppColors.border),
                  _buildHeader(),
                  Container(height: 1, color: AppColors.border),
                  Expanded(child: _buildList()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Pagination ───────────────────────────────────────────────────
          PaginationBar(
            currentPage: _currentPage,
            totalPages: _totalPages,
            rowsPerPage: _rowsPerPage,
            totalRows: _filtered.length,
            onPageChanged: _goToPage,
            onRowsPerPageChanged: _changeRowsPerPage,
            accentColor: AppColors.verifyingAccent,
          ),
          const SizedBox(height: 14),

          // ── Action bar ───────────────────────────────────────────────────
          _buildActionBar(),
        ],
      ),
    );
  }

  // ── TOOLBAR ───────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF161616),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          // Count chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.verifyingAccent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.verifyingAccent.withOpacity(0.25),
              ),
            ),
            child: Text(
              '${_filtered.length} polic${_filtered.length == 1 ? 'y' : 'ies'}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.verifyingLight,
              ),
            ),
          ),

          const Spacer(),

          // Filter
          ToolbarIconBtn(
            icon: Icons.filter_list_rounded,
            tooltip: 'Filter',
            onTap: () {},
          ),
          const SizedBox(width: 8),

          // Search bar
          QSearchBar(
            controller: _searchCtrl,
            query: _query,
            onChanged: (v) => setState(() {
              _query = v;
              _currentPage = 1;
              _applyFilter();
            }),
            onClear: () {
              _searchCtrl.clear();
              setState(() {
                _query = '';
                _currentPage = 1;
                _applyFilter();
              });
            },
            barWidth: 260,
            searchLabel: 'Search by name, category, status…',
            activeColor: AppColors.verifyingAccent,
          ),
          const SizedBox(width: 10),

          // Add New Policy
          AppButton(
            icon: Icons.add_rounded,
            label: 'Add New Policy',
            backgroundColor: AppColors.verifyingAccent,
            hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
            onTap: () => widget.onCreatePolicy?.call(),
          ),
        ],
      ),
    );
  }

  // ── COLUMN HEADER ─────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: AppColors.verifyingAccent.withOpacity(0.16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          const SizedBox(width: 15), // aligns with selection stripe
          _th('POLICY ID', flex: 1),
          _th('POLICY NAME', flex: 4),
          _thFixed('APPLIES TO', 160),
          const SizedBox(width: 60),
          _th('CREATED DATE', flex: 2),
          _th('CREATED BY', flex: 2),
          _thFixed('STATUS', 120),
        ],
      ),
    );
  }

  Widget _th(String label, {int flex = 1}) => Expanded(
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

  Widget _thFixed(String label, double width) => SizedBox(
    width: width,
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

  // ── LIST ──────────────────────────────────────────────────────────────────

  Widget _buildList() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _query.isEmpty ? Icons.policy_outlined : Icons.search_off_rounded,
              size: 36,
              color: AppColors.textDim,
            ),
            const SizedBox(height: 12),
            Text(
              _query.isEmpty
                  ? 'No policies found.'
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _pageRows.length,
      separatorBuilder: (_, __) =>
          Container(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final record = _pageRows[i];
        return _PolicyRow(
          record: record,
          isSelected: record.id == _selectedId,
          onTap: () => setState(() {
            _selectedId = record.id == _selectedId ? null : record.id;
          }),
        );
      },
    );
  }

  // ── ACTION BAR ────────────────────────────────────────────────────────────

  Widget _buildActionBar() {
    final sel = _sel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Back
        AppButton(
          icon: Icons.arrow_back_rounded,
          label: 'Back',
          showBorder: true,
          borderColor: AppColors.border,
          hoverColor: AppColors.surfaceHover,
          onTap: widget.onBack,
        ),
        const SizedBox(width: 10),

        // Delete
        AppButton(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          showBorder: true,
          borderColor: _deleteEnabled
              ? AppColors.revoked.withOpacity(0.5)
              : AppColors.border,
          textColor: _deleteEnabled ? AppColors.revoked : AppColors.textDim,
          iconColor: _deleteEnabled ? AppColors.revoked : AppColors.textDim,
          hoverColor: _deleteEnabled
              ? AppColors.revoked.withOpacity(0.08)
              : Colors.transparent,
          disabledBorderColor: AppColors.border,
          enabled: _deleteEnabled,
          tooltip: _deleteTooltip,
          onTap: _onDelete,
        ),
        const SizedBox(width: 10),

        // View
        AppButton(
          icon: Icons.open_in_new_rounded,
          label: 'View',
          backgroundColor: _viewEnabled
              ? AppColors.verifyingAccent
              : Colors.transparent,
          hoverColor: _viewEnabled
              ? AppColors.verifyingAccent.withOpacity(0.82)
              : Colors.transparent,
          showBorder: !_viewEnabled,
          borderColor: AppColors.border,
          disabledBorderColor: AppColors.border,
          textColor: _viewEnabled ? AppColors.white : AppColors.textDim,
          iconColor: _viewEnabled ? AppColors.white : AppColors.textDim,
          disabledBackgroundColor: AppColors.verifyingAccent.withOpacity(0.28),
          enabled: _viewEnabled,
          tooltip: _viewTooltip,
          onTap: () => widget.onView?.call(_selectedId!),
        ),

        // Selection hint
        if (sel != null) ...[
          const SizedBox(width: 16),
          Container(width: 1, height: 18, color: AppColors.border),
          const SizedBox(width: 14),
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 12,
            color: AppColors.textDim,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${sel.policyName}  ·  ${sel.id}',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                color: AppColors.textDim,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  POLICY ROW
// ═════════════════════════════════════════════════════════════════════════════

class _PolicyRow extends StatefulWidget {
  final PolicyRecord record;
  final bool isSelected;
  final VoidCallback onTap;

  const _PolicyRow({
    required this.record,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PolicyRow> createState() => _PolicyRowState();
}

class _PolicyRowState extends State<_PolicyRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: widget.isSelected
              ? AppColors.verifyingAccent.withOpacity(0.07)
              : _hovered
              ? AppColors.surfaceHover
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Selection stripe
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 3,
                height: 34,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppColors.verifyingAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Policy ID
              Expanded(
                flex: 1,
                child: Text(
                  r.id,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.verifyingLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Policy Name
              Expanded(
                flex: 4,
                child: Text(
                  r.policyName,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Applies To — box badge
              SizedBox(width: 160, child: AppliesToBadge(label: r.appliesTo)),
              const SizedBox(width: 60),

              // Created Date
              Expanded(
                flex: 2,
                child: Text(
                  r.createdDate,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Created By
              Expanded(
                flex: 2,
                child: Text(
                  r.createdBy,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Status badge
              SizedBox(width: 120, child: StatusBadge(fg: r.status.fg, label: r.status.label, iconPresent: false,)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  APPLIES TO BADGE  — coloured, matches _CategoryChip in schemas_page.dart
// ═════════════════════════════════════════════════════════════════════════════

class AppliesToBadge extends StatelessWidget {
  final String label;
  const AppliesToBadge({super.key, required this.label});

  Color _color() {
    final l = label.toLowerCase();
    if (l.contains('medical')) return const Color(0xFF06B6D4);
    if (l.contains('corporate')) return const Color(0xFFA855F7);
    if (l.contains('government')) return const Color(0xFFA855F7);
    if (l.contains('professional')) return const Color(0xFFF59E0B);
    if (l.contains('academic')) return AppColors.issuingLight;
    // 'All Credentials' and anything else
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final fg = _color();
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: fg,
        letterSpacing: 0.2,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════════
//  DELETE CONFIRMATION DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _DeleteDialog extends StatelessWidget {
  final String policyName;
  final String policyId;
  final VoidCallback onConfirm;

  const _DeleteDialog({
    required this.policyName,
    required this.policyId,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 40,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.revoked.withOpacity(0.14),
                      border: Border.all(
                        color: AppColors.revoked.withOpacity(0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 17,
                      color: AppColors.revoked,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Policy',
                          style: AppTextStyles.navLabelActive.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '$policyId  ·  $policyName',
                          style: AppTextStyles.bodyTiny.copyWith(
                            fontSize: 11,
                            color: AppColors.textDim,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Warning box ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.revoked.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.revoked.withOpacity(0.22),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 15,
                      color: AppColors.revoked.withOpacity(0.8),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Deleting this policy will permanently remove all its rules. '
                        'This action cannot be undone.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Buttons ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancel',
                      showBorder: true,
                      borderColor: AppColors.border,
                      hoverColor: AppColors.surfaceHover,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      backgroundColor: AppColors.revoked,
                      hoverColor: AppColors.revoked.withOpacity(0.82),
                      onTap: () {
                        Navigator.pop(context);
                        onConfirm();
                      },
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


// ─── TOOLBAR ICON BUTTON ──────────────────────────────────────────────────────

class _ToolbarIconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ToolbarIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  @override
  State<_ToolbarIconBtn> createState() => _ToolbarIconBtnState();
}

class _ToolbarIconBtnState extends State<_ToolbarIconBtn> {
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
          duration: const Duration(milliseconds: 120),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _h ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _h ? AppColors.border : Colors.transparent,
            ),
          ),
          child: Icon(widget.icon, size: 17, color: AppColors.textMuted),
        ),
      ),
    ),
  );
}
