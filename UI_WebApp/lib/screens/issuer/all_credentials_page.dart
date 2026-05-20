// view/issuing/all_credentials_page.dart
//
// All Credentials — paginated table of every issued credential.
//
// Integration:
//   case RouteName.allCredentials:
//     return AllCredentialsPage(
//       onViewCredential: (id) => onNavigate(RouteName.credentialDetail, arg: id),
//     );

import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/filterButton.dart';
import 'package:qportal_webapp/components/searchBar.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/services/api_service.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';

// ─── PAGE ────────────────────────────────────────────────────────────────────

class AllCredentialsPage extends StatefulWidget {
  /// Called when the user clicks "View" for a single selected credential.
  final void Function(String credentialId)? onViewCredential;

  const AllCredentialsPage({super.key, this.onViewCredential});

  @override
  State<AllCredentialsPage> createState() => _AllCredentialsPageState();
}

class _AllCredentialsPageState extends State<AllCredentialsPage> {
  // ── data ───────────────────────────────────────────────────────────────────
  List<CredentialRecord> _allRows = [];
  List<CredentialRecord> _filtered = [];
  bool _isLoading = true;

  // ── selection ──────────────────────────────────────────────────────────────
  final Set<String> _selected = {}; // credential IDs
  bool _selectAll = false;

  // ── search / filter ────────────────────────────────────────────────────────
  String _search = '';
  final _searchCtrl = TextEditingController();

  // ── pagination ─────────────────────────────────────────────────────────────
  int _rowsPerPage = 25;
  int _currentPage = 1;

  // ─── helpers ──────────────────────────────────────────────────────────────

  // @override
  // void initState() {
  //   super.initState();
    // _allRows = List<CredentialRecord>.from(IssuingMockData.credentials);
  //   _applyFilter();
  // }

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final data = await ApiService.getAllCredentials();
    if (!mounted) return;
    setState(() {
      _allRows = data;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    final q = _search.toLowerCase().trim();
    _filtered = q.isEmpty
        ? List.from(_allRows)
        : _allRows.where((r) {
            return r.id.toLowerCase().contains(q) ||
                r.holderName.toLowerCase().contains(q) ||
                r.credentialType.toLowerCase().contains(q) ||
                r.issuedBy.toLowerCase().contains(q) ||
                r.status.label.toLowerCase().contains(q);
          }).toList();

    // Clamp current page after filter
    final maxPage = (_filtered.length / _rowsPerPage).ceil().clamp(1, 99999);
    if (_currentPage > maxPage) _currentPage = maxPage;

    // Recalculate select-all state
    final pageIds = _pageRows.map((r) => r.id).toSet();
    _selectAll =
        pageIds.isNotEmpty && pageIds.every((id) => _selected.contains(id));
  }

  List<CredentialRecord> get _pageRows {
    final start = (_currentPage - 1) * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  int get _totalPages =>
      (_filtered.length / _rowsPerPage).ceil().clamp(1, 99999);

  int get _selectedCount => _selected.length;

  void _toggleRow(String id) {
    setState(() {
      _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
      final pageIds = _pageRows.map((r) => r.id).toSet();
      _selectAll = pageIds.every((id) => _selected.contains(id));
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      if (_selectAll) {
        _selected.addAll(_pageRows.map((r) => r.id));
      } else {
        _selected.removeAll(_pageRows.map((r) => r.id));
      }
    });
  }

  void _changeRowsPerPage(int rpp) {
    setState(() {
      _rowsPerPage = rpp;
      _currentPage = 1;
      _applyFilter();
    });
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() {
      _currentPage = page;
      // Refresh select-all for new page
      final pageIds = _pageRows.map((r) => r.id).toSet();
      _selectAll = pageIds.every((id) => _selected.contains(id));
    });
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ───────────────────────────────────────────────────────────
          Text(
            'All Credentials',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // ── Table container ─────────────────────────────────────────────────
          Expanded(
            child: _CredentialTable(
              isLoading: _isLoading,
              rows: _pageRows,
              selected: _selected,
              selectAll: _selectAll,
              totalFiltered: _filtered.length,
              onToggleRow: _toggleRow,
              onToggleAll: _toggleSelectAll,
              search: _search,
              searchCtrl: _searchCtrl,
              onSearchChanged: (v) => setState(() {
                _search = v;
                _currentPage = 1;
                _applyFilter();
              }),
              onClearSearch: () {
                _searchCtrl.clear();
                setState(() {
                  _search = '';
                  _currentPage = 1;
                  _applyFilter();
                });
              },
            ),
          ),

          const SizedBox(height: 14),

          // ── Pagination ──────────────────────────────────────────────────────
          _PaginationBar(
            currentPage: _currentPage,
            totalPages: _totalPages,
            rowsPerPage: _rowsPerPage,
            totalRows: _filtered.length,
            onPageChanged: _goToPage,
            onRowsPerPageChanged: _changeRowsPerPage,
          ),

          const SizedBox(height: 14),

          // ── Action buttons ──────────────────────────────────────────────────
          _ActionBar(
            selectedCount: _selectedCount,
            onExport: () {}, // simulated
            onView: _selectedCount == 1
                ? () => widget.onViewCredential?.call(_selected.first)
                : null,
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
}

// ═════════════════════════════════════════════════════════════════════════════
// TABLE
// ═════════════════════════════════════════════════════════════════════════════

class _CredentialTable extends StatelessWidget {
  final bool isLoading;
  final List<CredentialRecord> rows;
  final Set<String> selected;
  final bool selectAll;
  final int totalFiltered;
  final void Function(String id) onToggleRow;
  final void Function(bool?) onToggleAll;
  final String search;
  final TextEditingController searchCtrl;
  final void Function(String) onSearchChanged;
  final VoidCallback onClearSearch;

  const _CredentialTable({
    required this.isLoading,
    required this.rows,
    required this.selected,
    required this.selectAll,
    required this.totalFiltered,
    required this.onToggleRow,
    required this.onToggleAll,
    required this.search,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // ── Toolbar ──────────────────────────────────────────────────────
          _buildToolbar(),
          Container(height: 1, color: AppColors.border),

          // ── Header row ───────────────────────────────────────────────────
          _buildHeader(),
          Container(height: 1, color: AppColors.border),

          // ── Data rows ────────────────────────────────────────────────────
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                    ? const Center(
                        child: Text(
                          'No credentials match your search.',
                          style:
                              TextStyle(color: AppColors.textDim, fontSize: 12),
                        ),
                      )
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) =>
                            Container(height: 1, color: AppColors.border),
                        itemBuilder: (_, i) => _CredentialRow(
                          record: rows[i],
                          isSelected: selected.contains(rows[i].id),
                          onToggle: () => onToggleRow(rows[i].id),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final selCount = selected.length;

    return Container(
      color: const Color(0xFF161616),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Row count / selection info
          Expanded(
            child: Text(
              selCount > 0
                  ? '$selCount of $totalFiltered selected'
                  : '$totalFiltered credentials',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selCount > 0 ? AppColors.issuingAccent : Colors.white,
              ),
            ),
          ),

          // Filter icon
          ToolbarIconBtn(
            icon: Icons.filter_list_rounded,
            tooltip: 'Filter',
            onTap: () {},
          ),
          const SizedBox(width: 6),

          // Search bar
          QSearchBar(
            controller: searchCtrl,
            query: search,
            onChanged: onSearchChanged,
            onClear: onClearSearch,
            barWidth: 240,
            searchLabel: 'Search by ID, name, type, status…',
            activeColor: AppColors.issuingAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.issuingAccent.withOpacity(0.16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          // Select-all checkbox
          SizedBox(
            width: 32,
            child: Checkbox(
              value: selectAll,
              tristate: true,
              onChanged: onToggleAll,
              activeColor: AppColors.issuingAccent,
              side: const BorderSide(color: AppColors.textMuted),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          _th('CREDENTIAL ID', flex: 3),
          _th('HOLDER NAME', flex: 3),
          _th('CREDENTIAL TYPE', flex: 4),
          _th('ISSUED BY', flex: 3),
          _th('ISSUE DATE', flex: 2),
          _th('EXPIRY DATE', flex: 2),
          _th('STATUS', flex: 2),
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
}

// ─── TABLE ROW ────────────────────────────────────────────────────────────────

class _CredentialRow extends StatefulWidget {
  final CredentialRecord record;
  final bool isSelected;
  final VoidCallback onToggle;

  const _CredentialRow({
    required this.record,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  State<_CredentialRow> createState() => _CredentialRowState();
}

class _CredentialRowState extends State<_CredentialRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: widget.isSelected
              ? AppColors.issuingAccent.withOpacity(0.06)
              : _hovered
              ? AppColors.surfaceHover
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              // Checkbox
              SizedBox(
                width: 32,
                child: Checkbox(
                  value: widget.isSelected,
                  onChanged: (_) => widget.onToggle(),
                  activeColor: AppColors.issuingAccent,
                  side: const BorderSide(color: AppColors.border),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              // Credential ID
              Expanded(
                flex: 3,
                child: Text(
                  r.id,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.issuingLight,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Holder Name
              Expanded(
                flex: 3,
                child: Text(
                  r.holderName,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Credential Type
              Expanded(
                flex: 4,
                child: Text(
                  r.credentialType,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Issued By
              Expanded(
                flex: 3,
                child: Text(
                  r.issuedBy,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Issue Date
              Expanded(
                flex: 2,
                child: Text(
                  r.issueDate,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Expiry Date
              Expanded(
                flex: 2,
                child: Text(
                  r.expiryDate ?? 'No Expiry',
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: r.expiryDate != null
                        ? AppColors.textDim
                        : AppColors.textDim.withOpacity(0.5),
                    fontStyle: r.expiryDate == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Status badge
              Expanded(flex: 2, child: _StatusBadge(status: r.status)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── STATUS BADGE ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final CredentialStatus status;
  const _StatusBadge({required this.status});

  Color get _bg {
    switch (status) {
      case CredentialStatus.valid:
        return AppColors.valid.withOpacity(0.13);
      case CredentialStatus.revoked:
        return AppColors.revoked.withOpacity(0.13);
      case CredentialStatus.suspended:
        return AppColors.suspended.withOpacity(0.13);
      case CredentialStatus.expired:
        return AppColors.expired.withOpacity(0.13);
    }
  }

  Color get _fg {
    switch (status) {
      case CredentialStatus.valid:
        return AppColors.valid;
      case CredentialStatus.revoked:
        return AppColors.revoked;
      case CredentialStatus.suspended:
        return AppColors.suspended;
      case CredentialStatus.expired:
        return AppColors.expired;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _fg.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _fg),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _fg,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PAGINATION BAR
// ═════════════════════════════════════════════════════════════════════════════

class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int rowsPerPage;
  final int totalRows;
  final void Function(int) onPageChanged;
  final void Function(int) onRowsPerPageChanged;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.rowsPerPage,
    required this.totalRows,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
  });

  // Build the list of page numbers to show (with ellipsis gaps).
  List<int?> get _pageNumbers {
    if (totalPages <= 7) return List.generate(totalPages, (i) => i + 1);

    final result = <int?>[];
    result.add(1);

    if (currentPage > 4) result.add(null); // left ellipsis

    final start = (currentPage - 2).clamp(2, totalPages - 1);
    final end = (currentPage + 2).clamp(2, totalPages - 1);
    for (int i = start; i <= end; i++) result.add(i);

    if (currentPage < totalPages - 3) result.add(null); // right ellipsis

    result.add(totalPages);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final start = totalRows == 0 ? 0 : (currentPage - 1) * rowsPerPage + 1;
    final end = (currentPage * rowsPerPage).clamp(0, totalRows);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── Page numbers centred ──────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Prev arrow
            _PageBtn(
              child: const Icon(Icons.chevron_left, size: 16),
              enabled: currentPage > 1,
              onTap: () => onPageChanged(currentPage - 1),
            ),
            const SizedBox(width: 4),

            // Page number chips
            ..._pageNumbers.map((p) {
              if (p == null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    '…',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 12,
                      color: AppColors.textDim,
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _PageBtn(
                  active: p == currentPage,
                  child: Text(
                    '$p',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: p == currentPage
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: p == currentPage
                          ? Colors.white
                          : AppColors.textDim,
                    ),
                  ),
                  onTap: () => onPageChanged(p),
                ),
              );
            }),

            const SizedBox(width: 4),
            // Next arrow
            _PageBtn(
              child: const Icon(Icons.chevron_right, size: 16),
              enabled: currentPage < totalPages,
              onTap: () => onPageChanged(currentPage + 1),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ── Rows info + rows-per-page selector ───────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              totalRows == 0
                  ? 'No results'
                  : 'Showing $start–$end of $totalRows',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                color: AppColors.textDim,
              ),
            ),
            const SizedBox(width: 20),
            Text(
              'Rows per page:',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                color: AppColors.textDim,
              ),
            ),
            const SizedBox(width: 8),
            ...[25, 50, 100].map(
              (n) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _RowsPerPageChip(
                  value: n,
                  selected: n == rowsPerPage,
                  onTap: () => onRowsPerPageChanged(n),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PageBtn extends StatefulWidget {
  final Widget child;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  const _PageBtn({
    required this.child,
    required this.onTap,
    this.active = false,
    this.enabled = true,
  });

  @override
  State<_PageBtn> createState() => _PageBtnState();
}

class _PageBtnState extends State<_PageBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.active;
    final isEnabled = widget.enabled;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: isEnabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.issuingAccent
                : _h && isEnabled
                ? AppColors.surfaceHover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isActive
                ? null
                : Border.all(
                    color: _h && isEnabled
                        ? AppColors.border
                        : Colors.transparent,
                  ),
          ),
          child: Opacity(opacity: isEnabled ? 1.0 : 0.3, child: widget.child),
        ),
      ),
    );
  }
}

class _RowsPerPageChip extends StatefulWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;
  const _RowsPerPageChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_RowsPerPageChip> createState() => _RowsPerPageChipState();
}

class _RowsPerPageChipState extends State<_RowsPerPageChip> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: widget.selected
              ? AppColors.issuingAccent.withOpacity(0.18)
              : _h
              ? AppColors.surfaceHover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: widget.selected
                ? AppColors.issuingAccent.withOpacity(0.5)
                : AppColors.border,
          ),
        ),
        child: Text(
          '${widget.value}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w400,
            color: widget.selected ? AppColors.issuingLight : AppColors.textDim,
          ),
        ),
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// ACTION BAR
// ═════════════════════════════════════════════════════════════════════════════

class _ActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onExport;
  final VoidCallback? onView; // null = disabled

  const _ActionBar({
    required this.selectedCount,
    required this.onExport,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final viewEnabled = onView != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Export button
        _ActionButton(
          icon: Icons.download_rounded,
          label: selectedCount > 0
              ? 'Export Selected ($selectedCount)'
              : 'Export All',
          filled: false,
          onTap: onExport,
        ),
        const SizedBox(width: 10),

        // View button
        _ActionButton(
          icon: Icons.open_in_new_rounded,
          label: 'View Credential',
          filled: true,
          enabled: viewEnabled,
          onTap: onView ?? () {},
          disabledTooltip: selectedCount == 0
              ? 'Select one credential to view'
              : selectedCount > 1
              ? 'Select only one credential to view'
              : null,
        ),

        if (!viewEnabled && selectedCount > 1) ...[
          const SizedBox(width: 10),
          const Icon(Icons.info_outline, size: 12, color: AppColors.textDim),
          const SizedBox(width: 5),
          Text(
            'Select only one credential to use View.',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 11,
              color: AppColors.textDim,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;
  final String? disabledTooltip;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
    this.enabled = true,
    this.disabledTooltip,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled;
    final bg = widget.filled
        ? (active
              ? (_h
                    ? AppColors.issuingAccent.withOpacity(0.82)
                    : AppColors.issuingAccent)
              : AppColors.issuingAccent.withOpacity(0.28))
        : (_h && active ? AppColors.surfaceHover : Colors.transparent);

    final border = widget.filled
        ? Colors.transparent
        : (active ? AppColors.issuingAccent : AppColors.border);

    final fgText = widget.filled
        ? (active ? AppColors.white : AppColors.textMuted)
        : (active ? AppColors.white : AppColors.textDim);

    Widget btn = MouseRegion(
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: active ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.filled
                    ? (active ? AppColors.white : AppColors.textMuted)
                    : (active ? AppColors.issuingAccent : AppColors.textDim),
              ),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fgText,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!active && widget.disabledTooltip != null) {
      btn = Tooltip(message: widget.disabledTooltip!, child: btn);
    }
    return btn;
  }
}

// ─── TOOLBAR ICON BUTTON ──────────────────────────────────────────────────────


