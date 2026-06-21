import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/statusBadge.dart';
import 'package:qportal_webapp/components/tableHeader.dart';
import 'package:qportal_webapp/models/ISSUER/credentials_model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/utils/dateFormatter.dart';
import 'package:qportal_webapp/widgets/buildRow_widget.dart';
import 'package:qportal_webapp/widgets/buildToolBar_widget.dart';
// ═════════════════════════════════════════════════════════════════════════════
// TABLE
// ═════════════════════════════════════════════════════════════════════════════

class CredentialTable extends StatelessWidget {
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

  const CredentialTable({super.key, 
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
            searchLabel: 'Search all credentials...',
            trueMessage: 'selected',
            falseMessage: 'credential',
            searchColor: AppColors.issuingAccent,
            backgroundColor: AppColors.issuingAccent.withOpacity(0.1),
            borderColor: AppColors.issuingAccent.withOpacity(0.25),
            textColor: AppColors.issuingLight,
          ),
          Container(height: 1, color: AppColors.border),
          _buildHeader(),
          Container(height: 1, color: AppColors.border),
          Expanded(
            child: BuildrowWidget<CredentialRecord>(
              errorMessage: hasError ? 'Failed to load credentials.' : null,
              isLoading: isLoading,
              items: rows,
              query: search,
              onRetry: onRetry,
              emptyDefaultMessage: 'No credentials match your search.',
              emptySearchMessage: 'No results for "{query}".',
              accentColor: AppColors.issuingAccent,
              itemBuilder: (context, rec) {
                return _CredentialRow(
                  record: rec,
                  isSelected: selected.contains(rec.id),
                  onToggle: () => onToggleRow(rec.id),
                );
              },
            ),
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
          ColHead('CREDENTIAL ID', flex: 3),
          ColHead('HOLDER NAME', flex: 3),
          ColHead('CREDENTIAL TYPE', flex: 4),
          ColHead('ISSUED BY', flex: 3),
          ColHead('ISSUE DATE', flex: 2),
          ColHead('EXPIRY DATE', flex: 2),
          ColHead('STATUS', flex: 2),
        ],
      ),
    );
  }
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
                child: Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Text(
                    r.credentialType,
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
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
                  DateFormatter.formatIsoDate(r.issueDate),
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
                  DateFormatter.formatIsoDate(r.expiryDate ?? 'No Expiry'),
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
              Expanded(
                flex: 2,
                child: StatusBadge(fg: r.status.fg, label: r.status.label, iconPresent: false,),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
