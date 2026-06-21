import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/toast.dart';
import 'package:qportal_webapp/dialog/deleteSubscription_dialog.dart';
import 'package:qportal_webapp/dialog/unsubscribe_dialog.dart';
import 'package:qportal_webapp/models/VERIFIER/subscription_model.dart';
import 'package:qportal_webapp/dialog/addSubscription_dialog.dart';
import 'package:qportal_webapp/services/subscription_api.dart';
import 'package:qportal_webapp/tables/subscription_table.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/components/paginationBar.dart';
import 'package:qportal_webapp/utils/logger.dart';

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

  OverlayEntry? _toastEntry;

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
      final data = await SubscriptionApi.getSubscriptions();
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
      builder: (_) => DeleteDialog(
        holderName: record.holderName,
        onConfirm: () async {
          try {
            final success = await SubscriptionApi.deleteSubscription(record.id);
            if (success) {
              _fetchData();
            } else {
              showToast(
                'Error 400: Failed to delete subscription.',
                Icons.error_outline,
                true,
              );
            }
          } catch (e) {
            logDebug('Failed to delete subscription: $e');
            
          }
        },
      ),
    );
  }

  void _onUnsubscribe() {
    final record = _sel!;
    showDialog(
      context: context,
      builder: (_) => UnsubscribeDialog(
        holderName: record.holderName,
        credentialType: record.credentialType,
        onConfirm: () async {
          try {
            final success = await SubscriptionApi.unsubscribe(record.id);
            if (success) {
              _fetchData();
            } else {
              showToast(
                'Error 400: Failed to unsubscribe.',
                Icons.error_outline,
                true,
              );
            }
          } catch (e) {
            logDebug('Failed to unsubscribe: $e');
          }
        },
      ),
    );
  }

  void showToast(String message, IconData reqIcons, bool isError) {
    _toastEntry?.remove();
    _toastEntry = OverlayEntry(
      builder: (_) => Toast(
        message: message,
        toastIcons: reqIcons,
        onDone: () {
          _toastEntry?.remove();
          _toastEntry = null;
        },
        bgColor: isError ? AppColors.revoked : AppColors.adminMid,
        iconColor: AppColors.text,
      ),
    );
    Overlay.of(context).insert(_toastEntry!);
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
            child: SubscriptionTable(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              onRetry: _fetchData,
              rows: _pageRows,
              selectedId: _selectedId,
              totalFiltered: _filtered.length,
              onToggleRow: (id) => setState(() {
                _selectedId = id == _selectedId ? null : id;
              }),
              search: _query,
              searchCtrl: _searchCtrl,
              onSearchChanged: (v) => setState(() {
                _query = v;
                _applyFilter();
              }),
              onClearSearch: () {
                _searchCtrl.clear();
                setState(() {
                  _query = '';
                  _applyFilter();
                });
              },
              // NEW: Pass the dialog action here
              onAddRequest: () => showDialog(
                context: context,
                builder: (_) => AddNewSubscriptionDialog(
                  overlayContext: context,
                  onSubscriptionRequested: _fetchData,
                ),
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