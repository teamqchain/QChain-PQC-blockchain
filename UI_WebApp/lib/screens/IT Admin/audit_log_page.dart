import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/statusBadge.dart';
import 'package:qportal_webapp/dialog/export_dialog.dart';
import 'package:qportal_webapp/models/IT_ADMIN/audit_model.dart';
import 'package:qportal_webapp/services/admin_api.dart';
import 'package:qportal_webapp/tables/auditLog_table.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/components/paginationBar.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class AuditLogPage extends StatefulWidget {
  final VoidCallback onBack;

  const AuditLogPage({super.key, required this.onBack});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  // ── LIVE STATE ─────────────────────────────────────────────────────────────
  List<LiveAuditLogRecord> _allRows = [];
  List<LiveAuditLogRecord> _filtered = [];
  bool _isLoading = true;
  String? _errorMessage;

  // ── SEARCH ─────────────────────────────────────────────────────────────────
  String _query = '';
  final _searchCtrl = TextEditingController();

  // ── PAGINATION ─────────────────────────────────────────────────────────────
  int _rowsPerPage = 25;
  int _currentPage = 1;

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
      final records = await AdminApi.getAuditLogs(limit: 500);
      if (mounted) {
        setState(() {
          _allRows = records;
          _isLoading = false;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _allRows = [];
          _errorMessage = 'error';
        });
      }
    }
  }

  void _applyFilter() {
    final q = _query.toLowerCase().trim();
    _filtered = q.isEmpty
        ? List.from(_allRows)
        : _allRows.where((r) {
            return r.id.toLowerCase().contains(q) ||
                r.action.label.toLowerCase().contains(q) ||
                r.details.toLowerCase().contains(q) ||
                r.performedBy.toLowerCase().contains(q) ||
                r.performedByRole.toLowerCase().contains(q) ||
                r.ipAddress.toLowerCase().contains(q) ||
                r.timestamp.toLowerCase().contains(q);
          }).toList();

    final maxPage = (_filtered.length / _rowsPerPage).ceil().clamp(1, 99999);
    if (_currentPage > maxPage) _currentPage = maxPage;
  }

  List<LiveAuditLogRecord> get _pageRows {
    if (_filtered.isEmpty) return [];
    final start = (_currentPage - 1) * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  int get _totalPages {
    if (_rowsPerPage <= 0 || _filtered.isEmpty) return 1;
    return (_filtered.length / _rowsPerPage).ceil().clamp(1, 99999);
  }

  // ── EXPORT DIALOG ─────────────────────────────────────────────────────────
  void _onExport() {
    showDialog(
      context: context,
      builder: (_) => const ExportDialog(
        title: 'Export Audit Log',
        subtitle: 'Select a format to download the log.',
        accentColor: AppColors.adminAccent,
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ────────────────────────────────────────────────────────
          Row(
            children: [
              Text(
                'Audit Log',
                style: AppTextStyles.navLabelActive.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(
                fg: AppColors.adminAccent,
                label: "Append-only · Read-only",
                iconPresent: true,
                icon: Icons.lock_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: AuditLogTable(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              onRetry: _fetchData,
              rows: _pageRows,
              totalFiltered: _filtered.length,
              search: _query,
              searchCtrl: _searchCtrl,
              onSearchChanged: (v) => setState(() {
                _query = v;
                _currentPage = 1;
                _applyFilter();
              }),
              onClearSearch: () {
                _searchCtrl.clear();
                setState(() {
                  _query = '';
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
            onPageChanged: (p) => setState(() => _currentPage = p),
            onRowsPerPageChanged: (rpp) => setState(() {
              _rowsPerPage = rpp;
              _currentPage = 1;
              _applyFilter();
            }),
            accentColor: AppColors.adminAccent,
          ),
          const SizedBox(height: 14),

          // ── Action bar ───────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppButton(
                icon: Icons.arrow_back_rounded,
                label: 'Back',
                showBorder: true,
                borderColor: AppColors.border,
                hoverColor: AppColors.surfaceHover,
                onTap: widget.onBack,
              ),
              const SizedBox(width: 10),
              AppButton(
                icon: Icons.download_rounded,
                label: 'Export',
                backgroundColor: AppColors.adminAccent,
                hoverColor: AppColors.adminAccent.withOpacity(0.82),
                onTap: _onExport,
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
}
