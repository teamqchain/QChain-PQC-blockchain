// screens/verifier/verification_detail_page.dart
//
// Verification Details — shows the full verification result for a record
// selected from the Verification History page.
//
// Everything is identical to verification_result_page.dart (result_page.dart)
// EXCEPT the two action buttons:
//   • "Save Receipt"  →  replaced by "Back"   (returns to history)
//   • "Verify Another" →  replaced by "Export" (opens PDF / JSON dialog)
//
// ── Integration in app_shell.dart ────────────────────────────────────────────
//   import 'package:qportal_webapp/screens/verifier/verification_detail_page.dart';
//   import 'package:qportal_webapp/models/verifying_models.dart';
//
//   case RouteName.verificationDetail:
//     return VerificationDetailPage(
//       result: _selectedVerificationResult ?? VerifyingMockData.valid(),
//       onBack: () => _handleNavigate(RouteName.verificationHistory),
//     );

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/models/verifiying_models.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/app_button.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class VerificationDetailPage extends StatefulWidget {
  final VerificationResult result;
  final VoidCallback onBack;

  const VerificationDetailPage({
    super.key,
    required this.result,
    required this.onBack,
  });

  @override
  State<VerificationDetailPage> createState() => _VerificationDetailPageState();
}

class _VerificationDetailPageState extends State<VerificationDetailPage> {
  // Identical to result_page.dart — processing spinner shown for 2 s.
  bool _processing = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _processing = false);
    });
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title — identical to result_page.dart
          Text(
            _processing ? 'Verifying…' : 'Verification Details',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // Main container — identical to result_page.dart
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _processing ? _buildProcessing() : _buildResult(),
              ),
            ),
          ),

          // Action buttons — only shown after processing, CHANGED vs result_page
          if (!_processing) ...[const SizedBox(height: 16), _buildActions()],
        ],
      ),
    );
  }

  // ─── PROCESSING ─────────────────────────────────────────────────────────────
  // Identical to result_page.dart.

  Widget _buildProcessing() {
    return const Center(
      key: ValueKey('processing'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            'Verifying on blockchain...',
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

  // ─── RESULT ─────────────────────────────────────────────────────────────────
  // Identical to result_page.dart.

  Widget _buildResult() {
    return SingleChildScrollView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _CertCard(result: widget.result),
        ),
      ),
    );
  }

  // ─── ACTION BAR ─────────────────────────────────────────────────────────────
  // CHANGED: "Save Receipt" → "Back",  "Verify Another" → "Export"

  Widget _buildActions() {
    return Row(
      children: [
        // Back button
        AppButton(
          icon: Icons.arrow_back_rounded,
          label: 'Back',
          showBorder: true,
          borderColor: AppColors.border,
          hoverColor: AppColors.surfaceHover,
          onTap: widget.onBack,
        ),
        const SizedBox(width: 10),

        // Export button — opens format picker dialog
        AppButton(
          icon: Icons.download_rounded,
          label: 'Export',
          showBorder: true,
          borderColor: AppColors.verifyingAccent.withOpacity(0.5),
          textColor: AppColors.verifyingLight,
          iconColor: AppColors.verifyingLight,
          hoverColor: AppColors.verifyingAccent.withOpacity(0.08),
          onTap: _showExportDialog,
        ),
      ],
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (_) => _ExportDialog(isValid: widget.result.isValid),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

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
            // Icon box
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
            // Label + description
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
            // Checkmark when selected
            if (widget.selected)
              Icon(Icons.check_circle_rounded, size: 18, color: widget.color),
          ],
        ),
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  ALL WIDGETS BELOW ARE IDENTICAL TO result_page.dart
//  (copied verbatim — no modifications)
// ═════════════════════════════════════════════════════════════════════════════

// ─── CERTIFICATE CARD ─────────────────────────────────────────────────────────

class _CertCard extends StatelessWidget {
  final VerificationResult result;

  const _CertCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final verifyResult = result.toVerifyResult();
    final Color accent = verifyResult.fg;
    final Color accentBg = verifyResult.bg;

    return Container(
      decoration: BoxDecoration(
        color: accentBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.07),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusHeader(verifyResult: verifyResult, accent: accent),
          Padding(
            padding: const EdgeInsets.all(22),
            child: result.isValid
                ? _ValidBody(result: result)
                : _InvalidBody(result: result, accent: accent),
          ),
        ],
      ),
    );
  }
}

// ─── STATUS HEADER ────────────────────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  final VerifyResult verifyResult;
  final Color accent;

  const _StatusHeader({required this.verifyResult, required this.accent});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    color: accent.withOpacity(0.14),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withOpacity(0.18),
            border: Border.all(color: accent.withOpacity(0.5)),
          ),
          child: Icon(
            verifyResult.headerIcon,
            size: 18,
            color: accent,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          verifyResult.headerLabel,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: accent,
            letterSpacing: 1.2,
          ),
        ),
      ],
    ),
  );
}

// ─── VALID BODY ───────────────────────────────────────────────────────────────

class _ValidBody extends StatelessWidget {
  final VerificationResult result;

  const _ValidBody({required this.result});

  @override
  Widget build(BuildContext context) {
    final c = result.credential!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          c.credentialType,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          c.category,
          style: AppTextStyles.bodyTiny.copyWith(
            fontSize: 11,
            color: AppColors.textDim,
          ),
        ),
        const SizedBox(height: 20),
        _divider(),
        const SizedBox(height: 16),

        _Row('Credential ID', c.id),
        _Row('Holder Name', c.holderName),
        _Row('Holder ID', c.holderId),
        IssuedByRow(org: c.issuerOrg),
        _Row('Issue Date', c.issueDate),
        _Row('Expiry Date', c.expiryDate ?? 'No expiry'),

        if (result.policyChecks.isNotEmpty) ...[
          const SizedBox(height: 16),
          _divider(),
          const SizedBox(height: 14),
          const Text(
            'POLICY CHECKS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.textDim,
            ),
          ),
          const SizedBox(height: 10),
          ...result.policyChecks.map((p) => _PolicyRow(check: p)),
        ],
      ],
    );
  }
}

// ─── INVALID BODY ─────────────────────────────────────────────────────────────

class _InvalidBody extends StatelessWidget {
  final VerificationResult result;
  final Color accent;

  const _InvalidBody({required this.result, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReasonBox(),
        const SizedBox(height: 20),
        _divider(),
        const SizedBox(height: 16),
        if (result.credential != null) _buildCredentialDetails(),
      ],
    );
  }

  Widget _buildReasonBox() {
    final String message;
    final IconData icon;
    final c = result.credential;

    switch (result.invalidReason) {
      case InvalidReason.revoked:
        icon = Icons.block_rounded;
        message =
            'Revoked on ${c?.revokedDate ?? '—'}.'
            '${c?.revokedReason != null ? '\nReason: ${c!.revokedReason}' : ''}';
        break;
      case InvalidReason.expired:
        icon = Icons.schedule_rounded;
        message =
            'Expired on ${c?.expiryDate ?? '—'}. '
            'Ask holder to get it renewed.';
        break;
      case InvalidReason.suspended:
        icon = Icons.pause_circle_outline_rounded;
        message =
            'Temporarily suspended until ${c?.suspendedUntil ?? '—'}.'
            '${c?.suspendedReason != null ? '\nReason: ${c!.suspendedReason}' : ''}';
        break;
      case InvalidReason.tampered:
        icon = Icons.warning_amber_rounded;
        message =
            'Credential data does not match the blockchain record. '
            'This credential may have been modified. Do not accept.';
        break;
      case InvalidReason.notFound:
        icon = Icons.search_off_rounded;
        message = 'This credential was not found on the QChain network.';
        break;
      default:
        icon = Icons.error_outline_rounded;
        message = 'Unknown error.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accent,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialDetails() {
    final c = result.credential!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          c.credentialType,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          c.category,
          style: AppTextStyles.bodyTiny.copyWith(
            fontSize: 11,
            color: AppColors.textDim,
          ),
        ),
        const SizedBox(height: 12),
        _Row('Credential ID', c.id),
        _Row('Holder Name', c.holderName),
        _Row('Holder ID', c.holderId),
        IssuedByRow(org: c.issuerOrg, person: c.issuedBy),
        _Row('Issue Date', c.issueDate),
        if (c.expiryDate != null) _Row('Expiry Date', c.expiryDate!),
      ],
    );
  }
}

// ─── SHARED SMALL WIDGETS ─────────────────────────────────────────────────────

Widget _divider() =>
    Container(height: 1, color: AppColors.border.withOpacity(0.6));

class IssuedByRow extends StatelessWidget {
  final String org;
  final String? person;
  const IssuedByRow({required this.org, this.person});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            'Issued By',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textDim,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                org,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textDim,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.text,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PolicyRow extends StatelessWidget {
  final PolicyCheck check;
  const _PolicyRow({required this.check});

  @override
  Widget build(BuildContext context) {
    final Color c = check.passed
        ? AppColors.verifyingAccent
        : AppColors.revoked;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(
            check.passed
                ? Icons.check_circle_outline_rounded
                : Icons.cancel_outlined,
            size: 14,
            color: c,
          ),
          const SizedBox(width: 8),
          Text(
            check.label,
            style: TextStyle(
              fontSize: 12,
              color: check.passed ? AppColors.textMuted : AppColors.revoked,
            ),
          ),
          if (check.note != null) ...[
            const SizedBox(width: 6),
            Text(
              '· ${check.note}',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 10,
                color: AppColors.textDim,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
