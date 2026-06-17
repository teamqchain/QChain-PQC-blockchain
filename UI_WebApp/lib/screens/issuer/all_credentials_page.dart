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
import 'package:qportal_webapp/components/connection_error.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/screens/issuer/suspend_revoke_page.dart';
import 'package:qportal_webapp/services/api_service.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/countChip.dart';
import 'package:qportal_webapp/widgets/paginationBar.dart';
import 'package:qportal_webapp/widgets/statusBadge.dart';

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
  bool _hasError = false;

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
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final data = await ApiService.getAllCredentials();
      if (!mounted) return;
      setState(() {
        _allRows = data;
        _applyFilter();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
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
              hasError: _hasError,
              onRetry: _loadCredentials,
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
          PaginationBar(
            currentPage: _currentPage,
            totalPages: _totalPages,
            rowsPerPage: _rowsPerPage,
            totalRows: _filtered.length,
            onPageChanged: _goToPage,
            onRowsPerPageChanged: _changeRowsPerPage,
            accentColor: AppColors.issuingAccent,
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
  final bool hasError;
  final VoidCallback onRetry;
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
    required this.hasError,
    required this.onRetry,
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
            child: hasError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80.0),
                      child: ConnectionErrorWidget(onRetry: onRetry),
                    ),
                  )
                : isLoading
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                ? const Center(
                    child: Text(
                      'No credentials match your search.',
                      style: TextStyle(color: AppColors.textDim, fontSize: 12),
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
          CountChip(
            count: (selCount > 0) ? selCount : totalFiltered,
            label: (selCount > 0) ? 'selected' : 'credential',
            pluralLabel: (selCount > 1) ? 'selected' : 'credential',
          ),
          const Spacer(),

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
                  formatDateString(r.issueDate),
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
                  formatDateString(r.expiryDate ?? 'No Expiry'),
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
              Expanded(flex: 2, child: StatusBadge(fg: r.status.fg, label: r.status.label)),
            ],
          ),
        ),
      ),
    );
  }
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
