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
//  SUSPEND / REVOKE TABLE
// ═════════════════════════════════════════════════════════════════════════════

class SuspendRevokeTable extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;
  final List<CredentialRecord> rows;
  final Set<String> selected;
  final CredentialStatus? selStatus;
  final int totalFiltered;
  final void Function(String id) onToggleRow;
  final String search;
  final TextEditingController searchCtrl;
  final void Function(String) onSearchChanged;
  final VoidCallback onClearSearch;

  const SuspendRevokeTable({
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
    required this.rows,
    required this.selected,
    required this.selStatus,
    required this.totalFiltered,
    required this.onToggleRow,
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
            selected: selected,
            totalFiltered: totalFiltered,
            searchCtrl: searchCtrl,
            search: search,
            onSearchChanged: onSearchChanged,
            onClearSearch: onClearSearch,
            searchLabel: 'Search credentials...',
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
              accentColor: AppColors.issuingAccent,
              errorMessage: hasError ? 'Failed to load credentials.' : null,
              isLoading: isLoading,
              items: rows,
              query: search,
              onRetry: onRetry,
              emptyDefaultMessage: 'No credentials found.',
              emptySearchMessage: 'No results for "{query}".',
              itemBuilder: (context, rec) {
                final canSelect = selected.isEmpty || rec.status == selStatus;
                return _CredRow(
                  record: rec,
                  selected: selected.contains(rec.id),
                  dimmed: !canSelect && !selected.contains(rec.id),
                  onTap: () => onToggleRow(rec.id),
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
          const SizedBox(width: 50), // MATCHED: Checkbox width is 50 in rows
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

// ═════════════════════════════════════════════════════════════════════════════
//  CREDENTIAL TABLE ROW
// ═════════════════════════════════════════════════════════════════════════════

class _CredRow extends StatefulWidget {
  final CredentialRecord record;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const _CredRow({
    required this.record,
    required this.selected,
    this.dimmed = false,
    required this.onTap,
  });

  @override
  State<_CredRow> createState() => _CredRowState();
}

class _CredRowState extends State<_CredRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;

    return Opacity(
      opacity: widget.dimmed ? 0.35 : 1.0,
      child: MouseRegion(
        cursor: widget.dimmed
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.dimmed ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            color: widget.selected
                ? AppColors.issuingAccent.withOpacity(0.08)
                : _hovered && !widget.dimmed
                ? AppColors.surfaceHover
                : Colors.transparent,
            // MATCHED: Use symmetric horizontal padding identical to the header
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Checkbox
                SizedBox(
                  width:
                      50, // MATCHED: Fixed at 50, perfectly mirroring the header spacer
                  child: Checkbox(
                    value: widget.selected,
                    onChanged: (_) => widget.onTap(),
                    activeColor: AppColors.issuingAccent,
                    checkColor: Colors.white,
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),

                // Credential ID
                Expanded(
                  flex: 3,
                  child: Text(
                    r.id,
                    style: const TextStyle(
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
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Text(
                      r.holderName,
                      style: AppTextStyles.bodyTiny.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
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
                    r.expiryDate != null
                        ? DateFormatter.formatIsoDate(r.expiryDate!)
                        : 'No Expiry',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 11,
                      color: r.expiryDate != null
                          ? AppColors.textDim
                          : AppColors.textDim.withOpacity(0.4),
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
                  child: StatusBadge(
                    fg: r.status.fg,
                    label: r.status.label,
                    iconPresent: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
