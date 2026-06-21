import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/components/statusBadge.dart';
import 'package:qportal_webapp/components/tableHeader.dart';
import 'package:qportal_webapp/models/IT_ADMIN/staff/staff_model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/buildRow_widget.dart';
import 'package:qportal_webapp/widgets/buildToolBar_widget.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  MANAGE STAFF TABLE
// ═════════════════════════════════════════════════════════════════════════════

class ManageTable extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final List<StaffEntry> items;
  final String query;
  final String? selectedId;
  final TextEditingController searchCtrl;
  final VoidCallback onRetry;
  final void Function(String id) onToggleRow;
  final void Function(String) onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onAddStaff;

  const ManageTable({
    required this.isLoading,
    required this.errorMessage,
    required this.items,
    required this.query,
    required this.selectedId,
    required this.searchCtrl,
    required this.onRetry,
    required this.onToggleRow,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onAddStaff,
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
            totalFiltered: items.length,
            searchCtrl: searchCtrl,
            search: query,
            onSearchChanged: onSearchChanged,
            onClearSearch: onClearSearch,
            searchLabel: 'Search by name, email, role, portal…',
            trueMessage: 'selected',
            falseMessage: 'member',
            falsePluralMessage: 'members',
            searchColor: AppColors.adminAccent,
            backgroundColor: AppColors.adminAccent.withOpacity(0.1),
            borderColor: AppColors.adminAccent.withOpacity(0.35),
            textColor: AppColors.adminAccent,
            actionButton: AppButton(
              label: 'Add',
              icon: Icons.person_add_outlined,
              backgroundColor: AppColors.adminAccent,
              hoverColor: AppColors.adminAccent.withOpacity(0.82),
              onTap: onAddStaff,
            ),
          ),
          Container(height: 1, color: AppColors.border),
          _buildColHeader(),
          Expanded(
            child: BuildrowWidget<StaffEntry>(
              errorMessage: errorMessage,
              isLoading: isLoading,
              items: items,
              query: query,
              onRetry: onRetry,
              emptyDefaultMessage: 'No staff members found.',
              emptySearchMessage: 'No results for "{query}".',
              emptyDefaultIcon: Icons.group_outlined,
              accentColor: AppColors.adminAccent,
              itemBuilder: (context, item) {
                return _StaffRow(
                  entry: item,
                  selected: item.id == selectedId,
                  onTap: () => onToggleRow(item.id),
                  status: item.status,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColHeader() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.adminAccent.withOpacity(0.16),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 17,), // Spacing to align with the selection stripe
          ColHead('STAFF ID', flex: 2),
          ColHead('NAME', flex: 4),
          ColHead('EMAIL', flex: 4),
          ColHead('PORTAL', flex: 2),
          const SizedBox(width: 60),
          ColHead('ROLE', flex: 3),
          const SizedBox(width: 32),
          ColHead('ADDED', flex: 3),
          ColHead('STATUS', flex: 3),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STAFF ROW
// ═════════════════════════════════════════════════════════════════════════════

class _StaffRow extends StatefulWidget {
  final StaffEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final StaffStatus status;

  const _StaffRow({
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.status,
  });

  @override
  State<_StaffRow> createState() => _StaffRowState();
}

class _StaffRowState extends State<_StaffRow> {
  bool _hovered = false;


  

  @override
  Widget build(BuildContext context) {
    final s = widget.entry;
    final Color c;
    final IconData icon;
    switch (widget.status) {
      case StaffStatus.active:
        c = AppColors.verifyingAccent;
        icon = Icons.check_circle_outline_rounded;
        break;
      case StaffStatus.invited:
        c = AppColors.adminAccent;
        icon = Icons.mail_outline_rounded;
        break;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: widget.selected
              ? AppColors.adminAccent.withOpacity(0.07)
              : _hovered
              ? AppColors.surfaceHover
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 3,
                height: 36,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: widget.selected
                      ? AppColors.adminAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // id
              Expanded(
                flex: 2,
                child: Text(
                  s.id,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.adminAccent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Name
              Expanded(
                flex: 4,
                child: Text(
                  s.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Email
              Expanded(
                flex: 4,
                child: Text(
                  s.email,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Portal
              Expanded(
                flex: 2,
                child: Text(
                  s.portal.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: s.portal.accent,
                  ),
                ),
              ),

              const SizedBox(width: 60),

              // Role
              Expanded(
                flex: 3,
                child: Text(
                  s.roleLabel,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: 32),

              // Added
              Expanded(
                flex: 3,
                child: Text(
                  s.addedDate,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                ),
              ),

              // Status
              Expanded(flex: 3, child: Padding(
                padding: const EdgeInsets.only(right: 70.0),
                child: StatusBadge(fg: c, label: s.status.label, iconPresent: true, icon: icon),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
