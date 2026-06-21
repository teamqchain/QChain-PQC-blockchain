import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/models/VERIFIER/subscription_model.dart';
import 'package:qportal_webapp/components/statusBadge.dart';
import 'package:qportal_webapp/components/tableHeader.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/buildRow_widget.dart';
import 'package:qportal_webapp/widgets/buildToolBar_widget.dart';

// ═════════════════════════════════════════════════════════════════════════════
// SUBSCRIPTION TABLE
// ═════════════════════════════════════════════════════════════════════════════

class SubscriptionTable extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final List<SubscriptionRecord> rows;
  final String? selectedId;
  final int totalFiltered;
  final void Function(String id) onToggleRow;
  final String search;
  final TextEditingController searchCtrl;
  final void Function(String) onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onAddRequest; // <-- Added callback for the add button

  const SubscriptionTable({
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.rows,
    required this.selectedId,
    required this.totalFiltered,
    required this.onToggleRow,
    required this.search,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onAddRequest, // <-- Require it here
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
            selected: selectedId != null ? {selectedId!} : {},
            totalFiltered: totalFiltered,
            searchCtrl: searchCtrl,
            search: search,
            onSearchChanged: onSearchChanged,
            onClearSearch: onClearSearch,
            searchLabel: 'Search by holder, type, status…',
            trueMessage: 'selected',
            falseMessage: 'subscription',
            falsePluralMessage: 'subscriptions',
            searchColor: AppColors.verifyingAccent,
            backgroundColor: AppColors.verifyingAccent.withOpacity(0.1),
            borderColor: AppColors.verifyingAccent.withOpacity(0.25),
            textColor: AppColors.verifyingAccent,
            // NEW: Pass the AppButton directly to the toolbar
            actionButton: AppButton(
              icon: Icons.add_rounded,
              label: 'Add New Request',
              backgroundColor: AppColors.verifyingAccent,
              hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
              onTap: onAddRequest,
            ),
          ),
          Container(height: 1, color: AppColors.border),
          _buildHeader(),
          Container(height: 1, color: AppColors.border),
          Expanded(
            child: BuildrowWidget<SubscriptionRecord>(
              errorMessage: errorMessage,
              isLoading: isLoading,
              items: rows,
              query: search,
              onRetry: onRetry,
              emptyDefaultMessage: 'No subscriptions found.',
              emptySearchMessage: 'No results for "{query}".',
              emptyDefaultIcon: Icons.subscriptions_outlined,
              emptySearchIcon: Icons.search_off_rounded,
              accentColor: AppColors.verifyingAccent,
              itemBuilder: (context, record) {
                return _SubRow(
                  record: record,
                  isSelected: record.id == selectedId,
                  onTap: () => onToggleRow(record.id),
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
      color: AppColors.verifyingAccent.withOpacity(0.16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
          ), // Spacing to align with selection stripe in row
          ColHead('CREDENTIAL ID', flex: 3),
          ColHead('HOLDER NAME', flex: 3),
          ColHead('CREDENTIAL TYPE', flex: 4),
          ColHead('ISSUER', flex: 3),
          ColHead('SUB. DATE', flex: 2),
          ColHead('EXPIRY DATE', flex: 2),
          ColHead('STATUS', flex: 2),
        ],
      ),
    );
  }
}

// ─── Table ROW ─────────────────────────────────────────────────────────────────

class _SubRow extends StatefulWidget {
  final SubscriptionRecord record;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubRow({
    required this.record,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SubRow> createState() => _SubRowState();
}

class _SubRowState extends State<_SubRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
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
              // Selection stripe
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 3,
                height: 32,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppColors.verifyingAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Credential ID
              Expanded(
                flex: 3,
                child: Text(
                  r.credentialID,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.verifyingAccent,
                    fontWeight: FontWeight.w600,
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
                  maxLines: 2,
                ),
              ),
              // Credential Type
              Expanded(
                flex: 4,
                child: Text(
                  r.credentialType,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),

              // Issuer
              Expanded(
                flex: 3,
                child: Text(
                  r.issuer,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Subscribed Date
              Expanded(
                flex: 2,
                child: Text(
                  r.subscribedDate,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: r.subscribedDate == '—'
                        ? AppColors.textDim.withOpacity(0.5)
                        : AppColors.textDim,
                    fontStyle: r.subscribedDate == '—'
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Expiry Date
              Expanded(
                flex: 2,
                child: Text(
                  r.expiryDate,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: r.expiryDate == '—'
                        ? AppColors.textDim.withOpacity(0.5)
                        : AppColors.textDim,
                    fontStyle: r.expiryDate == '—'
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
