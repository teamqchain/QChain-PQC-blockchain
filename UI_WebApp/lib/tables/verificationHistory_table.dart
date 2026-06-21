import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/statusBadge.dart';
import 'package:qportal_webapp/components/tableHeader.dart';
import 'package:qportal_webapp/models/VERIFIER/verificationHistory_model.dart';
import 'package:qportal_webapp/models/VERIFIER/verifyResult_enum.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/utils/dateFormatter.dart';
import 'package:qportal_webapp/widgets/buildRow_widget.dart';
import 'package:qportal_webapp/widgets/buildToolBar_widget.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TABLE WIDGET
// ═════════════════════════════════════════════════════════════════════════════

class HistoryTable extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;
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

  const HistoryTable({
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
          BuildToolBar(
            selected: selected,
            totalFiltered: totalFiltered,
            searchCtrl: searchCtrl,
            search: search,
            onSearchChanged: onSearchChanged,
            onClearSearch: onClearSearch,
            searchLabel: 'Search by holder, type, result, staff…',
            trueMessage: 'selected',
            falseMessage: 'record',
            falsePluralMessage: 'records',
            searchColor: AppColors.verifyingAccent,
            backgroundColor: AppColors.verifyingAccent.withOpacity(0.1),
            borderColor: AppColors.verifyingAccent.withOpacity(0.25),
            textColor: AppColors.verifyingAccent,
          ),
          Container(height: 1, color: AppColors.border),
          _buildHeader(),
          Container(height: 1, color: AppColors.border),
          Expanded(
            child: BuildrowWidget<VerificationHistoryRecord>(
              errorMessage: hasError ? 'error' : null,
              isLoading: isLoading,
              items: rows,
              query: search,
              onRetry: onRetry,
              emptyDefaultMessage: 'No verification history found.',
              emptySearchMessage: 'No records match "{query}".',
              emptyDefaultIcon: Icons.history_outlined,
              emptySearchIcon: Icons.search_off_rounded,
              accentColor: AppColors.verifyingAccent,
              itemBuilder: (context, record) => _HistoryRow(
                record: record,
                isSelected: selected.contains(record.id),
                onToggle: () => onToggleRow(record.id),
              ),
            ),
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
          ColHead('DATE & TIME', flex: 2),
          const SizedBox(width: 12),
          ColHead('CREDENTIAL ID', flex: 2),
          const SizedBox(width: 12),
          ColHead('HOLDER NAME', flex: 3),
          const SizedBox(width: 12),
          ColHead('ISSUER', flex: 3),
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
          ColHead('METHOD', flex: 2),
          const SizedBox(width: 12),
          ColHead('VERIFIED BY', flex: 2),
        ],
      ),
    );
  }
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

              // Date and Time
              Expanded(
                flex: 2,
                child: Text(
                  DateFormatter.formatIsoDateAndTime(r.verifiedAt),
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),

              // Credential ID
              Expanded(
                flex: 2,
                child: Text(
                  r.credID,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.verifyingAccent,
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
                  maxLines: 2,
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
              SizedBox(
                width: 100,
                child: StatusBadge(fg: r.result.fg, label: r.result.label, iconPresent: false,),
              ),
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
