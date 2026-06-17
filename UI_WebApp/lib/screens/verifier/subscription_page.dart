// screens/verifier/subscription_page.dart
import 'package:flutter/material.dart';
import 'package:qportal_webapp/services/api_service.dart';
import 'package:qportal_webapp/components/filterButton.dart';
import 'package:qportal_webapp/components/searchBar.dart';
import 'package:qportal_webapp/components/connection_error.dart';
import 'package:qportal_webapp/models/verifiying_models.dart';
import 'package:qportal_webapp/screens/verifier/add_subscription_dialog.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/widgets/paginationBar.dart';
import 'package:qportal_webapp/widgets/statusBadge.dart';

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
        return const Color(0xFF60A5FA);
      case SubStatus.unsubscribed:
        return AppColors.textMuted;
      case SubStatus.rejected:
        return AppColors.revoked;
      case SubStatus.expired:
        return AppColors.expired;
    }
  }
}

class SubscriptionPage extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(String subscriptionId)? onAlert;

  const SubscriptionPage({super.key, required this.onBack, this.onAlert});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  List<SubscriptionRecord> _allRows = [];
  List<SubscriptionRecord> _filtered = [];
  bool _isLoading = true;
  String? _errorMessage; // Tracks connection errors
  String? _selectedId;
  String _query = '';
  final _searchCtrl = TextEditingController();
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
      _errorMessage = null; // reset on retry
    });

    try {
      final data = await ApiService.getSubscriptions();
      if (mounted) {
        setState(() {
          _allRows = data;
          _applyFilter();
          _isLoading = false;
          _selectedId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Connection Error: Unable to reach the server to fetch subscriptions.';
        });
      }
    }
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
    if (_filtered.isEmpty) return [];
    final start = (_currentPage - 1) * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  int get _totalPages {
    if (_rowsPerPage <= 0 || _filtered.isEmpty) return 1;
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

  bool get _deleteEnabled => _sel?.status == SubStatus.pending;
  bool get _unsubscribeEnabled => _sel?.status == SubStatus.active;

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

  void _onDelete() {
    final record = _sel!;
    showDialog(
      context: context,
      builder: (_) => _DeleteDialog(
        holderName: record.holderName,
        onConfirm: () async {
          try {
            final success = await ApiService.deleteSubscription(record.id);
            if (success) _fetchData();
          } catch (e) {
            _showErrorSnackbar(
              'Connection Error: Failed to delete subscription.',
            );
          }
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
        onConfirm: () async {
          try {
            final success = await ApiService.unsubscribe(record.id);
            if (success) _fetchData();
          } catch (e) {
            _showErrorSnackbar('Connection Error: Failed to unsubscribe.');
          }
        },
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.revoked,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
                  Expanded(child: _buildList()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Pagination ───────────────────────────────────────────────────
          PaginationBar(
            currentPage: _currentPage,
            totalPages: _totalPages,
            rowsPerPage: _rowsPerPage,
            totalRows: _filtered.length,
            onPageChanged: _goToPage,
            onRowsPerPageChanged: _changeRowsPerPage,
            accentColor: AppColors.verifyingAccent,
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
              builder: (_) => AddNewSubscriptionDialog(
                overlayContext: context,
                onSubscriptionRequested: _fetchData,
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
          const SizedBox(width: 14),
          _th('HOLDER NAME', flex: 3),
          _th('CREDENTIAL ID', flex: 3),
          _th('CREDENTIAL TYPE', flex: 4),
          _th('ISSUER', flex: 3),
          _th('SUB. DATE', flex: 2),
          _th('EXPIRY DATE', flex: 2),
          _th('STATUS', flex: 2),
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

  Widget _buildList() {
    // 1. Connection Error State
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 80.0),
        child: ConnectionErrorWidget(onRetry: _fetchData),
      );
    }

    // 2. Loading State
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.verifyingAccent),
      );
    }

    // 3. Empty State
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

    // 4. Data State
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

// ... existing _SubRow, _StatusBadge, _DeleteDialog, _UnsubscribeDialog, _PaginationBar code remains ...
// Add these below the SubscriptionPage definition like in the original file.

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
              Expanded(flex: 2, child: StatusBadge(fg: r.status.fg, label: r.status.label)),
            ],
          ),
        ),
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
