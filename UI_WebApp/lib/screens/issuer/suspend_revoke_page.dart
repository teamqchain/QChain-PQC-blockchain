import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/label.dart';
import 'package:qportal_webapp/dialog/restore_dialog.dart';
import 'package:qportal_webapp/dialog/revoke_dialog.dart';
import 'package:qportal_webapp/dialog/suspend_dialog.dart';
import 'package:qportal_webapp/models/ISSUER/credentials_model.dart';
import 'package:qportal_webapp/services/issuer_api.dart';
import 'package:qportal_webapp/tables/revokeSuspend_table.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/components/paginationBar.dart';
import 'package:qportal_webapp/components/statusBadge.dart';
import 'package:qportal_webapp/utils/currentUser.dart';
import 'package:qportal_webapp/utils/dateFormatter.dart';
import 'package:qportal_webapp/utils/logger.dart';



class RevokeSuspendPage extends StatefulWidget {
  final void Function(String credentialId)? onViewCredential;

  const RevokeSuspendPage({super.key, this.onViewCredential});

  @override
  State<RevokeSuspendPage> createState() => _RevokeSuspendPageState();
}

class _RevokeSuspendPageState extends State<RevokeSuspendPage> {
  List<CredentialRecord> _rows = [];
  List<CredentialRecord> _filtered = [];
  bool _isLoading = true;
  bool _hasError = false;

  String _query = '';
  final _searchCtrl = TextEditingController();
  final Set<String> _selectedIds = {};

  int _rowsPerPage = 25;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final data = await IssuerApi.getAllCredentials();
      if (!mounted) return;
      setState(() {
        _rows = data;
        _applyFilter();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _applyFilter() {
    final q = _query.toLowerCase().trim();
    _filtered = q.isEmpty
        ? List<CredentialRecord>.from(_rows)
        : _rows.where((r) {
            return r.id.toLowerCase().contains(q) ||
                r.holderName.toLowerCase().contains(q) ||
                r.credentialType.toLowerCase().contains(q) ||
                r.issuedBy.toLowerCase().contains(q) ||
                r.status.label.toLowerCase().contains(q);
          }).toList();

    if (_currentPage > _totalPages) {
      _currentPage = _totalPages;
    }
  }

  List<CredentialRecord> get _selRecords =>
      _rows.where((r) => _selectedIds.contains(r.id)).toList();

  bool get _hasSelection => _selectedIds.isNotEmpty;

  CredentialStatus? get _selStatus =>
      _hasSelection ? _selRecords.first.status : null;

  bool get _canRevoke =>
      _hasSelection && _selStatus != CredentialStatus.revoked;

  bool get _canSuspend => _hasSelection && _selStatus == CredentialStatus.valid;

  bool get _canRestore =>
      _hasSelection && (_selStatus == CredentialStatus.suspended);

  List<CredentialRecord> get _pageRows {
    final start = (_currentPage - 1) * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  int get _totalPages =>
      (_filtered.length / _rowsPerPage).ceil().clamp(1, 99999);

  int get _filteredCount => _filtered.length;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        return;
      }
      final rec = _rows.firstWhere((r) => r.id == id);
      if (_selectedIds.isNotEmpty && rec.status != _selStatus) return;
      if (_selectedIds.length >= 10) return;
      _selectedIds.add(id);
    });
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() {
      _currentPage = page;
    });
  }

  void _changeRowsPerPage(int rowsPerPage) {
    setState(() {
      _rowsPerPage = rowsPerPage;
      _currentPage = 1;
      _applyFilter();
    });
  }


  void _mutateAll(List<String> ids, CredentialStatus newStatus) {
    setState(() {
      for (final id in ids) {
        final i = _rows.indexWhere((r) => r.id == id);
        if (i < 0) continue;
        final old = _rows[i];
        _rows[i] = CredentialRecord(
          holderEmiratesID: old.holderEmiratesID,
          id: old.id,
          holderName: old.holderName,
          holderEmail: old.holderEmail,
          holderId: old.holderId,
          credentialType: old.credentialType,
          issuedBy: old.issuedBy,
          issueDate: old.issueDate,
          expiryDate: old.expiryDate,
          status: newStatus,
          revokedBy: newStatus == CredentialStatus.revoked
              ? kCurrentUser
              : null,
          revokedDate: newStatus == CredentialStatus.revoked
              ? DateFormatter.formatIsoDate(DateTime.now() as String?)
              : null,
          auditTrail: old.auditTrail,
          attributes: old.attributes,
          signingAlgorithm: old.signingAlgorithm,
          signatureHash: old.signatureHash,
          blockchainTxId: old.blockchainTxId,
          ipfsReference: old.ipfsReference,
        );
      }
      _selectedIds.clear();
      _applyFilter();
    });
  }


  // Dialogs for Revoke, Suspend, Restore actions
  Future<void> _openRevoke() async {
    final recs = _selRecords;
    if (recs.isEmpty) return;
    final ids = recs.map((r) => r.id).toList();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RevokeDialog(
        credentials: recs,
        onConfirmed: () {
          _mutateAll(ids, CredentialStatus.revoked);
          for (final id in ids) {
            if (id.startsWith('CRED-')) IssuerApi.revokeCredential(id);
          }
        },
      ),
    );
  }

  Future<void> _openSuspend() async {
    final recs = _selRecords;
    if (recs.isEmpty) return;
    final ids = recs.map((r) => r.id).toList();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SuspendDialog(
        credentials: recs,
        onConfirmed: (String reason) async {
          bool allSucceeded = true;
          for (final id in ids) {
            if (id.startsWith('CRED-')) {
              try {
                final success = await IssuerApi.suspendCredential(
                  id,
                  reason: reason,
                );
                if (!success) allSucceeded = false;
              } catch (e) {
                allSucceeded = false;
                logDebug('Suspend failed for $id: $e');
              }
            }
          }

          if (allSucceeded) {
            _mutateAll(
              ids,
              CredentialStatus.suspended,
            ); 
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Suspend failed — please try again.'),
                ),
              );
            }
            _loadCredentials();
          }
        },
      ),
    );
  }

  Future<void> _openRestore() async {
    final recs = _selRecords;
    if (recs.isEmpty) return;
    final ids = recs.map((r) => r.id).toList();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RestoreDialog(
        credentials: recs,
        onConfirmed: () {
          _mutateAll(ids, CredentialStatus.valid);
          for (final id in ids) {
            if (id.startsWith('CRED-')) {
              IssuerApi.restoreCredential(id);
            }
          }
        },
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
          Text(
            'Revoke / Suspend Management',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SuspendRevokeTable(
              isLoading: _isLoading,
              hasError: _hasError,
              onRetry: _loadCredentials,
              rows: _pageRows,
              selected: _selectedIds,
              selStatus: _selStatus,
              totalFiltered: _filteredCount,
              onToggleRow: _toggleSelection,
              search: _query,
              searchCtrl: _searchCtrl,
              onSearchChanged: (v) => setState(() {
                _query = v;
                _applyFilter();
              }),
              onClearSearch: () => setState(() {
                _query = '';
                _searchCtrl.clear();
                _applyFilter();
              }),
            ),
          ),
          const SizedBox(height: 16),
          PaginationBar(
            currentPage: _currentPage,
            totalPages: _totalPages,
            rowsPerPage: _rowsPerPage,
            totalRows: _filteredCount,
            onPageChanged: _goToPage,
            onRowsPerPageChanged: _changeRowsPerPage,
            accentColor: AppColors.issuingAccent,
          ),
          const SizedBox(height: 16),
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    final count = _selectedIds.length;
    final singleSel = count == 1 ? _selRecords.first : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Revoke ──────────────────────────────────────────────────────────
        AppButton(
          label: count > 1 ? 'Revoke ($count)' : 'Revoke',
          icon: Icons.block_rounded,
          backgroundColor: AppColors.revoked,
          hoverColor: AppColors.revoked.withOpacity(0.82),
          enabled: _canRevoke,
          onTap: _openRevoke,
          tooltip: !_hasSelection
              ? 'Select a credential first'
              : _selStatus == CredentialStatus.revoked
              ? 'Already revoked'
              : null,
          disabledTextColor: AppColors.textDim,
        ),
        const SizedBox(width: 10),

        // ── Suspend ─────────────────────────────────────────────────────────
        AppButton(
          label: count > 1 ? 'Suspend ($count)' : 'Suspend',
          icon: Icons.pause_circle_outline_rounded,
          backgroundColor: AppColors.suspended,
          hoverColor: AppColors.suspended.withOpacity(0.82),
          enabled: _canSuspend,
          onTap: _openSuspend,
          tooltip: !_hasSelection
              ? 'Select a credential first'
              : _selStatus != CredentialStatus.valid
              ? 'Only VALID credentials can be suspended'
              : null,
          disabledTextColor: AppColors.textDim,
        ),
        const SizedBox(width: 10),

        // ── Restore ─────────────────────────────────────────────────────────
        AppButton(
          label: count > 1 ? 'Restore ($count)' : 'Restore',
          icon: Icons.restore_rounded,
          backgroundColor: AppColors.expired, // grey per spec
          hoverColor: AppColors.expired.withOpacity(0.82),
          enabled: _canRestore,
          onTap: _openRestore,
          tooltip: !_hasSelection
              ? 'Select a credential first'
              : !_canRestore
              ? 'Only suspended credentials can be restored'
              : null,
          disabledTextColor: AppColors.textDim,
        ),
        const SizedBox(width: 10),

        // ── View Credential (only when exactly 1 selected) ──────────────
        AppButton(
          label: 'View Credential',
          icon: Icons.open_in_new_rounded,
          enabled: singleSel != null,
          onTap: () {
            if (singleSel != null) widget.onViewCredential?.call(singleSel.id);
          },
          tooltip: count == 0
              ? 'Select a credential first'
              : count > 1
              ? 'Select exactly one credential to view'
              : null,
          showBorder: true,
          borderColor: AppColors.issuingAccent,
          hoverColor: AppColors.surfaceHover,
          disabledTextColor: AppColors.textDim,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

// ─── STEP 2 — PASSWORD ────────────────────────────────────────────────────────

class Step2Password extends StatelessWidget {
  final Color accentColor;
  final String proceedLabel;
  final TextEditingController pwCtrl;
  final bool pwErr;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const Step2Password({
    super.key,
    required this.accentColor,
    required this.proceedLabel,
    required this.pwCtrl,
    required this.pwErr,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Step indicator
      Row(
        children: [
          _StepDot(n: 1, done: true, active: false, color: accentColor),
          _StepLine(done: true, color: accentColor),
          _StepDot(n: 2, done: false, active: true, color: accentColor),
          _StepLine(done: false, color: accentColor),
          _StepDot(n: 3, done: false, active: false, color: accentColor),
        ],
      ),
      const SizedBox(height: 22),

      DlgHeader(
        icon: Icons.lock_outline_rounded,
        title: 'Confirm Your Identity',
        subtitle: 'Enter your password to authorise this action.',
        accentColor: accentColor,
      ),
      const SizedBox(height: 22),

      const Label(text: 'Password'),
      const SizedBox(height: 6),
      AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: AppColors.surfaceHover,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: pwErr ? AppColors.revoked : AppColors.border,
            width: pwErr ? 1.5 : 1,
          ),
        ),
        child: TextField(
          controller: pwCtrl,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          style: const TextStyle(fontSize: 13, color: AppColors.text),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            border: InputBorder.none,
            hintText: 'Enter your password',
            hintStyle: AppTextStyles.bodyTiny.copyWith(
              fontSize: 12,
              color: AppColors.textDim,
            ),
          ),
          onSubmitted: (_) => onSubmit(),
        ),
      ),
      if (pwErr) ...[
        const SizedBox(height: 6),
        const Text(
          'Password is required to proceed.',
          style: TextStyle(fontSize: 11, color: AppColors.revoked),
        ),
      ],
      const SizedBox(height: 24),

      DlgFooter(
        cancelLabel: '← Back',
        proceedLabel: 'Submit',
        proceedColor: accentColor,
        canProceed: true,
        onCancel: onBack,
        onProceed: onSubmit,
      ),
    ],
  );
}

// ─── STEP 3 — DONE ────────────────────────────────────────────────────────────

class Step3Done extends StatelessWidget {
  final List<CredentialRecord> credentials;
  final String performedBy;
  final String actionPast; // 'revoked' | 'suspended' | 'restored'
  final Color accentColor;
  final VoidCallback onReturn;

  const Step3Done({
    super.key,
    required this.credentials,
    required this.performedBy,
    required this.actionPast,
    required this.accentColor,
    required this.onReturn,
  });

  IconData get _icon {
    if (actionPast == 'restored') return Icons.check_circle_outline_rounded;
    if (actionPast == 'revoked') return Icons.cancel_outlined;
    return Icons.pause_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final count = credentials.length;
    final single = count == 1;
    final holderName = credentials.first.holderName;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),

        // Large icon badge
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withOpacity(0.12),
              border: Border.all(
                color: accentColor.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Icon(_icon, size: 34, color: accentColor),
          ),
        ),
        const SizedBox(height: 20),

        // Title
        Center(
          child: Text(
            'Action Complete',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Message
        Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.7,
                letterSpacing: 0.5,
              ),
              children: single
                  ? [
                      const TextSpan(text: 'The credential for '),
                      TextSpan(
                        text: holderName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextSpan(text: ' has been $actionPast by '),
                      TextSpan(
                        text: performedBy,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ]
                  : [
                      TextSpan(
                        text: '$count credentials',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextSpan(text: ' have been $actionPast by '),
                      TextSpan(
                        text: performedBy,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Return button
        Center(
          child: AppButton(
            label: 'Return to Management',
            backgroundColor: accentColor,
            hoverColor: accentColor.withOpacity(0.82),
            onTap: onReturn,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHARED DIALOG BUILDING BLOCKS
// ═════════════════════════════════════════════════════════════════════════════

// ─── DIALOG OUTER FRAME ───────────────────────────────────────────────────────

class DialogFrame extends StatelessWidget {
  final Widget child;
  const DialogFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
    child: Container(
      constraints: const BoxConstraints(maxWidth: 540),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.65),
            blurRadius: 48,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
        child: child,
      ),
    ),
  );
}

// ─── DIALOG HEADER ────────────────────────────────────────────────────────────

class DlgHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;

  const DlgHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 20, color: accentColor),
      ),
      const SizedBox(width: 13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.navLabelActive.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                color: AppColors.textDim,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// ─── CREDENTIAL SUMMARY CARD ──────────────────────────────────────────────────

class CredSummary extends StatelessWidget {
  final List<CredentialRecord> credentials;
  const CredSummary({super.key, required this.credentials});

  @override
  Widget build(BuildContext context) {
    if (credentials.length == 1) {
      final c = credentials.first;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceHover,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            _row('Credential ID', c.id, mono: true),
            _row('Holder Name', c.holderName),
            _row('Credential Type', c.credentialType),
            _row('Issue Date', DateFormatter.formatIsoDate(c.issueDate)),
            _rowWidget(
              'Current Status',
              StatusBadge(
                fg: c.status.fg,
                label: c.status.label,
                iconPresent: false,
              ),
            ),
          ],
        ),
      );
    }

    // Multiple credentials
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.issuingAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${credentials.length} credentials selected',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.issuingAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...credentials.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.fiber_manual_record,
                    size: 5,
                    color: AppColors.textDim,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Text(
                      c.holderName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      c.credentialType,
                      style: AppTextStyles.bodyTiny.copyWith(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    c.id.length > 12 ? '${c.id.substring(0, 12)}…' : c.id,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.issuingLight.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool mono = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: [
        SizedBox(
          width: 128,
          child: Text(
            label,
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 11,
              color: AppColors.textDim,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: mono ? AppColors.issuingLight : AppColors.text,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  Widget _rowWidget(String label, Widget widget) => Row(
    children: [
      SizedBox(
        width: 128,
        child: Text(
          label,
          style: AppTextStyles.bodyTiny.copyWith(
            fontSize: 11,
            color: AppColors.textDim,
          ),
        ),
      ),
      widget,
    ],
  );
}

// ─── DROPDOWN ─────────────────────────────────────────────────────────────────

class Dropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final String hint;
  final Color accentColor;
  final void Function(String?) onChanged;

  const Dropdown({
    super.key,
    required this.value,
    required this.items,
    required this.hint,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.surfaceHover,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(
        color: value != null ? accentColor.withOpacity(0.5) : AppColors.border,
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: const Color(0xFF1E1E1E),
        iconEnabledColor: AppColors.textDim,
        hint: Text(
          hint,
          style: AppTextStyles.bodyTiny.copyWith(
            fontSize: 12,
            color: AppColors.textDim,
          ),
        ),
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.text,
          fontFamily: 'Inter',
        ),
        items: items
            .map((r) => DropdownMenuItem(value: r, child: Text(r)))
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

// ─── TEXT AREA ────────────────────────────────────────────────────────────────

class TextArea extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const TextArea({super.key, required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceHover,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: AppColors.border),
    ),
    child: TextField(
      controller: controller,
      maxLines: 3,
      style: const TextStyle(fontSize: 12, color: AppColors.text),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.all(12),
        border: InputBorder.none,
        hintText: hint,
        hintStyle: AppTextStyles.bodyTiny.copyWith(
          fontSize: 12,
          color: AppColors.textDim,
        ),
      ),
    ),
  );
}

// ─── ACKNOWLEDGEMENT ROW ──────────────────────────────────────────────────────

class AckRow extends StatelessWidget {
  final bool checked;
  final String text;
  final Color color;
  final void Function(bool) onChanged;

  const AckRow({
    super.key,
    required this.checked,
    required this.text,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!checked),
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Custom checkbox
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 1.5),
            decoration: BoxDecoration(
              color: checked ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: checked ? color : AppColors.border,
                width: 1.5,
              ),
            ),
            child: checked ? Icon(Icons.check, size: 14, color: AppColors.text) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── RADIO ────────────────────────────────────────────────────────────────────

class Radio extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const Radio({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? color : AppColors.border,
                width: 1.5,
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 12,
              color: selected ? AppColors.text : AppColors.textMuted,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── STEP INDICATOR DOTS + LINES ─────────────────────────────────────────────

class _StepDot extends StatelessWidget {
  final int n;
  final bool done;
  final bool active;
  final Color color;

  const _StepDot({
    required this.n,
    required this.done,
    required this.active,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = done || active
        ? color.withOpacity(done ? 0.2 : 0.12)
        : AppColors.surfaceHover;
    final border = done || active ? color.withOpacity(0.6) : AppColors.border;
    final textColor = done || active ? color : AppColors.textDim;

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: border, width: 1.5),
      ),
      child: done
          ? Icon(Icons.check, size: 12, color: color)
          : Center(
              child: Text(
                '$n',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool done;
  final Color color;
  const _StepLine({required this.done, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 1.5,
      color: done ? color.withOpacity(0.4) : AppColors.border,
    ),
  );
}

// ─── DIALOG FOOTER ────────────────────────────────────────────────────────────

class DlgFooter extends StatelessWidget {
  final String cancelLabel;
  final String proceedLabel;
  final Color proceedColor;
  final bool canProceed;
  final VoidCallback onCancel;
  final VoidCallback onProceed;

  const DlgFooter({
    super.key,
    required this.cancelLabel,
    required this.proceedLabel,
    required this.proceedColor,
    required this.canProceed,
    required this.onCancel,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      AppButton(
        label: cancelLabel,
        onTap: onCancel,
        textColor: AppColors.textMuted,
        showBorder: true,
        borderColor: AppColors.border,
        hoverColor: AppColors.surfaceHover,
      ),
      const SizedBox(width: 10),
      AppButton(
        label: proceedLabel,
        backgroundColor: canProceed
            ? proceedColor
            : proceedColor.withOpacity(0.28),
        hoverColor: proceedColor.withOpacity(0.82),
        onTap: canProceed ? onProceed : () {},
      ),
    ],
  );
}
