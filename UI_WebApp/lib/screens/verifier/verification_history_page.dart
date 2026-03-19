// screens/verifier/verification_history_page.dart
//
// Verification History — paginated table of every credential verification event.
//
// Structure mirrors all_credentials_page.dart exactly:
//   • Title
//   • Expanded table container (toolbar → header → rows)
//   • Pagination bar
//   • Action bar (Export / View Verification)
//
// Only changes vs all_credentials_page.dart:
//   • verifyingAccent replaces issuingAccent throughout
//   • Different columns (Date & Time, Credential Type, Holder Name,
//     Issuer Name, Result, Method, Verified By)
//   • Export button opens a format-picker dialog (Excel / PDF / JSON)
//   • Button labels renamed to "Export" and "View Verification"
//
// ── Integration ──────────────────────────────────────────────────────────────
//   case RouteName.verificationHistory:
//     return VerificationHistoryPage(
//       onViewVerification: (id) => _handleNavigate(
//         RouteName.verificationDetail, arg: id,
//       ),
//     );

import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/filterButton.dart';
import 'package:qportal_webapp/components/searchBar.dart';
import 'package:qportal_webapp/models/verifiying_models.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/app_button.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class VerificationHistoryPage extends StatefulWidget {
  final void Function(String recordId)? onViewVerification;

  const VerificationHistoryPage({super.key, this.onViewVerification});

  @override
  State<VerificationHistoryPage> createState() =>
      _VerificationHistoryPageState();
}

class _VerificationHistoryPageState extends State<VerificationHistoryPage> {
  // ── data ──────────────────────────────────────────────────────────────────
  late List<VerificationHistoryRecord> _allRows;
  late List<VerificationHistoryRecord> _filtered;

  // ── selection ─────────────────────────────────────────────────────────────
  final Set<String> _selected = {};
  bool _selectAll = false;

  // ── search ────────────────────────────────────────────────────────────────
  String _search = '';
  final _searchCtrl = TextEditingController();

  // ── pagination ────────────────────────────────────────────────────────────
  int _rowsPerPage = 25;
  int _currentPage = 1;

  // ─── helpers ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _allRows = List.from(kMockVerificationHistory);
    _applyFilter();
  }

  void _applyFilter() {
    final q = _search.toLowerCase().trim();
    _filtered = q.isEmpty
      ? List.from(_allRows)
      : _allRows.where((r) {
        return r.id.toLowerCase().contains(q) ||
          r.date.toLowerCase().contains(q) ||
          r.time.toLowerCase().contains(q) ||
          r.holderName.toLowerCase().contains(q) ||
          r.credentialType.toLowerCase().contains(q) ||
          r.issuerName.toLowerCase().contains(q) ||
          r.verifiedBy.toLowerCase().contains(q) ||
          r.result.label.toLowerCase().contains(q) ||
          r.method.label.toLowerCase().contains(q);
        }).toList();

    final maxPage = (_filtered.length / _rowsPerPage).ceil().clamp(1, 99999);
    if (_currentPage > maxPage) _currentPage = maxPage;

    final pageIds = _pageRows.map((r) => r.id).toSet();
    _selectAll =
        pageIds.isNotEmpty && pageIds.every((id) => _selected.contains(id));
  }

  List<VerificationHistoryRecord> get _pageRows {
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
      final pageIds = _pageRows.map((r) => r.id).toSet();
      _selectAll = pageIds.every((id) => _selected.contains(id));
    });
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (_) => _ExportDialog(selectedCount: _selectedCount),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ────────────────────────────────────────────────────────
          Text(
            'Verification History',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // ── Table container ──────────────────────────────────────────────
          Expanded(
            child: _HistoryTable(
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

          // ── Pagination ───────────────────────────────────────────────────
          _PaginationBar(
            currentPage: _currentPage,
            totalPages: _totalPages,
            rowsPerPage: _rowsPerPage,
            totalRows: _filtered.length,
            onPageChanged: _goToPage,
            onRowsPerPageChanged: _changeRowsPerPage,
          ),
          const SizedBox(height: 14),

          // ── Action buttons ───────────────────────────────────────────────
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    final viewEnabled = _selectedCount == 1;
    final multiSelect = _selectedCount > 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Export button — always enabled, opens format dialog
        AppButton(
          icon: Icons.download_rounded,
          label: _selectedCount > 0
              ? 'Export Selected ($_selectedCount)'
              : 'Export All',
          showBorder: true,
          borderColor: AppColors.verifyingAccent,
          textColor: AppColors.verifyingAccent,
          iconColor: AppColors.verifyingAccent,
          hoverColor: AppColors.verifyingAccent.withOpacity(0.08),
          onTap: _showExportDialog,
        ),
        const SizedBox(width: 10),

        // View Verification button — enabled only when exactly 1 row selected
        AppButton(
          icon: Icons.open_in_new_rounded,
          label: 'View Verification',
          backgroundColor: AppColors.verifyingAccent,
          hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
          disabledBackgroundColor: AppColors.verifyingAccent.withOpacity(0.28),
          enabled: viewEnabled,
          tooltip: _selectedCount == 0
              ? 'Select one record to view'
              : multiSelect
              ? 'Select only one record to view'
              : null,
          onTap: () => widget.onViewVerification?.call(_selected.first),
        ),

        // Inline hint when > 1 selected
        if (multiSelect) ...[
          const SizedBox(width: 10),
          const Icon(Icons.info_outline, size: 12, color: AppColors.textDim),
          const SizedBox(width: 5),
          Text(
            'Select only one record to use View Verification.',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 11,
              color: AppColors.textDim,
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
// TABLE WIDGET
// ═════════════════════════════════════════════════════════════════════════════

class _HistoryTable extends StatelessWidget {
  final List<VerificationHistoryRecord> rows;
  final Set<String> selected;
  final bool selectAll;
  final int totalFiltered;
  final void Function(String) onToggleRow;
  final void Function(bool?) onToggleAll;
  final String search;
  final TextEditingController searchCtrl;
  final void Function(String) onSearchChanged;
  final VoidCallback onClearSearch;

  const _HistoryTable({
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
          _buildToolbar(),
          Container(height: 1, color: AppColors.border),
          _buildHeader(),
          Container(height: 1, color: AppColors.border),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'No records match your search.',
                      style: TextStyle(color: AppColors.textDim, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        Container(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) => _HistoryRow(
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
          // Count / selection label
          Expanded(
            child: Text(
              selCount > 0
                  ? '$selCount of $totalFiltered selected'
                  : '$totalFiltered records',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selCount > 0 ? AppColors.verifyingAccent : Colors.white,
              ),
            ),
          ),

          // Filter icon button
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
            barWidth: 260,
            searchLabel: 'Search by holder, type, result, staff…',
            activeColor: AppColors.verifyingAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.verifyingAccent.withOpacity(0.16),
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
              activeColor: AppColors.verifyingAccent,
              side: const BorderSide(color: AppColors.textMuted),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          _th('DATE', flex: 2),
          const SizedBox(width: 12),
          _th('TIME', flex: 1),
          const SizedBox(width: 12),
          _th('CREDENTIAL TYPE', flex: 3),
          const SizedBox(width: 12),
          _th('HOLDER NAME', flex: 3),
          const SizedBox(width: 12),
          _th('ISSUER', flex: 3),
          // const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              'RESULT',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(width: 60),
          _th('METHOD', flex: 2),
          const SizedBox(width: 12),
          _th('VERIFIED BY', flex: 2),
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

class _HistoryRow extends StatefulWidget {
  final VerificationHistoryRecord record;
  final bool isSelected;
  final VoidCallback onToggle;

  const _HistoryRow({
    required this.record,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
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
              ? AppColors.verifyingAccent.withOpacity(0.07)
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
                  activeColor: AppColors.verifyingAccent,
                  side: const BorderSide(color: AppColors.border),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              // Date
              Expanded(
                flex: 2,
                child: Text(
                  r.date,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),

              // Time
              Expanded(
                flex: 1,
                child: Text(
                  r.time,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),

              // Credential Type
              Expanded(
                flex: 3,
                child: Text(
                  r.credentialType,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),

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
              const SizedBox(width: 12),

              // Issuer Name
              Expanded(
                flex: 3,
                child: Text(
                  r.issuerName,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // const SizedBox(width: 100),

              // Result badge
              SizedBox(width: 100, child: _ResultBadge(result: r.result)),
              const SizedBox(width: 60),

              // Method chip
              Expanded(flex: 2, child: _MethodChip(method: r.method)),
              const SizedBox(width: 12),

              // Verified By
              Expanded(
                flex: 2,
                child: Text(
                  r.verifiedBy,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── RESULT BADGE ─────────────────────────────────────────────────────────────

class _ResultBadge extends StatelessWidget {
  final VerifyResult result;
  const _ResultBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    final fg = result.fg;
    return Container(
      // width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: fg.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
          ),
          const SizedBox(width: 5),
          Center(
            child: Text(
              result.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── METHOD CHIP ──────────────────────────────────────────────────────────────

class _MethodChip extends StatelessWidget {
  final VerifyMethod method;
  const _MethodChip({required this.method});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(method.icon, size: 12, color: AppColors.textDim),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            method.label,
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 10,
              color: AppColors.textDim,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EXPORT DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _ExportDialog extends StatefulWidget {
  final int selectedCount;
  const _ExportDialog({required this.selectedCount});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  String _format = 'Excel';

  static const _kFormats = [
    (
      value: 'Excel',
      icon: Icons.table_chart_outlined,
      description: 'Spreadsheet — best for data analysis',
      color: AppColors.verifyingAccent,
    ),
    (
      value: 'PDF',
      icon: Icons.picture_as_pdf_outlined,
      description: 'Formal compliance report',
      color: AppColors.verifyingAccent,
    ),
    (
      value: 'JSON',
      icon: Icons.code_rounded,
      description: 'Developer integration & API use',
      color: AppColors.verifyingAccent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
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
                      color: AppColors.verifyingAccent.withOpacity(0.14),
                      border: Border.all(
                        color: AppColors.verifyingAccent.withOpacity(0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      size: 17,
                      color: AppColors.verifyingAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Records',
                          style: AppTextStyles.navLabelActive.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.selectedCount > 0
                              ? 'Exporting ${widget.selectedCount} selected '
                                    'record${widget.selectedCount > 1 ? 's' : ''}'
                              : 'Exporting all records',
                          style: AppTextStyles.bodyTiny.copyWith(
                            fontSize: 11,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Format options ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELECT FORMAT',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: AppColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._kFormats.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FormatOption(
                        value: f.value,
                        icon: f.icon,
                        description: f.description,
                        color: f.color,
                        selected: _format == f.value,
                        onTap: () => setState(() => _format = f.value),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Buttons ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                      icon: Icons.download_rounded,
                      label: 'Export as $_format',
                      backgroundColor: AppColors.verifyingAccent,
                      hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
                      onTap: () => Navigator.pop(context),
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

// ─── FORMAT OPTION ROW (inside dialog) ────────────────────────────────────────

class _FormatOption extends StatefulWidget {
  final String value;
  final IconData icon;
  final String description;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FormatOption({
    required this.value,
    required this.icon,
    required this.description,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FormatOption> createState() => _FormatOptionState();
}

class _FormatOptionState extends State<_FormatOption> {
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: widget.selected
              ? widget.color.withOpacity(0.09)
              : _h
              ? AppColors.surfaceHover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.selected
                ? widget.color.withOpacity(0.4)
                : AppColors.border,
            width: widget.selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon box
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(widget.selected ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(widget.icon, size: 17, color: widget.color),
            ),
            const SizedBox(width: 12),
            // Label + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: widget.selected ? widget.color : AppColors.text,
                    ),
                  ),
                  Text(
                    widget.description,
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 11,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            // Check icon when selected
            if (widget.selected)
              Icon(Icons.check_circle_rounded, size: 18, color: widget.color),
          ],
        ),
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// PAGINATION BAR  (identical logic to all_credentials_page.dart;
//                  only accent colour swapped to verifyingAccent)
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

  List<int?> get _pageNumbers {
    if (totalPages <= 7) return List.generate(totalPages, (i) => i + 1);
    final result = <int?>[];
    result.add(1);
    if (currentPage > 4) result.add(null);
    final start = (currentPage - 2).clamp(2, totalPages - 1);
    final end = (currentPage + 2).clamp(2, totalPages - 1);
    for (int i = start; i <= end; i++) result.add(i);
    if (currentPage < totalPages - 3) result.add(null);
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
        // ── Page number buttons ──────────────────────────────────────────
        Row(
          children: [
            _PageBtn(
              child: const Icon(Icons.chevron_left, size: 16),
              enabled: currentPage > 1,
              onTap: () => onPageChanged(currentPage - 1),
            ),
            const SizedBox(width: 4),
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
                  onTap: () => onPageChanged(p),
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
                ),
              );
            }),
            const SizedBox(width: 4),
            _PageBtn(
              child: const Icon(Icons.chevron_right, size: 16),
              enabled: currentPage < totalPages,
              onTap: () => onPageChanged(currentPage + 1),
            ),
          ],
        ),
        const SizedBox(width: 20),

        // ── Row info + rows-per-page selector ────────────────────────────
        Row(
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

// ─── PAGE BUTTON ──────────────────────────────────────────────────────────────

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
                ? AppColors.verifyingAccent
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

// ─── ROWS-PER-PAGE CHIP ───────────────────────────────────────────────────────

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
              ? AppColors.verifyingAccent.withOpacity(0.18)
              : _h
              ? AppColors.surfaceHover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: widget.selected
                ? AppColors.verifyingAccent.withOpacity(0.5)
                : AppColors.border,
          ),
        ),
        child: Text(
          '${widget.value}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w400,
            color: widget.selected
                ? AppColors.verifyingLight
                : AppColors.textDim,
          ),
        ),
      ),
    ),
  );
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
