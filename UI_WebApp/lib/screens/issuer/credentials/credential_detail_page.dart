import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qportal_webapp/components/toast.dart';
import 'package:qportal_webapp/models/ISSUER/credentials_model.dart';
import 'package:qportal_webapp/services/issuer_api.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/components/connection_error.dart';
import 'package:qportal_webapp/components/statusBadge.dart';
import 'package:qportal_webapp/widgets/credentialHistoryPanel_widget.dart';

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

  bool _editing = false;
  bool _dirty = false;
  bool _saving = false;
  bool _showHistory = false;


  CredentialRecord? _detailRecord;
  bool _loadingDetail = true;
  bool _hasError = false;


  late TextEditingController _emailCtrl;
  late TextEditingController _expiryCtrl;
  bool _controllersInitialized = false;


  OverlayEntry? _toastEntry;

  CredentialRecord get _current => _detailRecord ?? widget.credential;

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
      final full = await IssuerApi.getCredentialDetail(widget.credential.id);
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
    final ok = await IssuerApi.updateCredential(
      credentialID: c.id,
      holderEmail: _emailCtrl.text.trim(),
      expiryDate: _expiryCtrl.text.trim().isEmpty
          ? null
          : _expiryCtrl.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
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
      showToast('Changes saved', Icons.check_circle_rounded, false);
    } else {
      setState(() => _saving = false);
      showToast('Save failed — check connection', Icons.error_outline_rounded, true);
    }
  }

  void _copyToClipboard(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    showToast('$label copied', Icons.check_circle_rounded, false);
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
        bgColor: isError ? AppColors.revoked : AppColors.valid,
        iconColor: AppColors.text,
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
                : (_showHistory
                      // Replace _buildHistoryPanel() with the new separated class
                      ? CredentialHistoryPanel(
                          credential: _current,
                          onClose: () => setState(() => _showHistory = false),
                        )
                      : _buildDetailCard()),
          ),

          const SizedBox(height: 18),
          _buildActionButtons(),
        ],
      ),
    );
  }

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
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge( label: c.status.label, fg: c.status.fg, iconPresent: false,),
              ],
            ),

            const SizedBox(height: 24),

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
            Row(
              children: [
                _sectionDividerInline('EDITABLE INFORMATION'),
                if (_editing) ...[const SizedBox(width: 10), StatusBadge(fg: AppColors.issuingAccent, label: "Editing", iconPresent: false)],
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
        AppButton(
          icon: Icons.history_rounded,
          label: _showHistory ? 'Hide History' : 'History',
          onTap: () => setState(() => _showHistory = !_showHistory),
          textColor: AppColors.issuingAccent,
          iconColor: AppColors.issuingAccent,
          fontWeight: FontWeight.w600,
          showBorder: true,
          borderColor: AppColors.issuingAccent.withOpacity(0.6),
          borderWidth: 1.5,
          backgroundColor: _showHistory
              ? AppColors.issuingAccent.withOpacity(0.1)
              : Colors.transparent,
          hoverColor: AppColors.issuingAccent.withOpacity(0.1),
        ),
        const SizedBox(width: 10),

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

  // Helpers
  
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
