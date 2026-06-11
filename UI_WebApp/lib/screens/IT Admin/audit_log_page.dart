// screens/audit_log_page.dart

import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/filterButton.dart';
import 'package:qportal_webapp/services/api_service.dart';
import 'package:qportal_webapp/components/searchBar.dart';
import 'package:qportal_webapp/components/connection_error.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/components/countChip.dart';

// ─── ACTION EXTENSION (Maps API Enums to UI Colors) ─────────────────────────

extension LiveAuditActionX on LiveAuditAction {
  String get label {
    switch (this) {
      case LiveAuditAction.issued:
        return 'Issued';
      case LiveAuditAction.revoked:
        return 'Revoked';
      case LiveAuditAction.suspended:
        return 'Suspended';
      case LiveAuditAction.verified:
        return 'Verified';
      case LiveAuditAction.policy:
        return 'Policy Change';
      case LiveAuditAction.system:
        return 'System Config';
      case LiveAuditAction.error:
        return 'Error';
    }
  }

  Color get colour {
    switch (this) {
      case LiveAuditAction.issued:
        return AppColors.valid;
      case LiveAuditAction.revoked:
        return AppColors.revoked;
      case LiveAuditAction.suspended:
        return AppColors.suspended;
      case LiveAuditAction.verified:
        return AppColors.verifyingLight;
      case LiveAuditAction.policy:
        return const Color(0xFFF97316);
      case LiveAuditAction.system:
        return const Color(0xFF60A5FA);
      case LiveAuditAction.error:
        return AppColors.revoked;
    }
  }
}

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
      // Fetch an initial large batch, similar to subscription page architecture.
      final records = await ApiService.getAuditLogs(limit: 500);
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
          _errorMessage = 'error'; // triggers the connection error state
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
// ── export dialog ─────────────────────────────────────────────────────────
  void _onExport() {
    showDialog(context: context, builder: (_) => const _ExportDialog());
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.adminAccent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.adminAccent.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 11,
                      color: AppColors.adminLight,
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Append-only · Read-only',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.adminLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          _PaginationBar(
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

  // ── TOOLBAR ───────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF161616),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
            // Count chip
          CountChip(
            count: _filtered.length,
            label: 'entry',
            pluralLabel: 'entries',
            backgroundColor: AppColors.adminAccent.withOpacity(0.10),
            borderColor: AppColors.adminAccent.withOpacity(0.25),
            textColor: AppColors.adminLight,
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
            barWidth: 280,
            searchLabel: 'Search ID, actions, details, staff…',
            activeColor: AppColors.adminAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.adminAccent.withOpacity(0.16),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          const SizedBox(width: 12),
          _th('LOG ID', flex: 2),
          _th('ACTION', flex: 2),
          _th('DETAILS', flex: 6),
          _th('PERFORMED BY', flex: 3),
          _th('IP ADDRESS', flex: 2),
          _th('TIMESTAMP', flex: 3),
        ],
      ),
    );
  }

  Widget _th(String label, {required int flex}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        label,
        style: AppTextStyles.bodyTiny.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: AppColors.white,
        ),
      ),
    ),
  );

  Widget _buildList() {
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
              _query.isEmpty
                  ? Icons.history_outlined
                  : Icons.search_off_rounded,
              size: 36,
              color: AppColors.textDim,
            ),
            const SizedBox(height: 12),
            Text(
              _query.isEmpty
                  ? 'No audit log entries found.'
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _pageRows.length,
      separatorBuilder: (_, __) =>
          Container(height: 1, color: AppColors.border),
      itemBuilder: (_, i) => _AuditRow(record: _pageRows[i]),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  AUDIT ROW
// ═════════════════════════════════════════════════════════════════════════════

class _AuditRow extends StatefulWidget {
  final LiveAuditLogRecord record;
  const _AuditRow({required this.record});

  @override
  State<_AuditRow> createState() => _AuditRowState();
}

class _AuditRowState extends State<_AuditRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final colour = r.action.colour;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? AppColors.surfaceHover : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 12),

            // ── LOG ID
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  r.id,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDim,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),

            // ── ACTION
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _ActionBadge(label: r.action.label, colour: colour),
              ),
            ),

            // ── DETAILS
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  r.details,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),

            // ── PERFORMED BY
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.performedBy,
                      style: AppTextStyles.bodyTiny.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.performedByRole,
                      style: AppTextStyles.bodyTiny.copyWith(
                        fontSize: 9,
                        color: AppColors.textDim,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),

            // ── IP ADDRESS
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  r.ipAddress,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),

            // ── TIMESTAMP
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  r.timestamp,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ACTION BADGE ─────────────────────────────────────────────────────────────

class _ActionBadge extends StatelessWidget {
  final String label;
  final Color colour;
  const _ActionBadge({required this.label, required this.colour});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: colour.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: colour),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colour,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  EXPORT DIALOG & FORMAT CHIPS (Unchanged functionality)
// ═════════════════════════════════════════════════════════════════════════════

class _ExportDialog extends StatefulWidget {
  const _ExportDialog();

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  String _selected = 'XLSX';
  static const _formats = ['XLSX', 'PDF', 'JSON'];

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
                      color: AppColors.adminAccent.withOpacity(0.14),
                      border: Border.all(
                        color: AppColors.adminAccent.withOpacity(0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      size: 17,
                      color: AppColors.adminLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export Audit Log',
                        style: AppTextStyles.navLabelActive.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Select a format to download the log.',
                        style: AppTextStyles.bodyTiny.copyWith(
                          fontSize: 11,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Format options ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: _formats
                    .map(
                      (fmt) => _FormatOption(
                        label: fmt,
                        selected: _selected == fmt,
                        icon: _fmtIcon(fmt),
                        subtitle: _fmtSubtitle(fmt),
                        onTap: () => setState(() => _selected = fmt),
                      ),
                    )
                    .toList(),
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
                      icon: Icons.download_rounded,
                      label: 'Export as $_selected',
                      backgroundColor: AppColors.adminAccent,
                      hoverColor: AppColors.adminAccent.withOpacity(0.82),
                      onTap: () {
                        Navigator.pop(context);
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

  IconData _fmtIcon(String fmt) {
    switch (fmt) {
      case 'PDF':
        return Icons.picture_as_pdf_outlined;
      case 'JSON':
        return Icons.data_object_rounded;
      default:
        return Icons.table_chart_outlined;
    }
  }

  String _fmtSubtitle(String fmt) {
    switch (fmt) {
      case 'PDF':
        return 'Formatted report — ideal for printing';
      case 'JSON':
        return 'Machine-readable — ideal for integrations';
      default:
        return 'Spreadsheet — ideal for analysis';
    }
  }
}

// ─── FORMAT OPTION ROW ────────────────────────────────────────────────────────

class _FormatOption extends StatefulWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FormatOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FormatOption> createState() => _FormatOptionState();
}

class _FormatOptionState extends State<_FormatOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.adminAccent.withOpacity(0.08)
                : _hovered
                ? AppColors.surfaceHover
                : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected
                  ? AppColors.adminAccent.withOpacity(0.4)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.selected
                    ? AppColors.adminLight
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: widget.selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: widget.selected
                            ? AppColors.text
                            : AppColors.textMuted,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.selected
                      ? AppColors.adminAccent
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.selected
                        ? AppColors.adminAccent
                        : AppColors.textMuted,
                    width: 1.5,
                  ),
                ),
                child: widget.selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 11,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PAGINATION BAR
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

  List<int?> get _pages {
    if (totalPages <= 7) return List.generate(totalPages, (i) => i + 1);
    final result = <int?>[];
    result.add(1);
    if (currentPage > 4) result.add(null);
    final start = (currentPage - 2).clamp(2, totalPages - 1);
    final end = (currentPage + 2).clamp(2, totalPages - 1);
    for (int i = start; i <= end; i++) {
      result.add(i);
    }
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
        // Page buttons
        Row(
          children: [
            _PageBtn(
              enabled: currentPage > 1,
              onTap: () => onPageChanged(currentPage - 1),
              child: const Icon(Icons.chevron_left, size: 16),
            ),
            const SizedBox(width: 4),
            ..._pages.map((p) {
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
              enabled: currentPage < totalPages,
              onTap: () => onPageChanged(currentPage + 1),
              child: const Icon(Icons.chevron_right, size: 16),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Text(
          totalRows == 0 ? 'No results' : 'Showing $start–$end of $totalRows',
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
            child: _RowsChip(
              value: n,
              selected: n == rowsPerPage,
              onTap: () => onRowsPerPageChanged(n),
            ),
          ),
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
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.enabled
        ? SystemMouseCursors.click
        : SystemMouseCursors.basic,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.active
              ? AppColors.adminAccent
              : _h && widget.enabled
              ? AppColors.surfaceHover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: widget.active
              ? null
              : Border.all(
                  color: _h && widget.enabled
                      ? AppColors.border
                      : Colors.transparent,
                ),
        ),
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.3,
          child: widget.child,
        ),
      ),
    ),
  );
}

class _RowsChip extends StatefulWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;
  const _RowsChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });
  @override
  State<_RowsChip> createState() => _RowsChipState();
}

class _RowsChipState extends State<_RowsChip> {
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
              ? AppColors.adminAccent.withOpacity(0.18)
              : _h
              ? AppColors.surfaceHover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: widget.selected
                ? AppColors.adminAccent.withOpacity(0.5)
                : AppColors.border,
          ),
        ),
        child: Text(
          '${widget.value}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w400,
            color: widget.selected ? AppColors.adminLight : AppColors.textDim,
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
