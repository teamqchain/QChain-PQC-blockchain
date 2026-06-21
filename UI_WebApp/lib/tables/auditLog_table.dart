import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/statusBadge.dart';
import 'package:qportal_webapp/components/tableHeader.dart';
import 'package:qportal_webapp/models/IT_ADMIN/audit_model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/buildRow_widget.dart';
import 'package:qportal_webapp/widgets/buildToolBar_widget.dart';
// ═════════════════════════════════════════════════════════════════════════════
//  AUDIT LOG TABLE
// ═════════════════════════════════════════════════════════════════════════════

class AuditLogTable extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final List<LiveAuditLogRecord> rows;
  final int totalFiltered;
  final String search;
  final TextEditingController searchCtrl;
  final void Function(String) onSearchChanged;
  final VoidCallback onClearSearch;

  const AuditLogTable({
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.rows,
    required this.totalFiltered,
    required this.search,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          BuildToolBar(
            selected: const {}, // Audit logs don't have row selection
            totalFiltered: totalFiltered,
            searchCtrl: searchCtrl,
            search: search,
            onSearchChanged: onSearchChanged,
            onClearSearch: onClearSearch,
            searchLabel: 'Search audit logs...',
            trueMessage: 'entry',
            falseMessage: 'entry',
            falsePluralMessage: "entries",
            searchColor: AppColors.adminAccent,
            backgroundColor: AppColors.adminAccent.withOpacity(0.10),
            borderColor: AppColors.adminAccent.withOpacity(0.25),
            textColor: AppColors.adminAccent,
          ),
          Container(height: 1, color: AppColors.border),
          _buildHeader(),
          Container(height: 1, color: AppColors.border),
          Expanded(
            child: BuildrowWidget<LiveAuditLogRecord>(
              errorMessage: errorMessage,
              isLoading: isLoading,
              items: rows,
              query: search,
              onRetry: onRetry,
              emptyDefaultMessage: 'No audit log entries found.',
              emptySearchMessage: 'No results for "{query}".',
              emptyDefaultIcon: Icons.history_outlined,
              emptySearchIcon: Icons.search_off_rounded,
              accentColor: AppColors.adminAccent,
              itemBuilder: (context, record) => _AuditRow(record: record),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.adminAccent.withOpacity(0.16),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 17),
          ColHead('LOG ID', flex: 2),
          ColHead('ACTION', flex: 2),
          ColHead('DETAILS', flex: 6),
          ColHead('PERFORMED BY', flex: 3),
          ColHead('IP ADDRESS', flex: 2),
          ColHead('TIMESTAMP', flex: 3),
        ],
      ),
    );
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
        // Synchronized padding with _buildHeader outer padding
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 3,
              height: 36,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── LOG ID
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  r.id,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.adminAccent
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
                padding: const EdgeInsets.only(right: 29),
                child: StatusBadge(
                  label: r.action.label,
                  fg: colour,
                  iconPresent: false,
                ),
              ),
            ),

            // ── DETAILS
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  r.details,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ),

            // ── PERFORMED BY
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
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
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  r.ipAddress,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
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
          ],
        ),
      ),
    );
  }
}
