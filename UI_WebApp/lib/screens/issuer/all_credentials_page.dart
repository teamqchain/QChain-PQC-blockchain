import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/models/ISSUER/credentials_model.dart';
import 'package:qportal_webapp/services/issuer_api.dart';

import 'package:qportal_webapp/tables/credential_table.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/paginationBar.dart';

class AllCredentialsPage extends StatefulWidget {
  final void Function(String credentialId)? onViewCredential;
  const AllCredentialsPage({super.key, this.onViewCredential});

  @override
  State<AllCredentialsPage> createState() => _AllCredentialsPageState();
}

class _AllCredentialsPageState extends State<AllCredentialsPage> {
  List<CredentialRecord> _allRows = [];
  List<CredentialRecord> _filtered = [];
  bool _isLoading = true;
  bool _hasError = false;

  final Set<String> _selected = {};
  bool _selectAll = false;

  String _search = '';
  final _searchCtrl = TextEditingController();

  int _rowsPerPage = 25;
  int _currentPage = 1;

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
      final data = await IssuerApi.getAllCredentials();
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

    final maxPage = (_filtered.length / _rowsPerPage).ceil().clamp(1, 99999);
    if (_currentPage > maxPage) _currentPage = maxPage;

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
          Text(
            'All Credentials',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          Expanded(
            child: CredentialTable(
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

          _ActionBar(
            selectedCount: _selectedCount,
            onExport: () {}, 
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


class _ActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onExport;
  final VoidCallback? onView; 

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
        AppButton(
          icon: Icons.download_rounded,
          label: selectedCount > 0
              ? 'Export Selected ($selectedCount)'
              : 'Export All',
          onTap: onExport,
          fontWeight: FontWeight.w600,
          backgroundColor: Colors.transparent,
          hoverColor: AppColors.surfaceHover,
          showBorder: true,
          borderColor: AppColors.issuingAccent,
          disabledBorderColor: AppColors.border,
          textColor: AppColors.white,
          disabledTextColor: AppColors.textDim,
          iconColor: AppColors.issuingAccent,
          disabledIconColor: AppColors.textDim,
        ),
        const SizedBox(width: 10),

        AppButton(
          icon: Icons.open_in_new_rounded,
          label: 'View Credential',
          enabled: viewEnabled,
          onTap: onView ?? () {},
          fontWeight: FontWeight.w600,
          backgroundColor: AppColors.issuingAccent,
          hoverColor: AppColors.issuingAccent.withOpacity(0.82),
          disabledBackgroundColor: AppColors.issuingAccent.withOpacity(0.28),
          showBorder: false,
          textColor: AppColors.white,
          disabledTextColor: AppColors.textMuted,
          iconColor: AppColors.white,
          disabledIconColor: AppColors.textMuted,
          tooltip: selectedCount == 0
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
