import 'package:flutter/material.dart';
import 'package:qportal_webapp/dialog/export_dialog.dart';
import 'package:qportal_webapp/models/VERIFIER/verificationHistory_model.dart';
import 'package:qportal_webapp/models/VERIFIER/verifyResult_enum.dart';
import 'package:qportal_webapp/services/verifier_api.dart';
import 'package:qportal_webapp/tables/verificationHistory_table.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/components/paginationBar.dart';


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
  bool _isLoading = true;
  bool _hasError = false;

  // ── selection ─────────────────────────────────────────────────────────────
  final Set<String> _selected = {};
  bool _selectAll = false;

  // ── search ────────────────────────────────────────────────────────────────
  String _search = '';
  final _searchCtrl = TextEditingController();

  // ── pagination ────────────────────────────────────────────────────────────
  int _rowsPerPage = 25;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _allRows = [];
    _filtered = [];
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final data = await VerifierApi.getVerificationHistory();
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
                r.verifiedAt.toLowerCase().contains(q) ||
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
      builder: (_) => const ExportDialog(
        title: 'Export Records',
        subtitle: 'Choose a format to export these records.',
        accentColor: AppColors.verifyingAccent,
        formats: [
          'PDF',
          'JSON',
          'XLSX',
        ], // Example: Excludes XLSX for this specific page
      ),
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
            child: HistoryTable(
              isLoading: _isLoading,
              hasError: _hasError,
              onRetry: _loadHistory,
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

