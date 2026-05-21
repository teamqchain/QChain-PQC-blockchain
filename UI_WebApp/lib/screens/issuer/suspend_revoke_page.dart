// screens/issuer/revoke_suspend_page.dart
//
// Revoke / Suspend Management — credential table + three full multi-step
// action flows (Revoke → Suspend → Restore), each with:
//   Step 1 — credential summary + action details + acknowledgement
//   Step 2 — password confirmation
//   Step 3 — result confirmation
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   case RouteName.revokeSuspend:
//     return RevokeSuspendPage(
//       onViewCredential: (id) =>
//           _handleNavigate(RouteName.credentialDetail, arg: id),
//     );

import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/filterButton.dart';
import 'package:qportal_webapp/components/label.dart';
import 'package:qportal_webapp/components/searchBar.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/app_button.dart';
import 'package:qportal_webapp/services/api_service.dart';

// ─── MOCK CURRENT USER ────────────────────────────────────────────────────────

const _kCurrentUser = 'Mohammed A.';

// ─── REVOKE REASON OPTIONS ────────────────────────────────────────────────────

const _kRevokeReasons = <String>[
  'Academic misconduct',
  'Disciplinary action',
  'Credential error — reissue required',
  'Holder request',
  'Fraudulent information provided',
  'Duplicate credential',
  'Other',
];

// ─── SUSPEND REASON OPTIONS ───────────────────────────────────────────────────

const _kSuspendReasons = <String>[
  'Audit review in progress',
  'Disciplinary investigation',
  'Temporary hold — pending verification',
  'Holder request',
  'Other',
];

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class RevokeSuspendPage extends StatefulWidget {
  /// Called when the user presses "View Credential".
  final void Function(String credentialId)? onViewCredential;

  const RevokeSuspendPage({super.key, this.onViewCredential});

  @override
  State<RevokeSuspendPage> createState() => _RevokeSuspendPageState();
}

class _RevokeSuspendPageState extends State<RevokeSuspendPage> {
  // ── local mutable list so status mutations reflect in the table ────────────
  List<CredentialRecord> _rows = [];
  List<CredentialRecord> _filtered = [];
  bool _isLoading = true;

  String _query = '';
  final _searchCtrl = TextEditingController();
  final Set<String> _selectedIds = {};

  // ── helpers ────────────────────────────────────────────────────────────────

  // @override
  // void initState() {
  //   super.initState();
  //   _rows = List<CredentialRecord>.from(IssuingMockData.credentials);
  //   _applyFilter();
  // }

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final data = await ApiService.getAllCredentials();
    if (!mounted) return;
    setState(() {
      _rows = data;
      _applyFilter();
      _isLoading = false;
    });
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
  }

  List<CredentialRecord> get _selRecords =>
      _rows.where((r) => _selectedIds.contains(r.id)).toList();

  bool get _hasSelection => _selectedIds.isNotEmpty;

  /// All selected rows share the same status (enforced at selection time).
  CredentialStatus? get _selStatus =>
      _hasSelection ? _selRecords.first.status : null;

  bool get _canRevoke =>
      _hasSelection && _selStatus != CredentialStatus.revoked;

  bool get _canSuspend => _hasSelection && _selStatus == CredentialStatus.valid;

  bool get _canRestore =>
      _hasSelection && (_selStatus == CredentialStatus.suspended);

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        return;
      }
      // Enforce same-status constraint
      final rec = _rows.firstWhere((r) => r.id == id);
      if (_selectedIds.isNotEmpty && rec.status != _selStatus) return;
      // Enforce max 10
      if (_selectedIds.length >= 10) return;
      _selectedIds.add(id);
    });
  }

  // ── status mutation ────────────────────────────────────────────────────────

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
              ? _kCurrentUser
              : null,
          revokedDate: newStatus == CredentialStatus.revoked
              ? _todayStr()
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

  String _todayStr() {
    final n = DateTime.now();
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${n.day.toString().padLeft(2, '0')} ${m[n.month - 1]} ${n.year}';
  }

  // ── dialog openers ─────────────────────────────────────────────────────────

  Future<void> _openRevoke() async {
    final recs = _selRecords;
    if (recs.isEmpty) return;
    final ids = recs.map((r) => r.id).toList();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RevokeDialog(
        credentials: recs,
        onConfirmed: () {
          _mutateAll(ids, CredentialStatus.revoked);
          // Fire-and-forget: only real CRED- IDs hit the API (mock QC- IDs are skipped).
          for (final id in ids) {
            if (id.startsWith('CRED-')) ApiService.revokeCredential(id);
          }
        },
      ),
    );
  }

  // Future<void> _openSuspend() async {
  //   final recs = _selRecords;
  //   if (recs.isEmpty) return;
  //   final ids = recs.map((r) => r.id).toList();
  //   await showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (_) => _SuspendDialog(
  //       credentials: recs,
  //       onConfirmed: (String reason) {
  //         _mutateAll(ids, CredentialStatus.suspended);
  //         for (final id in ids) {
  //           if (id.startsWith('CRED-')) {
  //             ApiService.suspendCredential(id, reason: reason);
  //           }
  //         }
  //       },
  //     ),
  //   );
  // }
  Future<void> _openSuspend() async {
    final recs = _selRecords;
    if (recs.isEmpty) return;
    final ids = recs.map((r) => r.id).toList();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuspendDialog(
        credentials: recs,
        onConfirmed: (String reason) async {
          // 1. Call API first, THEN mutate local state only on success
          bool allSucceeded = true;
          for (final id in ids) {
            if (id.startsWith('CRED-')) {
              try {
                final success = await ApiService.suspendCredential(
                  id,
                  reason: reason,
                );
                if (!success) allSucceeded = false;
              } catch (e) {
                allSucceeded = false;
                debugPrint('Suspend failed for $id: $e');
              }
            }
          }

          if (allSucceeded) {
            _mutateAll(
              ids,
              CredentialStatus.suspended,
            ); // only update UI after confirmed
          } else {
            // Show error to user
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Suspend failed — please try again.'),
                ),
              );
            }
            // Re-fetch real state from API
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
      builder: (_) => _RestoreDialog(
        credentials: recs,
        // onConfirmed: () => _mutateAll(ids, CredentialStatus.valid),
        onConfirmed: () {
          _mutateAll(ids, CredentialStatus.valid);
          for (final id in ids) {
            if (id.startsWith('CRED-')) {
              ApiService.restoreCredential(id);
            }
          }
        },
      ),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page title ─────────────────────────────────────────────────────
          Text(
            'Revoke / Suspend Management',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // ── Table container ────────────────────────────────────────────────
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
                  _buildColumnHeader(),
                  Expanded(child: _buildRows()),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Action buttons ─────────────────────────────────────────────────
          _buildActionBar(),
        ],
      ),
    );
  }

  // ─── TOOLBAR ───────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          // Search
          const Spacer(),
          ToolbarIconBtn(
            icon: Icons.filter_list_rounded,
            tooltip: 'Filtersear',
            onTap: () {},
          ),
          const SizedBox(width: 6),
          QSearchBar(
            controller: _searchCtrl,
            query: _query,
            onChanged: (v) => setState(() {
              _query = v;
              _applyFilter();
            }),
            onClear: () => setState(() {
              _query = '';
              _searchCtrl.clear();
              _applyFilter();
            }),
            searchLabel: 'Search credentials…',
            barWidth: 240,
          ),
          const SizedBox(width: 8),

          // Filter icon
        ],
      ),
    );
  }

  // ─── COLUMN HEADER ─────────────────────────────────────────────────────────

  Widget _buildColumnHeader() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.issuingAccent.withOpacity(0.16),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          const SizedBox(width: 36), // checkbox space
          _ColHead('CREDENTIAL ID', flex: 3),
          _ColHead('HOLDER NAME', flex: 3),
          _ColHead('CREDENTIAL TYPE', flex: 4),
          _ColHead('ISSUED BY', flex: 2),
          _ColHead('ISSUE DATE', flex: 2),
          _ColHead('EXPIRY DATE', flex: 2),
          _ColHead('STATUS', flex: 2),
        ],
      ),
    );
  }

  // ─── DATA ROWS ─────────────────────────────────────────────────────────────

  Widget _buildRows() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 32,
              color: AppColors.textDim,
            ),
            const SizedBox(height: 10),
            Text(
              _query.isEmpty
                  ? 'No credentials found.'
                  : 'No results for "$_query".',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                color: AppColors.textDim,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (_, __) =>
          Container(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final rec = _filtered[i];
        // Dim rows whose status differs from the current selection
        final canSelect = _selectedIds.isEmpty || rec.status == _selStatus;
        return _CredRow(
          record: rec,
          selected: _selectedIds.contains(rec.id),
          dimmed: !canSelect && !_selectedIds.contains(rec.id),
          onTap: () => _toggleSelection(rec.id),
        );
      },
    );
  }

  // ─── ACTION BAR ────────────────────────────────────────────────────────────

  Widget _buildActionBar() {
    final count = _selectedIds.length;
    final singleSel = count == 1 ? _selRecords.first : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Selection count chip ─────────────────────────────────────────
        if (count > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.issuingAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.issuingAccent.withOpacity(0.35),
              ),
            ),
            child: Text(
              '$count selected',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.issuingAccent,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],

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
              ? 'Only revoked or suspended credentials can be restored'
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

        // ── Selection indicator ─────────────────────────────────────────────
        // if (count > 0) ...[
        //   const SizedBox(width: 16),
        //   Container(width: 1, height: 18, color: AppColors.border),
        //   const SizedBox(width: 14),
        //   const Icon(
        //     Icons.check_circle_outline_rounded,
        //     size: 12,
        //     color: AppColors.textDim,
        //   ),
        //   const SizedBox(width: 6),
        //   Flexible(
        //     child: Text(
        //       '${sel.holderName}  ·  ${sel.id}',
        //       style: AppTextStyles.bodyTiny.copyWith(
        //         fontSize: 11,
        //         color: AppColors.textDim,
        //       ),
        //       overflow: TextOverflow.ellipsis,
        //     ),
        //   ),
        // ],
      ],
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Checkbox
                SizedBox(
                  width: 36,
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
                      fontFamily: 'monospace',
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
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
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Issued By
                Expanded(
                  flex: 2,
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
                    r.issueDate,
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
                    r.expiryDate ?? '—',
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
                Expanded(flex: 2, child: _StatusBadge(status: r.status)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  REVOKE DIALOG  (3-step: details+reason → password → confirmation)
// ═════════════════════════════════════════════════════════════════════════════

class _RevokeDialog extends StatefulWidget {
  final List<CredentialRecord> credentials;
  final VoidCallback onConfirmed;

  const _RevokeDialog({required this.credentials, required this.onConfirmed});

  @override
  State<_RevokeDialog> createState() => _RevokeDialogState();
}

class _RevokeDialogState extends State<_RevokeDialog>
    with SingleTickerProviderStateMixin {
  int _step = 1;

  // Step 1
  String? _reason;
  final _notesCtrl = TextEditingController();
  bool _acked = false;

  // Step 2
  final _pwCtrl = TextEditingController();
  bool _pwErr = false;

  bool get _step1Ready => _reason != null && _acked;

  void _toStep2() => setState(() => _step = 2);

  void _submitPw() {
    if (_pwCtrl.text.trim().isEmpty) {
      setState(() => _pwErr = true);
      return;
    }
    widget.onConfirmed();
    setState(() {
      _pwErr = false;
      _step = 3;
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _DialogFrame(
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: switch (_step) {
          1 => _Step1Revoke(
            credentials: widget.credentials,
            reason: _reason,
            notesCtrl: _notesCtrl,
            acked: _acked,
            reasons: _kRevokeReasons,
            accentColor: AppColors.revoked,
            proceedLabel: 'Revoke',
            onReasonChanged: (v) => setState(() => _reason = v),
            onAckedChanged: (v) => setState(() => _acked = v),
            canProceed: _step1Ready,
            onCancel: () => Navigator.pop(context),
            onProceed: _toStep2,
          ),
          2 => _Step2Password(
            accentColor: AppColors.revoked,
            proceedLabel: 'Revoke',
            pwCtrl: _pwCtrl,
            pwErr: _pwErr,
            onBack: () => setState(() {
              _step = 1;
              _pwErr = false;
            }),
            onSubmit: _submitPw,
          ),
          _ => _Step3Done(
            credentials: widget.credentials,
            performedBy: _kCurrentUser,
            actionPast: 'revoked',
            accentColor: AppColors.revoked,
            onReturn: () => Navigator.pop(context),
          ),
        },
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  SUSPEND DIALOG
// ═════════════════════════════════════════════════════════════════════════════

enum _SuspendMode { furtherNotice, specificDate }

class _SuspendDialog extends StatefulWidget {
  final List<CredentialRecord> credentials;
  final void Function(String reason) onConfirmed;

  const _SuspendDialog({required this.credentials, required this.onConfirmed});

  @override
  State<_SuspendDialog> createState() => _SuspendDialogState();
}

class _SuspendDialogState extends State<_SuspendDialog> {
  int _step = 1;

  // Step 1
  String? _reason;
  final _notesCtrl = TextEditingController();
  bool _acked = false;
  _SuspendMode _mode = _SuspendMode.furtherNotice;
  DateTime? _untilDate;

  // Step 2
  final _pwCtrl = TextEditingController();
  bool _pwErr = false;

  bool get _step1Ready =>
      _reason != null &&
      _acked &&
      (_mode == _SuspendMode.furtherNotice || _untilDate != null);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.suspended,
            onPrimary: Colors.black,
            surface: Color(0xFF1E1E1E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _untilDate = picked);
  }

  String _fmtDate(DateTime d) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
  }

  void _submitPw() {
    if (_pwCtrl.text.trim().isEmpty) {
      setState(() => _pwErr = true);
      return;
    }
    widget.onConfirmed(_reason!);
    setState(() {
      _pwErr = false;
      _step = 3;
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _DialogFrame(
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: switch (_step) {
          1 => _Step1Suspend(
            credentials: widget.credentials,
            reason: _reason,
            notesCtrl: _notesCtrl,
            acked: _acked,
            mode: _mode,
            untilDate: _untilDate,
            dateLabel: _untilDate != null ? _fmtDate(_untilDate!) : null,
            reasons: _kSuspendReasons,
            onReasonChanged: (v) => setState(() => _reason = v),
            onAckedChanged: (v) => setState(() => _acked = v),
            onModeChanged: (v) => setState(() {
              _mode = v;
              _untilDate = null;
            }),
            onPickDate: _pickDate,
            canProceed: _step1Ready,
            onCancel: () => Navigator.pop(context),
            onProceed: () => setState(() => _step = 2),
          ),
          2 => _Step2Password(
            accentColor: AppColors.suspended,
            proceedLabel: 'Suspend',
            pwCtrl: _pwCtrl,
            pwErr: _pwErr,
            onBack: () => setState(() {
              _step = 1;
              _pwErr = false;
            }),
            onSubmit: _submitPw,
          ),
          _ => _Step3Done(
            credentials: widget.credentials,
            performedBy: _kCurrentUser,
            actionPast: 'suspended',
            accentColor: AppColors.suspended,
            onReturn: () => Navigator.pop(context),
          ),
        },
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  RESTORE DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _RestoreDialog extends StatefulWidget {
  final List<CredentialRecord> credentials;
  final VoidCallback onConfirmed;

  const _RestoreDialog({required this.credentials, required this.onConfirmed});

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  int _step = 1;
  bool _acked = false;

  final _pwCtrl = TextEditingController();
  bool _pwErr = false;

  void _submitPw() {
    if (_pwCtrl.text.trim().isEmpty) {
      setState(() => _pwErr = true);
      return;
    }
    widget.onConfirmed();
    setState(() {
      _pwErr = false;
      _step = 3;
    });
  }

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _DialogFrame(
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: switch (_step) {
          1 => _Step1Restore(
            credentials: widget.credentials,
            acked: _acked,
            onAckedChanged: (v) => setState(() => _acked = v),
            canProceed: _acked,
            onCancel: () => Navigator.pop(context),
            onProceed: () => setState(() => _step = 2),
          ),
          2 => _Step2Password(
            accentColor: AppColors.verifyingAccent,
            proceedLabel: 'Restore',
            pwCtrl: _pwCtrl,
            pwErr: _pwErr,
            onBack: () => setState(() {
              _step = 1;
              _pwErr = false;
            }),
            onSubmit: _submitPw,
          ),
          _ => _Step3Done(
            credentials: widget.credentials,
            performedBy: _kCurrentUser,
            actionPast: 'restored',
            accentColor: AppColors.verifyingAccent,
            onReturn: () => Navigator.pop(context),
          ),
        },
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  STEP WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ─── STEP 1 — REVOKE ──────────────────────────────────────────────────────────

class _Step1Revoke extends StatelessWidget {
  final List<CredentialRecord> credentials;
  final String? reason;
  final TextEditingController notesCtrl;
  final bool acked;
  final List<String> reasons;
  final Color accentColor;
  final String proceedLabel;
  final void Function(String?) onReasonChanged;
  final void Function(bool) onAckedChanged;
  final bool canProceed;
  final VoidCallback onCancel;
  final VoidCallback onProceed;

  const _Step1Revoke({
    required this.credentials,
    required this.reason,
    required this.notesCtrl,
    required this.acked,
    required this.reasons,
    required this.accentColor,
    required this.proceedLabel,
    required this.onReasonChanged,
    required this.onAckedChanged,
    required this.canProceed,
    required this.onCancel,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _DlgHeader(
        icon: Icons.block_rounded,
        title: credentials.length == 1
            ? '$proceedLabel Credential'
            : '$proceedLabel ${credentials.length} Credentials',
        subtitle: 'Review the summary and provide a reason before proceeding.',
        accentColor: accentColor,
      ),
      const SizedBox(height: 20),

      _CredSummary(credentials: credentials),
      const SizedBox(height: 20),

      Label(text: 'Reason for $proceedLabel', required: true),
      const SizedBox(height: 6),
      _Dropdown(
        value: reason,
        items: reasons,
        hint: 'Select a reason…',
        accentColor: accentColor,
        onChanged: onReasonChanged,
      ),
      const SizedBox(height: 14),

      Label(text: 'Additional Notes'),
      const SizedBox(height: 6),
      _TextArea(
        controller: notesCtrl,
        hint: 'Optional — add any relevant context here…',
      ),
      const SizedBox(height: 18),

      _AckRow(
        checked: acked,
        text:
            'I understand this action will affect the holder\'s'
            ' credential and cannot be undone without re-issuance.',
        color: accentColor,
        onChanged: onAckedChanged,
      ),
      const SizedBox(height: 24),

      _DlgFooter(
        cancelLabel: 'Cancel',
        proceedLabel: proceedLabel,
        proceedColor: accentColor,
        canProceed: canProceed,
        onCancel: onCancel,
        onProceed: onProceed,
      ),
    ],
  );
}

// ─── STEP 1 — SUSPEND ─────────────────────────────────────────────────────────

class _Step1Suspend extends StatelessWidget {
  final List<CredentialRecord> credentials;
  final String? reason;
  final TextEditingController notesCtrl;
  final bool acked;
  final _SuspendMode mode;
  final DateTime? untilDate;
  final String? dateLabel;
  final List<String> reasons;
  final void Function(String?) onReasonChanged;
  final void Function(bool) onAckedChanged;
  final void Function(_SuspendMode) onModeChanged;
  final VoidCallback onPickDate;
  final bool canProceed;
  final VoidCallback onCancel;
  final VoidCallback onProceed;

  const _Step1Suspend({
    required this.credentials,
    required this.reason,
    required this.notesCtrl,
    required this.acked,
    required this.mode,
    required this.untilDate,
    required this.dateLabel,
    required this.reasons,
    required this.onReasonChanged,
    required this.onAckedChanged,
    required this.onModeChanged,
    required this.onPickDate,
    required this.canProceed,
    required this.onCancel,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _DlgHeader(
        icon: Icons.pause_circle_outline_rounded,
        title: credentials.length == 1
            ? 'Suspend Credential'
            : 'Suspend ${credentials.length} Credentials',
        subtitle: 'Review the summary and configure the suspension period.',
        accentColor: AppColors.suspended,
      ),
      const SizedBox(height: 20),

      _CredSummary(credentials: credentials),
      const SizedBox(height: 20),

      // Suspension duration
      const Label(text: 'Suspension Duration'),
      const SizedBox(height: 10),
      Row(
        children: [
          _Radio(
            label: 'Until further notice',
            selected: mode == _SuspendMode.furtherNotice,
            color: AppColors.suspended,
            onTap: () => onModeChanged(_SuspendMode.furtherNotice),
          ),
          const SizedBox(width: 20),
          _Radio(
            label: 'Until a specific date',
            selected: mode == _SuspendMode.specificDate,
            color: AppColors.suspended,
            onTap: () => onModeChanged(_SuspendMode.specificDate),
          ),
        ],
      ),

      if (mode == _SuspendMode.specificDate) ...[
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onPickDate,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceHover,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: dateLabel != null
                      ? AppColors.suspended.withOpacity(0.55)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: dateLabel != null
                        ? AppColors.suspended
                        : AppColors.textDim,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    dateLabel ?? 'Pick a date…',
                    style: TextStyle(
                      fontSize: 12,
                      color: dateLabel != null
                          ? AppColors.text
                          : AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],

      const SizedBox(height: 14),

      const Label(text: 'Reason for Suspension ', required: true),
      const SizedBox(height: 6),
      _Dropdown(
        value: reason,
        items: reasons,
        hint: 'Select a reason…',
        accentColor: AppColors.suspended,
        onChanged: onReasonChanged,
      ),
      const SizedBox(height: 14),

      const Label(text: 'Additional Notes'),
      const SizedBox(height: 6),
      _TextArea(
        controller: notesCtrl,
        hint: 'Optional — add any relevant context here…',
      ),
      const SizedBox(height: 18),

      _AckRow(
        checked: acked,
        text:
            'I understand this will temporarily restrict the holder\'s'
            ' access to this credential.',
        color: AppColors.suspended,
        onChanged: onAckedChanged,
      ),
      const SizedBox(height: 24),

      _DlgFooter(
        cancelLabel: 'Cancel',
        proceedLabel: 'Suspend',
        proceedColor: AppColors.suspended,
        canProceed: canProceed,
        onCancel: onCancel,
        onProceed: onProceed,
      ),
    ],
  );
}

// ─── STEP 1 — RESTORE ─────────────────────────────────────────────────────────

class _Step1Restore extends StatelessWidget {
  final List<CredentialRecord> credentials;
  final bool acked;
  final void Function(bool) onAckedChanged;
  final bool canProceed;
  final VoidCallback onCancel;
  final VoidCallback onProceed;

  const _Step1Restore({
    required this.credentials,
    required this.acked,
    required this.onAckedChanged,
    required this.canProceed,
    required this.onCancel,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _DlgHeader(
        icon: Icons.restore_rounded,
        title: credentials.length == 1
            ? 'Restore Credential'
            : 'Restore ${credentials.length} Credentials',
        subtitle: 'This will reinstate the credential to VALID status.',
        accentColor: AppColors.verifyingAccent,
      ),
      const SizedBox(height: 20),

      _CredSummary(credentials: credentials),
      const SizedBox(height: 18),

      // Info banner
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.verifyingAccent.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.verifyingAccent.withOpacity(0.22),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline,
              size: 14,
              color: AppColors.verifyingAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Restoring this credential will set its status back to VALID'
                ' and make it verifiable by third parties again.'
                ' All blockchain and IPFS records remain unchanged.',
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),

      _AckRow(
        checked: acked,
        text:
            'I confirm that this credential should be reinstated to'
            ' VALID status and made accessible to the holder.',
        color: AppColors.verifyingAccent,
        onChanged: onAckedChanged,
      ),
      const SizedBox(height: 24),

      _DlgFooter(
        cancelLabel: 'Cancel',
        proceedLabel: 'Restore',
        proceedColor: AppColors.verifyingAccent,
        canProceed: canProceed,
        onCancel: onCancel,
        onProceed: onProceed,
      ),
    ],
  );
}

// ─── STEP 2 — PASSWORD ────────────────────────────────────────────────────────

class _Step2Password extends StatelessWidget {
  final Color accentColor;
  final String proceedLabel;
  final TextEditingController pwCtrl;
  final bool pwErr;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const _Step2Password({
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

      _DlgHeader(
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

      _DlgFooter(
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

class _Step3Done extends StatelessWidget {
  final List<CredentialRecord> credentials;
  final String performedBy;
  final String actionPast; // 'revoked' | 'suspended' | 'restored'
  final Color accentColor;
  final VoidCallback onReturn;

  const _Step3Done({
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

class _DialogFrame extends StatelessWidget {
  final Widget child;
  const _DialogFrame({required this.child});

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

class _DlgHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;

  const _DlgHeader({
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

class _CredSummary extends StatelessWidget {
  final List<CredentialRecord> credentials;
  const _CredSummary({required this.credentials});

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
            _row('Issue Date', c.issueDate),
            _rowWidget('Current Status', _StatusBadge(status: c.status)),
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
                      fontFamily: 'monospace',
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
              fontFamily: mono ? 'monospace' : null,
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

class _Dropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final String hint;
  final Color accentColor;
  final void Function(String?) onChanged;

  const _Dropdown({
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

class _TextArea extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _TextArea({required this.controller, required this.hint});

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

class _AckRow extends StatelessWidget {
  final bool checked;
  final String text;
  final Color color;
  final void Function(bool) onChanged;

  const _AckRow({
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
              color: checked ? color.withOpacity(0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: checked ? color : AppColors.border,
                width: 1.5,
              ),
            ),
            child: checked ? Icon(Icons.check, size: 12, color: color) : null,
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

class _Radio extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Radio({
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

class _DlgFooter extends StatelessWidget {
  final String cancelLabel;
  final String proceedLabel;
  final Color proceedColor;
  final bool canProceed;
  final VoidCallback onCancel;
  final VoidCallback onProceed;

  const _DlgFooter({
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

// ═════════════════════════════════════════════════════════════════════════════
//  SMALL UTILITY WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ─── STATUS BADGE ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final CredentialStatus status;
  const _StatusBadge({required this.status});

  Color get _fg {
    switch (status) {
      case CredentialStatus.valid:
        return AppColors.valid;
      case CredentialStatus.revoked:
        return AppColors.revoked;
      case CredentialStatus.suspended:
        return AppColors.suspended;
      case CredentialStatus.expired:
        return AppColors.expired;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _fg.withOpacity(0.12),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: _fg.withOpacity(0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _fg),
        ),
        const SizedBox(width: 5),
        Text(
          status.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _fg,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}

// ─── SEARCH BAR ───────────────────────────────────────────────────────────────

// class _SearchBar extends StatelessWidget {
//   final TextEditingController controller;
//   final String query;
//   final void Function(String) onChanged;
//   final VoidCallback onClear;

//   const _SearchBar({
//     required this.controller,
//     required this.query,
//     required this.onChanged,
//     required this.onClear,
//   });

//   @override
//   Widget build(BuildContext context) => Container(
//     constraints: const BoxConstraints(maxWidth: 320),
//     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
//     decoration: BoxDecoration(
//       color: AppColors.white,
//       borderRadius: BorderRadius.circular(7),
//       border: Border.all(color: AppColors.border),
//     ),
//     child: Row(
//       children: [
//         const Icon(Icons.search, size: 14, color: AppColors.textDim),
//         const SizedBox(width: 8),
//         Expanded(
//           child: TextField(
//             controller: controller,
//             style: const TextStyle(fontSize: 12, color: AppColors.bg),
//             decoration: InputDecoration(
//               isDense: true,
//               border: InputBorder.none,
//               hintText: 'Search credentials…',
//               hintStyle: AppTextStyles.bodyTiny.copyWith(
//                 fontSize: 12,
//                 color: AppColors.borderLight,
//               ),
//             ),
//             onChanged: onChanged,
//           ),
//         ),
//         if (query.isNotEmpty)
//           GestureDetector(
//             onTap: onClear,
//             child: const Icon(Icons.close, size: 13, color: AppColors.textDim),
//           ),
//       ],
//     ),
//   );
// }

// ─── TOOLBAR ICON BUTTON ──────────────────────────────────────────────────────

class _ToolbarIconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ToolbarIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ToolbarIconBtn> createState() => _ToolbarIconBtnState();
}

class _ToolbarIconBtnState extends State<_ToolbarIconBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _h ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _h ? AppColors.border : Colors.transparent,
            ),
          ),
          child: Icon(widget.icon, size: 17, color: AppColors.textMuted),
        ),
      ),
    ),
  );
}

// ─── COLUMN HEADER ────────────────────────────────────────────────────────────

class _ColHead extends StatelessWidget {
  final String label;
  final int flex;
  const _ColHead(this.label, {this.flex = 1});

  @override
  Widget build(BuildContext context) => Expanded(
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
}

// ─── LABEL ────────────────────────────────────────────────────────────────────

// class Label extends StatelessWidget {
//   final String text;
//   const Label(this.text);

//   @override
//   Widget build(BuildContext context) => Text(
//     text,
//     style: AppTextStyles.bodyTiny.copyWith(
//       fontSize: 10,
//       fontWeight: FontWeight.w700,
//       letterSpacing: 0.4,
//       color: AppColors.textMuted,
//     ),
//   );
// }
