// screens/verifier/verification_detail_page.dart
//
// Verification Details — shows the full verification result for a record
// selected from the Verification History page.
//
// ── Integration ──────────────────────────────────────────────────────────────
//   case RouteName.verificationDetails:
//     return VerificationDetailPage(
//       recordId: _selectedVerificationHistoryId ?? '',
//       onBack: () => _handleNavigate(RouteName.verificationHistory),
//     );

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/components/connection_error.dart';
import 'package:qportal_webapp/models/verifiying_models.dart';
import 'package:qportal_webapp/services/api_service.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/utils/logger.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class VerificationDetailPage extends StatefulWidget {
  final String recordId;
  final VoidCallback onBack;

  const VerificationDetailPage({
    super.key,
    required this.recordId,
    required this.onBack,
  });

  @override
  State<VerificationDetailPage> createState() => _VerificationDetailPageState();
}

class _VerificationDetailPageState extends State<VerificationDetailPage> {
  VerificationDetailData? _data;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final detail = await ApiService.getVerificationDetail(widget.recordId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (detail == null) {
          _error = true;
        } else {
          _data = detail;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.hardEdge,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildBody(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HEADER ROW ────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        AppButton(
          icon: Icons.arrow_back_rounded,
          label: 'Back',
          showBorder: true,
          borderColor: AppColors.border,
          hoverColor: AppColors.surfaceHover,
          onTap: widget.onBack,
        ),
        const SizedBox(width: 16),
        Text(
          'Verification Record',
          style: AppTextStyles.navLabelActive.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        if (!_loading && !_error && _data != null)
          AppButton(
            icon: Icons.download_rounded,
            label: 'Export',
            showBorder: true,
            backgroundColor: AppColors.verifyingAccent.withOpacity(0.1),
            borderColor: AppColors.verifyingAccent.withOpacity(0.4),
            textColor: AppColors.verifyingLight,
            iconColor: AppColors.verifyingLight,
            hoverColor: AppColors.verifyingAccent.withOpacity(0.18),
            onTap: _showExportDialog,
          ),
      ],
    );
  }

  // ─── BODY SWITCHER ──────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) return _buildLoading();
    if (_error || _data == null) return _buildError();
    return _buildResultContent();
  }

  // ─── LOADING ────────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Center(
      key: const ValueKey('loading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: AppColors.verifyingAccent,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Retrieving verification details...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ─── ERROR ──────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(top: 40.0),
      child: ConnectionErrorWidget(
        onRetry: () {
          setState(() {
            _loading = true;
            _error = false;
          });
          _loadData();
        },
      ),
    );
  }

  // ─── RESULT CONTENT ──────────────────────────────────────────────────────────

  Widget _buildResultContent() {
    final data = _data!;

    return SingleChildScrollView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusBanner(result: data.result),
              const SizedBox(height: 24),
              _VerificationMetaSection(record: data.historyRecord),
              const SizedBox(height: 24),
              if (data.result.credential != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _CredentialMetaSection(
                        credential: data.result.credential!,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _HolderSection(credential: data.result.credential!),
                          const SizedBox(height: 24),
                          _PolicySection(result: data.result),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (_) => _ExportDialog(isValid: _data!.result.isValid),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DATA SECTIONS
// ═════════════════════════════════════════════════════════════════════════════

// ─── STATUS BANNER ────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final VerificationResult result;

  const _StatusBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final verifyResult = result.toVerifyResult();
    final Color accent = verifyResult.fg;
    final Color bg = verifyResult.bg;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.15),
            ),
            child: Icon(verifyResult.headerIcon, size: 28, color: accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verifyResult.headerLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  result.isValid
                      ? 'The blockchain record indicates this credential is fully valid and unmodified.'
                      : _getInvalidMessage(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: accent.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInvalidMessage() {
    final c = result.credential;
    switch (result.invalidReason) {
      case InvalidReason.revoked:
        return 'Revoked on ${c?.revokedDate ?? '—'}. Reason: ${c?.revokedReason ?? 'Not specified'}.';
      case InvalidReason.expired:
        return 'Expired on ${c?.expiryDate ?? '—'}. The credential is no longer valid.';
      case InvalidReason.suspended:
        return 'Temporarily suspended until ${c?.suspendedUntil ?? '—'}. Reason: ${c?.suspendedReason ?? 'Not specified'}.';
      case InvalidReason.tampered:
        return 'Data mismatch. The credential presented has been tampered with or modified from the original blockchain record.';
      case InvalidReason.notFound:
        return 'This credential was not found on the QChain network.';
      default:
        return 'Unknown error during verification.';
    }
  }
}

// ─── VERIFICATION METADATA ────────────────────────────────────────────────────

class _VerificationMetaSection extends StatelessWidget {
  final VerificationHistoryRecord record;

  const _VerificationMetaSection({required this.record});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'VERIFICATION EVENT DETAILS',
      icon: Icons.history_rounded,
      child: Wrap(
        spacing: 40,
        runSpacing: 20,
        children: [
          _DataColumn(label: 'Verification ID', value: record.id),
          _DataColumn(
            label: 'Timestamp',
            value: '${record.date}, ${record.time}',
          ),
          _DataColumn(label: 'Mode / Method', value: record.method.label),
          _DataColumn(
            label: 'Verified By',
            value: record.verifiedBy.isNotEmpty ? record.verifiedBy : '—',
          ),
        ],
      ),
    );
  }
}

// ─── CREDENTIAL RECORD METADATA ───────────────────────────────────────────────

class _CredentialMetaSection extends StatelessWidget {
  final CredentialRecord credential;

  const _CredentialMetaSection({required this.credential});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CREDENTIAL DETAILS',
      icon: Icons.description_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DataRow(label: 'Credential ID', value: credential.id),
          _divider(),
          _DataRow(label: 'Type', value: credential.credentialType),
          _divider(),
          _DataRow(label: 'Issuer Org', value: credential.issuerOrg),
          _divider(),
          _DataRow(
            label: 'Issue Date',
            value: credential.issueDate,
            isDate: true,
          ),
          _divider(),
          _DataRow(
            label: 'Expiry Date',
            value: credential.expiryDate ?? 'No Expiry',
            isDate: true,
          ),
        ],
      ),
    );
  }
}

// ─── HOLDER SECTION ───────────────────────────────────────────────────────────

class _HolderSection extends StatelessWidget {
  final CredentialRecord credential;

  const _HolderSection({required this.credential});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'SUBJECT / HOLDER',
      icon: Icons.person_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DataRow(label: 'Holder Name', value: credential.holderName),
          _divider(),
          _DataRow(label: 'Holder ID', value: credential.holderId),
        ],
      ),
    );
  }
}

// ─── POLICY CHECKS SECTION ────────────────────────────────────────────────────

class _PolicySection extends StatelessWidget {
  final VerificationResult result;

  const _PolicySection({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.policyChecks.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      title: 'SYSTEM & POLICY CHECKS',
      icon: Icons.rule_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: result.policyChecks.map((p) {
          final passed = p.passed;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  passed
                      ? Icons.check_circle_outline_rounded
                      : Icons.cancel_outlined,
                  size: 16,
                  color: passed ? AppColors.verifyingAccent : AppColors.revoked,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: passed
                              ? AppColors.textMuted
                              : AppColors.revoked,
                        ),
                      ),
                      if (p.note != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          p.note!,
                          style: AppTextStyles.bodyTiny.copyWith(
                            fontSize: 11,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHARED LAYOUT WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.verifyingAccent),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

class _DataColumn extends StatelessWidget {
  final String label;
  final String value;

  const _DataColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.bodyTiny.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: AppColors.textDim,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDate;

  const _DataRow({
    required this.label,
    required this.value,
    this.isDate = false,
  });

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDim,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDate ? (value == 'No Expiry' ? AppColors.revoked : AppColors.verifyingLight) : AppColors.text,
                fontStyle: isDate ? (value == 'No Expiry' ? FontStyle.italic : FontStyle.normal) : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _divider() => Container(
  height: 1,
  color: AppColors.border.withOpacity(0.5),
  margin: const EdgeInsets.symmetric(vertical: 4),
);

// ═════════════════════════════════════════════════════════════════════════════
//  EXPORT DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _ExportDialog extends StatefulWidget {
  final bool isValid;
  const _ExportDialog({required this.isValid});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  String _format = 'PDF';

  static const _kFormats = [
    (
      value: 'PDF',
      icon: Icons.picture_as_pdf_outlined,
      description: 'Formal compliance report',
      color: AppColors.verifyingAccent,
    ),
    (
      value: 'JSON',
      icon: Icons.code_rounded,
      description: 'Developer integration & API use',
      color: AppColors.verifyingAccent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Container(
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
                      color: AppColors.verifyingAccent.withOpacity(0.14),
                      border: Border.all(
                        color: AppColors.verifyingAccent.withOpacity(0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      size: 17,
                      color: AppColors.verifyingAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Verification Record',
                          style: AppTextStyles.navLabelActive.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Choose a format to export this record.',
                          style: AppTextStyles.bodyTiny.copyWith(
                            fontSize: 11,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Format options ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELECT FORMAT',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: AppColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._kFormats.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FormatOption(
                        value: f.value,
                        icon: f.icon,
                        description: f.description,
                        color: f.color,
                        selected: _format == f.value,
                        onTap: () => setState(() => _format = f.value),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Buttons ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                      icon: Icons.download_rounded,
                      label: 'Export as $_format',
                      backgroundColor: AppColors.verifyingAccent,
                      hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
                      onTap: () => Navigator.pop(context),
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

// ─── FORMAT OPTION ROW ────────────────────────────────────────────────────────

class _FormatOption extends StatefulWidget {
  final String value;
  final IconData icon;
  final String description;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FormatOption({
    required this.value,
    required this.icon,
    required this.description,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FormatOption> createState() => _FormatOptionState();
}

class _FormatOptionState extends State<_FormatOption> {
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: widget.selected
              ? widget.color.withOpacity(0.09)
              : _h
              ? AppColors.surfaceHover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.selected
                ? widget.color.withOpacity(0.4)
                : AppColors.border,
            width: widget.selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(widget.selected ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(widget.icon, size: 17, color: widget.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: widget.selected ? widget.color : AppColors.text,
                    ),
                  ),
                  Text(
                    widget.description,
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 11,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.selected)
              Icon(Icons.check_circle_rounded, size: 18, color: widget.color),
          ],
        ),
      ),
    ),
  );
}
