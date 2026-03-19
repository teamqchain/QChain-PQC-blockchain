// screens/verifier/subscription_page.dart
//
// Subscriptions — monitor credentials over time and receive alerts on
// status changes.
//
// Layout contract (matches all_credentials_page.dart):
//   Padding → Column
//     Title (fixed)
//     Expanded table container (toolbar → header → rows)
//     Pagination bar (fixed)
//     Action bar (fixed)
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   case RouteName.subscription:
//     return SubscriptionPage(
//       onBack:  () => _handleNavigate(RouteName.dashboard),
//       onAlert: (id) => _handleNavigate(RouteName.subscriptionAlert, arg: id),
//     );

import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/filterButton.dart';
import 'package:qportal_webapp/components/searchBar.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/models/verifiying_models.dart';
import 'package:qportal_webapp/screens/verifier/add_subscription_dialog.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/app_button.dart';

// ─── SUBSCRIPTION STATUS ENUM ────────────────────────────────────────────────

enum SubStatus { active, pending, unsubscribed, rejected, expired }

extension SubStatusX on SubStatus {
  String get label {
    switch (this) {
      case SubStatus.active:
        return 'Active';
      case SubStatus.pending:
        return 'Pending';
      case SubStatus.unsubscribed:
        return 'Unsubscribed';
      case SubStatus.rejected:
        return 'Rejected';
      case SubStatus.expired:
        return 'Expired';
    }
  }

  Color get fg {
    switch (this) {
      case SubStatus.active:
        return AppColors.valid;
      case SubStatus.pending:
        return const Color(0xFF60A5FA); // blue
      case SubStatus.unsubscribed:
        return AppColors.textMuted;
      case SubStatus.rejected:
        return AppColors.revoked;
      case SubStatus.expired:
        return AppColors.expired;
    }
  }
}

// ─── MODEL ───────────────────────────────────────────────────────────────────



// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class SubscriptionPage extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(String subscriptionId)? onAlert;

  const SubscriptionPage({super.key, required this.onBack, this.onAlert});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  // ── data ──────────────────────────────────────────────────────────────────
  late List<SubscriptionRecord> _allRows;
  late List<SubscriptionRecord> _filtered;

  // ── single selection ──────────────────────────────────────────────────────
  String? _selectedId;

  // ── search ────────────────────────────────────────────────────────────────
  String _query = '';
  final _searchCtrl = TextEditingController();

  // ── pagination ────────────────────────────────────────────────────────────
  int _rowsPerPage = 25;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _allRows = List.from(kMockSubscriptions);
    _applyFilter();
  }

  void _applyFilter() {
    final q = _query.toLowerCase().trim();
    _filtered = q.isEmpty
        ? List.from(_allRows)
        : _allRows.where((r) {
            return r.holderName.toLowerCase().contains(q) ||
                r.holderId.toLowerCase().contains(q) ||
                r.credentialType.toLowerCase().contains(q) ||
                r.issuer.toLowerCase().contains(q) ||
                r.status.label.toLowerCase().contains(q);
          }).toList();

    final maxPage = (_filtered.length / _rowsPerPage).ceil().clamp(1, 99999);
    if (_currentPage > maxPage) _currentPage = maxPage;
  }

  List<SubscriptionRecord> get _pageRows {
    final start = (_currentPage - 1) * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  int get _totalPages {
    if (_rowsPerPage <= 0) return 1;
    return (_filtered.length / _rowsPerPage).ceil().clamp(1, 99999);
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() => _currentPage = page);
  }

  void _changeRowsPerPage(int rpp) {
    setState(() {
      _rowsPerPage = rpp;
      _currentPage = 1;
    });
  }

  SubscriptionRecord? get _sel => _selectedId == null
      ? null
      : _allRows.where((r) => r.id == _selectedId).firstOrNull;

  // ── Button enablement logic ───────────────────────────────────────────────

  bool get _deleteEnabled => _sel?.status == SubStatus.pending;
  bool get _unsubscribeEnabled => _sel?.status == SubStatus.active;
  bool get _alertEnabled => _sel != null;

  String? get _deleteTooltip {
    if (_sel == null) return 'Select a pending request to delete';
    if (_sel!.status != SubStatus.pending) {
      return 'Delete is only available for pending requests';
    }
    return null;
  }

  String? get _unsubscribeTooltip {
    if (_sel == null) return 'Select an active subscription to unsubscribe';
    if (_sel!.status != SubStatus.active) {
      return 'Unsubscribe is only available for active subscriptions';
    }
    return null;
  }

  String? get _alertTooltip =>
      _sel == null ? 'Select a subscription to manage alerts' : null;

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onDelete() {
    final record = _sel!;
    showDialog(
      context: context,
      builder: (_) => _DeleteDialog(
        holderName: record.holderName,
        onConfirm: () {
          setState(() {
            _allRows.removeWhere((r) => r.id == record.id);
            _selectedId = null;
            _applyFilter();
          });
        },
      ),
    );
  }

  void _onUnsubscribe() {
    final record = _sel!;
    showDialog(
      context: context,
      builder: (_) => _UnsubscribeDialog(
        holderName: record.holderName,
        credentialType: record.credentialType,
        onConfirm: () {
          setState(() {
            final idx = _allRows.indexWhere((r) => r.id == record.id);
            if (idx != -1) {
              _allRows[idx] = SubscriptionRecord(
                id: record.id,
                holderName: record.holderName,
                holderId: record.holderId,
                credentialType: record.credentialType,
                issuer: record.issuer,
                subscribedDate: record.subscribedDate,
                expiryDate: record.expiryDate,
                status: SubStatus.unsubscribed,
              );
            }
            _selectedId = null;
            _applyFilter();
          });
        },
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
            'Subscriptions',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
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
                  // SizedBox(height: 3,),
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
            onPageChanged: _goToPage,
            onRowsPerPageChanged: _changeRowsPerPage,
          ),
          const SizedBox(height: 14),

          // ── Action bar ───────────────────────────────────────────────────
          _buildActionBar(),
        ],
      ),
    );
  }

  // ─── TOOLBAR ──────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF161616),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          // Count chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.verifyingAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.verifyingAccent.withOpacity(0.25),
              ),
            ),
            child: Text(
              '${_filtered.length} subscription${_filtered.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.verifyingLight,
              ),
            ),
          ),

          const Spacer(),

          // Filter icon
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
              _applyFilter();
            }),
            onClear: () {
              _searchCtrl.clear();
              setState(() {
                _query = '';
                _applyFilter();
              });
            },
            barWidth: 248,
            searchLabel: 'Search by holder, type, status…',
            activeColor: AppColors.verifyingAccent,
          ),
          const SizedBox(width: 10),

          // Add New Request
          AppButton(
            icon: Icons.add_rounded,
            label: 'Add New Request',
            backgroundColor: AppColors.verifyingAccent,
            hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
            onTap: () => showDialog(
              context: context,
              builder: (_) => AddNewSubscriptionDialog(overlayContext: context),
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
          // SizedBox(
          //   width: 32,
          //   child: Checkbox(
          //     value: selectAll,
          //     tristate: true,
          //     onChanged: onToggleAll,
          //     activeColor: AppColors.verifyingAccent,
          //     side: const BorderSide(color: AppColors.textMuted),
          //     materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          //   ),
          // ),
          SizedBox(width: 14,),
          _th('HOLDER NAME',     flex: 3),
          _th('HOLDER ID',       flex: 3),
          _th('CREDENTIAL TYPE', flex: 4),
          _th('ISSUER',          flex: 3),
          _th('SUB. DATE', flex: 2),
          _th('EXPIRY DATE',     flex: 2),
          _th('STATUS',          flex: 2),
        ],
      ),
    );
  }

  Widget _th(String label, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(
      label,
      style: AppTextStyles.bodyTiny.copyWith(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: AppColors.white,
      ),
    ),
  );


  

  // ─── LIST ─────────────────────────────────────────────────────────────────

  Widget _buildList() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _query.isEmpty
                  ? Icons.subscriptions_outlined
                  : Icons.search_off_rounded,
              size: 36,
              color: AppColors.textDim,
            ),
            const SizedBox(height: 12),
            Text(
              _query.isEmpty
                  ? 'No subscriptions found.'
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _pageRows.length,
      separatorBuilder: (_, __) =>
          Container(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final record = _pageRows[i];
        return _SubRow(
          record: record,
          isSelected: record.id == _selectedId,
          onTap: () => setState(() {
            _selectedId = record.id == _selectedId ? null : record.id;
          }),
        );
      },
    );
  }

  // ─── ACTION BAR ───────────────────────────────────────────────────────────

  Widget _buildActionBar() {
    final sel = _sel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Back
        AppButton(
          icon: Icons.arrow_back_rounded,
          label: 'Back',
          showBorder: true,
          borderColor: AppColors.border,
          hoverColor: AppColors.surfaceHover,
          onTap: widget.onBack,
        ),
        const SizedBox(width: 10),

        // Delete — only for Pending
        AppButton(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          showBorder: true,
          borderColor: _deleteEnabled
              ? AppColors.revoked.withOpacity(0.5)
              : AppColors.border,
          textColor: _deleteEnabled ? AppColors.revoked : AppColors.textDim,
          iconColor: _deleteEnabled ? AppColors.revoked : AppColors.textDim,
          hoverColor: _deleteEnabled
              ? AppColors.revoked.withOpacity(0.08)
              : Colors.transparent,
          disabledBorderColor: AppColors.border,
          enabled: _deleteEnabled,
          tooltip: _deleteTooltip,
          onTap: _onDelete,
        ),
        const SizedBox(width: 10),

        // Unsubscribe — only for Active
        AppButton(
          icon: Icons.notifications_off_outlined,
          label: 'Unsubscribe',
          showBorder: true,
          borderColor: _unsubscribeEnabled
              ? AppColors.suspended.withOpacity(0.5)
              : AppColors.border,
          textColor: _unsubscribeEnabled
              ? AppColors.suspended
              : AppColors.textDim,
          iconColor: _unsubscribeEnabled
              ? AppColors.suspended
              : AppColors.textDim,
          hoverColor: _unsubscribeEnabled
              ? AppColors.suspended.withOpacity(0.08)
              : Colors.transparent,
          disabledBorderColor: AppColors.border,
          enabled: _unsubscribeEnabled,
          tooltip: _unsubscribeTooltip,
          onTap: _onUnsubscribe,
        ),
        // const SizedBox(width: 10),

        // Alert
        // AppButton(
        //   icon: Icons.notifications_active_outlined,
        //   label: 'Alert',
        //   backgroundColor: _alertEnabled
        //       ? AppColors.verifyingAccent
        //       : Colors.transparent,
        //   hoverColor: _alertEnabled
        //       ? AppColors.verifyingAccent.withOpacity(0.82)
        //       : Colors.transparent,
        //   showBorder: !_alertEnabled,
        //   borderColor: AppColors.border,
        //   disabledBorderColor: AppColors.border,
        //   textColor: _alertEnabled ? AppColors.white : AppColors.textDim,
        //   iconColor: _alertEnabled ? AppColors.white : AppColors.textDim,
        //   disabledBackgroundColor: AppColors.verifyingAccent.withOpacity(0.28),
        //   enabled: _alertEnabled,
        //   tooltip: _alertTooltip,
        //   onTap: () => widget.onAlert?.call(_selectedId!),
        // ),

        // Selection hint
        if (sel != null) ...[
          const SizedBox(width: 16),
          Container(width: 1, height: 18, color: AppColors.border),
          const SizedBox(width: 14),
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 12,
            color: AppColors.textDim,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${sel.holderName}  ·  ${sel.id}',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                color: AppColors.textDim,
              ),
              overflow: TextOverflow.ellipsis,
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

// ─── LIST ROW ─────────────────────────────────────────────────────────────────

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

              // Holder ID
              Expanded(
                flex: 3,
                child: Text(
                  r.holderId,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.verifyingLight,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
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
              Expanded(flex: 2, child: _StatusBadge(status: r.status)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── STATUS BADGE ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final SubStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final fg = status.fg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: fg.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DELETE CONFIRMATION DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _DeleteDialog extends StatelessWidget {
  final String holderName;
  final VoidCallback onConfirm;

  const _DeleteDialog({required this.holderName, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Container(
        width: 400,
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
                      color: AppColors.revoked.withOpacity(0.14),
                      border: Border.all(
                        color: AppColors.revoked.withOpacity(0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 17,
                      color: AppColors.revoked,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Pending Request',
                          style: AppTextStyles.navLabelActive.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          holderName,
                          style: AppTextStyles.bodyTiny.copyWith(
                            fontSize: 11,
                            color: AppColors.textDim,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.revoked.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.revoked.withOpacity(0.22),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 15,
                      color: AppColors.revoked.withOpacity(0.8),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Deleting this pending request will cancel the request.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
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
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      backgroundColor: AppColors.revoked,
                      hoverColor: AppColors.revoked.withOpacity(0.82),
                      onTap: () {
                        Navigator.pop(context);
                        onConfirm();
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
}

// ═════════════════════════════════════════════════════════════════════════════
// UNSUBSCRIBE CONFIRMATION DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _UnsubscribeDialog extends StatelessWidget {
  final String holderName;
  final String credentialType;
  final VoidCallback onConfirm;

  const _UnsubscribeDialog({
    required this.holderName,
    required this.credentialType,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
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
                      color: AppColors.suspended.withOpacity(0.14),
                      border: Border.all(
                        color: AppColors.suspended.withOpacity(0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.notifications_off_outlined,
                      size: 17,
                      color: AppColors.suspended,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unsubscribe',
                          style: AppTextStyles.navLabelActive.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '$holderName · $credentialType',
                          style: AppTextStyles.bodyTiny.copyWith(
                            fontSize: 11,
                            color: AppColors.textDim,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Warning box ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.suspended.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.suspended.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 15,
                      color: AppColors.suspended.withOpacity(0.85),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Once unsubscribed, you will no longer be able to view this credential or receive any status update notifications.\n\nTo subscribe again, you will need to send a new subscription request.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Buttons ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                      icon: Icons.notifications_off_outlined,
                      label: 'Confirm Unsubscribe',
                      backgroundColor: AppColors.suspended,
                      hoverColor: AppColors.suspended.withOpacity(0.82),
                      onTap: () {
                        Navigator.pop(context);
                        onConfirm();
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
}

// ═════════════════════════════════════════════════════════════════════════════
// PAGINATION BAR
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

  List<int?> get _pageNumbers {
    if (totalPages <= 7) return List.generate(totalPages, (i) => i + 1);
    final result = <int?>[];
    result.add(1);
    if (currentPage > 4) result.add(null);
    final start = (currentPage - 2).clamp(2, totalPages - 1);
    final end = (currentPage + 2).clamp(2, totalPages - 1);
    for (int i = start; i <= end; i++) result.add(i);
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
        Row(
          children: [
            _PageBtn(
              child: const Icon(Icons.chevron_left, size: 16),
              enabled: currentPage > 1,
              onTap: () => onPageChanged(currentPage - 1),
            ),
            const SizedBox(width: 4),
            ..._pageNumbers.map((p) {
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
                      color: p == currentPage ? Colors.white : AppColors.textDim,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 4),
            _PageBtn(
              child: const Icon(Icons.chevron_right, size: 16),
              enabled: currentPage < totalPages,
              onTap: () => onPageChanged(currentPage + 1),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Row(
          children: [
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
                child: _RowsPerPageChip(
                  value: n,
                  selected: n == rowsPerPage,
                  onTap: () => onRowsPerPageChanged(n),
                ),
              ),
            ),
          ],
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
  Widget build(BuildContext context) {
    final isActive = widget.active;
    final isEnabled = widget.enabled;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: isEnabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.verifyingAccent
                : _h && isEnabled
                ? AppColors.surfaceHover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isActive
                ? null
                : Border.all(
                    color: _h && isEnabled
                        ? AppColors.border
                        : Colors.transparent,
                  ),
          ),
          child: Opacity(opacity: isEnabled ? 1.0 : 0.3, child: widget.child),
        ),
      ),
    );
  }
}

class _RowsPerPageChip extends StatefulWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;
  const _RowsPerPageChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });
  @override
  State<_RowsPerPageChip> createState() => _RowsPerPageChipState();
}

class _RowsPerPageChipState extends State<_RowsPerPageChip> {
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
              ? AppColors.verifyingAccent.withOpacity(0.18)
              : _h
              ? AppColors.surfaceHover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: widget.selected
                ? AppColors.verifyingAccent.withOpacity(0.5)
                : AppColors.border,
          ),
        ),
        child: Text(
          '${widget.value}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w400,
            color:
                widget.selected ? AppColors.verifyingLight : AppColors.textDim,
          ),
        ),
      ),
    ),
  );
}

// ─── TOOLBAR ICON BUTTON ──────────────────────────────────────────────────────

// class xxz extends StatefulWidget {
//   final IconData icon;
//   final String tooltip;
//   final VoidCallback onTap;
//   const _ToolbarIconBtn({
//     required this.icon,
//     required this.tooltip,
//     required this.onTap,
//   });
//   @override
//   State<_ToolbarIconBtn> createState() => _ToolbarIconBtnState();
// }

// class _ToolbarIconBtnState extends State<_ToolbarIconBtn> {
//   bool _h = false;
//   @override
//   Widget build(BuildContext context) => Tooltip(
//     message: widget.tooltip,
//     child: MouseRegion(
//       cursor: SystemMouseCursors.click,
//       onEnter: (_) => setState(() => _h = true),
//       onExit: (_) => setState(() => _h = false),
//       child: GestureDetector(
//         onTap: widget.onTap,
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 120),
//           width: 34,
//           height: 34,
//           decoration: BoxDecoration(
//             color: _h ? AppColors.surfaceHover : Colors.transparent,
//             borderRadius: BorderRadius.circular(7),
//             border: Border.all(
//               color: _h ? AppColors.border : Colors.transparent,
//             ),
//           ),
//           child: Icon(widget.icon, size: 17, color: AppColors.textMuted),
//         ),
//       ),
//     ),
//   );
// }
