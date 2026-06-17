import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/services/api_service.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/components/connection_error.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PAGE
// ═════════════════════════════════════════════════════════════════════════════

class CredentialDetailPage extends StatefulWidget {
  final CredentialRecord credential;
  final VoidCallback onClose;
  final void Function(CredentialRecord updated)? onReissue;

  const CredentialDetailPage({
    super.key,
    required this.credential,
    required this.onClose,
    this.onReissue,
  });

  @override
  State<CredentialDetailPage> createState() => _CredentialDetailPageState();
}

class _CredentialDetailPageState extends State<CredentialDetailPage> {
  // ── mode flags ──────────────────────────────────────────────────────────
  bool _editing = false;
  bool _dirty = false;
  bool _saving = false;
  bool _showHistory = false;

  // ── detail fetch state ──────────────────────────────────────────────────
  CredentialRecord? _detailRecord;
  bool _loadingDetail = true;
  bool _hasError = false;

  // ── controllers for editable fields ─────────────────────────────────────
  late TextEditingController _emailCtrl;
  late TextEditingController _expiryCtrl;
  bool _controllersInitialized = false;

  // ── clipboard toast overlay ──────────────────────────────────────────────
  OverlayEntry? _toastEntry;

  // ── convenience getter: always use the fetched record if available ───────
  CredentialRecord get _current => _detailRecord ?? widget.credential;

  // ─── INIT ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _resetControllers();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _loadingDetail = true;
      _hasError = false;
    });
    try {
      final full = await ApiService.getCredentialDetail(widget.credential.id);
      if (!mounted) return;
      setState(() {
        _detailRecord = full ?? widget.credential;
        _loadingDetail = false;
      });
      _resetControllers();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingDetail = false;
        _hasError = true;
      });
    }
  }

  // ─── CONTROLLERS ──────────────────────────────────────────────────────────

  void _resetControllers() {
    final c = _current;
    _disposeControllers();
    _emailCtrl = TextEditingController(text: c.holderEmail)
      ..addListener(_checkDirty);
    _expiryCtrl = TextEditingController(text: c.expiryDate ?? '')
      ..addListener(_checkDirty);
    _controllersInitialized = true;
  }

  void _disposeControllers() {
    if (!_controllersInitialized) return;
    _emailCtrl.dispose();
    _expiryCtrl.dispose();
    _controllersInitialized = false;
  }

  void _checkDirty() {
    final c = _current;
    final changed =
        _emailCtrl.text != c.holderEmail ||
        _expiryCtrl.text != (c.expiryDate ?? '');
    if (changed != _dirty) setState(() => _dirty = changed);
  }

  // ─── EDIT ACTIONS ─────────────────────────────────────────────────────────

  void _startEdit() => setState(() => _editing = true);

  void _cancelEdit() {
    _resetControllers();
    setState(() {
      _editing = false;
      _dirty = false;
    });
  }

  Future<void> _saveEdit() async {
    if (_saving) return;
    setState(() => _saving = true);

    final c = _current;
    final ok = await ApiService.updateCredential(
      credentialID: c.id,
      holderEmail: _emailCtrl.text.trim(),
      expiryDate: _expiryCtrl.text.trim().isEmpty
          ? null
          : _expiryCtrl.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      // Mirror the saved values into the local record so the UI stays accurate
      // without a second network round-trip.
      _detailRecord = CredentialRecord(
        id: c.id,
        holderName: c.holderName,
        holderEmail: _emailCtrl.text.trim(),
        holderId: c.holderId,
        holderEmiratesID: c.holderEmiratesID,
        credentialType: c.credentialType,
        issuedBy: c.issuedBy,
        issueDate: c.issueDate,
        expiryDate: _expiryCtrl.text.trim().isEmpty
            ? null
            : _expiryCtrl.text.trim(),
        status: c.status,
        auditTrail: c.auditTrail,
        attributes: c.attributes,
      );
      setState(() {
        _editing = false;
        _dirty = false;
        _saving = false;
      });
      _showToast('Changes saved');
    } else {
      setState(() => _saving = false);
      _showToast('Save failed — check connection', success: false);
    }
  }

  // ─── CLIPBOARD ────────────────────────────────────────────────────────────

  void _copyToClipboard(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    _showToast('$label copied');
  }

  void _showToast(String message, {bool success = true}) {
    _toastEntry?.remove();
    _toastEntry = OverlayEntry(
      builder: (_) => _Toast(
        message: message,
        success: success,
        onDone: () {
          _toastEntry?.remove();
          _toastEntry = null;
        },
      ),
    );
    Overlay.of(context).insert(_toastEntry!);
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Credential Details',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          Expanded(
            child: _hasError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80.0),
                      child: ConnectionErrorWidget(onRetry: _fetchDetail),
                    ),
                  )
                : _loadingDetail
                ? _buildLoadingShimmer()
                : (_showHistory ? _buildHistoryPanel() : _buildDetailCard()),
          ),

          const SizedBox(height: 18),
          _buildActionButtons(),
        ],
      ),
    );
  }

  // ─── LOADING SHIMMER ──────────────────────────────────────────────────────

  Widget _buildLoadingShimmer() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.issuingAccent,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DETAIL CARD
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDetailCard() {
    final c = _current;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row with status ─────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.credentialType,
                        style: AppTextStyles.navLabelActive.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.id,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.issuingLight,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: c.status),
              ],
            ),

            const SizedBox(height: 24),

            // ── System Information ─────────────────────────────────────
            _sectionDivider('SYSTEM INFORMATION'),
            const SizedBox(height: 14),

            _readRow(
              label: 'Credential ID',
              value: c.id,
              trailing: _CopyIconBtn(
                onTap: () => _copyToClipboard(c.id, 'Credential ID'),
              ),
            ),
            _readRow(label: 'Credential Type', value: c.credentialType),
            _readRow(label: 'Issued By', value: c.issuedBy),
            _readRow(label: 'Issue Date', value: c.issueDate),

            const SizedBox(height: 24),

            // ── Holder Information ─────────────────────────────────────
            _sectionDivider('HOLDER INFORMATION'),
            const SizedBox(height: 14),

            _readRow(
              label: 'First Name',
              value: c.holderName.trim().split(' ').isNotEmpty
                  ? c.holderName.trim().split(' ').first
                  : '',
            ),
            _readRow(
              label: 'Last Name',
              value: c.holderName.trim().split(' ').length > 1
                  ? c.holderName.trim().split(' ').sublist(1).join(' ')
                  : '',
            ),
            _readRow(label: 'Holder ID', value: c.holderId),

            const SizedBox(height: 24),

            // ── Editable fields ────────────────────────────────────────
            Row(
              children: [
                _sectionDividerInline('EDITABLE INFORMATION'),
                if (_editing) ...[const SizedBox(width: 10), _EditingChip()],
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _editField(label: 'Email Address', ctrl: _emailCtrl),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _editField(
                    label: 'Expiry Date',
                    ctrl: _expiryCtrl,
                    hint: 'DD MMM YYYY  (leave blank for no expiry)',
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── READ-ONLY ROW ────────────────────────────────────────────────────────

  Widget _readRow({
    required String label,
    required String value,
    Widget? trailing,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 156,
          child: Text(
            label,
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 11,
              color: AppColors.textDim,
            ),
          ),
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 6), trailing],
            ],
          ),
        ),
      ],
    ),
  );

  // ─── EDITABLE FIELD ───────────────────────────────────────────────────────

  Widget _editField({
    required String label,
    required TextEditingController ctrl,
    String? hint,
  }) {
    final en = _editing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyTiny.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: en ? AppColors.textMuted : AppColors.textDim,
          ),
        ),
        const SizedBox(height: 5),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: en
                ? AppColors.issuingAccent.withOpacity(0.04)
                : AppColors.surfaceHover.withOpacity(0.5),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: en
                  ? AppColors.issuingAccent.withOpacity(0.55)
                  : AppColors.border,
              width: en ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: ctrl,
            enabled: en,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: InputBorder.none,
              hintText: hint,
              hintStyle: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                color: AppColors.textDim.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── ACTION BUTTONS ───────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    final c = _current;

    return Row(
      children: [
        // 1 — History
        _OutlinedAccentBtn(
          icon: Icons.history_rounded,
          label: _showHistory ? 'Hide History' : 'History',
          onTap: () => setState(() => _showHistory = !_showHistory),
          active: _showHistory,
        ),
        const SizedBox(width: 10),

        // 2 — Edit / Save
        AppButton(
          icon: _saving
              ? Icons.hourglass_top_rounded
              : (_editing ? Icons.save : Icons.edit_outlined),
          label: _saving ? 'Saving…' : (_editing ? 'Save' : 'Edit'),
          enabled: !_showHistory && !_saving,
          onTap: _editing ? _saveEdit : _startEdit,
          textColor: AppColors.white,
          showBorder: true,
          borderColor: _editing ? AppColors.valid : AppColors.textDim,
          hoverColor: _editing
              ? AppColors.verifyingAccent
              : AppColors.surfaceHover,
          disabledTextColor: AppColors.textDim,
        ),

        const SizedBox(width: 10),

        // 3 — Reissue (enabled only when dirty)
        AppButton(
          icon: Icons.refresh_rounded,
          label: 'Reissue',
          backgroundColor: AppColors.issuingAccent,
          hoverColor: AppColors.issuingAccent.withOpacity(0.82),
          enabled: _dirty,
          onTap: () {
            if (widget.onReissue == null) return;
            final updated = CredentialRecord(
              id: c.id,
              holderName: c.holderName,
              holderEmail: _emailCtrl.text.trim(),
              holderId: c.holderId,
              holderEmiratesID: c.holderEmiratesID,
              credentialType: c.credentialType,
              issuedBy: c.issuedBy,
              issueDate: c.issueDate,
              expiryDate: _expiryCtrl.text.trim().isEmpty
                  ? null
                  : _expiryCtrl.text.trim(),
              status: c.status,
              auditTrail: c.auditTrail,
              attributes: c.attributes,
            );
            widget.onReissue!(updated);
          },
        ),
        const SizedBox(width: 10),

        // 4 — Close (filled red)
        AppButton(
          icon: Icons.close_rounded,
          label: _editing ? 'Cancel without saving' : 'Close',
          backgroundColor: _editing ? Colors.transparent : AppColors.revoked,
          hoverColor: AppColors.revoked.withOpacity(0.82),
          onTap: _editing ? _cancelEdit : widget.onClose,
          showBorder: true,
          borderColor: _editing ? AppColors.revoked : Colors.transparent,
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HISTORY PANEL
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHistoryPanel() {
    final c = _current;
    final entries = c.auditTrail;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Container(
            color: const Color(0xFF161616),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: AppColors.issuingAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Credential History',
                        style: AppTextStyles.navLabelActive.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        c.id,
                        style: AppTextStyles.bodyTiny.copyWith(
                          fontSize: 10,
                          color: AppColors.textDim,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showHistory = false),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: AppColors.textDim,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.border),

          // Timeline scroll area
          Expanded(
            child: entries.isEmpty
                ? _buildEmptyHistory()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                    child: Column(
                      children: List.generate(
                        entries.length,
                        (i) => _TimelineNode(
                          entry: entries[i],
                          isLast: i == entries.length - 1,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_rounded,
            size: 32,
            color: AppColors.textDim.withOpacity(0.4),
          ),
          const SizedBox(height: 10),
          Text(
            'No history events yet',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 12,
              color: AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  Widget _sectionDivider(String label) => Row(
    children: [
      Text(
        label,
        style: AppTextStyles.bodyTiny.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: AppColors.textDim,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 1, color: AppColors.border)),
    ],
  );

  Widget _sectionDividerInline(String label) => Expanded(
    child: Row(
      children: [
        Text(
          label,
          style: AppTextStyles.bodyTiny.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: AppColors.textDim,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AppColors.border)),
      ],
    ),
  );

  @override
  void dispose() {
    _disposeControllers();
    _toastEntry?.remove();
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TIMELINE NODE
// ═════════════════════════════════════════════════════════════════════════════

class _TimelineNode extends StatefulWidget {
  final AuditEntry entry;
  final bool isLast;

  const _TimelineNode({required this.entry, required this.isLast});

  @override
  State<_TimelineNode> createState() => _TimelineNodeState();
}

class _TimelineNodeState extends State<_TimelineNode> {
  bool _reasonVisible = false;

  bool get _isClickable {
    final a = widget.entry.action.toLowerCase();
    return (a.contains('revok') || a.contains('suspend')) &&
        widget.entry.note != null;
  }

  Color get _accentColor {
    final a = widget.entry.action.toLowerCase();
    if (a.contains('revok')) return AppColors.revoked;
    if (a.contains('suspend')) return AppColors.suspended;
    return AppColors.issuingAccent;
  }

  IconData get _nodeIcon {
    final a = widget.entry.action.toLowerCase();
    if (a.contains('revok')) return Icons.cancel_outlined;
    if (a.contains('suspend')) return Icons.pause_circle_outline_rounded;
    if (a.contains('restore')) return Icons.play_circle_outline_rounded;
    if (a.contains('reissued')) return Icons.refresh_rounded;
    return Icons.verified_outlined;
  }

  String get _performedVerb {
    final a = widget.entry.action.toLowerCase();
    if (a.contains('revok')) return 'Revoked';
    if (a.contains('suspend')) return 'Suspended';
    if (a.contains('restore')) return 'Restored';
    if (a.contains('reissued')) return 'Reissued';
    return 'Issued';
  }

  @override
  Widget build(BuildContext context) {
    final color = _accentColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Spine column ──────────────────────────────────────────────
        SizedBox(
          width: 42,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.13),
                  border: Border.all(
                    color: color.withOpacity(0.45),
                    width: 1.5,
                  ),
                ),
                child: Icon(_nodeIcon, size: 16, color: color),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // ── Content ───────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.isLast ? 0 : 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date
                Text(
                  widget.entry.date,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 10,
                    color: AppColors.textDim,
                  ),
                ),
                const SizedBox(height: 3),

                // Action title
                Text(
                  'Credential ${widget.entry.action}',
                  style: AppTextStyles.navLabelActive.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),

                // Performed by
                Text(
                  '$_performedVerb by: ${widget.entry.performedBy}',
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),

                // Clickable reason (only revoke / suspend)
                if (_isClickable) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _reasonVisible = !_reasonVisible),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _reasonVisible ? 'Hide reason' : 'Show reason',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 3),
                          AnimatedRotation(
                            turns: _reasonVisible ? 0.5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: _reasonVisible
                        ? Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: color.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 13,
                                  color: color.withOpacity(0.65),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'REASON',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: color.withOpacity(0.6),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.entry.note!,
                                        style: AppTextStyles.bodyTiny.copyWith(
                                          fontSize: 11,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SMALL REUSABLE WIDGETS
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
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: _fg.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _fg.withOpacity(0.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _fg),
        ),
        const SizedBox(width: 6),
        Text(
          status.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _fg,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}

// ─── COPY ICON BUTTON ─────────────────────────────────────────────────────────

class _CopyIconBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _CopyIconBtn({required this.onTap});

  @override
  State<_CopyIconBtn> createState() => _CopyIconBtnState();
}

class _CopyIconBtnState extends State<_CopyIconBtn> {
  bool _h = false;
  bool _done = false;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Copy',
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: () async {
          widget.onTap();
          setState(() => _done = true);
          await Future.delayed(const Duration(milliseconds: 900));
          if (mounted) setState(() => _done = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _h ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            _done ? Icons.check_rounded : Icons.copy_rounded,
            size: 13,
            color: _done
                ? AppColors.valid
                : (_h ? AppColors.textMuted : AppColors.textDim),
          ),
        ),
      ),
    ),
  );
}

// ─── "EDITING" CHIP ───────────────────────────────────────────────────────────

class _EditingChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.issuingAccent.withOpacity(0.12),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: AppColors.issuingAccent.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.issuingAccent,
          ),
        ),
        const SizedBox(width: 5),
        const Text(
          'Editing',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.issuingAccent,
            letterSpacing: 0.4,
          ),
        ),
      ],
    ),
  );
}

// ─── OUTLINED ACCENT BUTTON ───────────────────────────────────────────────────

class _OutlinedAccentBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _OutlinedAccentBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  State<_OutlinedAccentBtn> createState() => _OutlinedAccentBtnState();
}

class _OutlinedAccentBtnState extends State<_OutlinedAccentBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: widget.active || _h
              ? AppColors.issuingAccent.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: AppColors.issuingAccent.withOpacity(0.6),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 14, color: AppColors.issuingAccent),
            const SizedBox(width: 7),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.issuingAccent,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── CLIPBOARD TOAST ─────────────────────────────────────────────────────────

class _Toast extends StatefulWidget {
  final String message;
  final VoidCallback onDone;
  final bool success;

  const _Toast({
    required this.message,
    required this.onDone,
    this.success = true,
  });

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    Future.delayed(
      const Duration(milliseconds: 1500),
      () => _ctrl.reverse().then((_) => widget.onDone()),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    bottom: 50,
    left: 150,
    right: 0,
    child: Center(
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  (widget.success
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded),
                  size: 14,
                  color: widget.success ? AppColors.valid : AppColors.revoked,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
