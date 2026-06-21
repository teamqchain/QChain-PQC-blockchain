import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/toast.dart';
import 'package:qportal_webapp/models/VERIFIER/policy_model.dart';
import 'package:qportal_webapp/models/VERIFIER/verificationResult_model.dart';
import 'package:qportal_webapp/models/VERIFIER/verifyResult_enum.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class VerificationResultPage extends StatefulWidget {
  final VerificationResult result;
  final VoidCallback onVerifyAnother;

  const VerificationResultPage({
    super.key,
    required this.result,
    required this.onVerifyAnother,
  });

  @override
  State<VerificationResultPage> createState() => _VerificationResultPageState();
}

class _VerificationResultPageState extends State<VerificationResultPage> {
  // Processing state lasts 1–3 s before the result is shown.
  bool _processing = true;

  // Receipt toast overlay entry
  OverlayEntry? _toastEntry;

  @override
  void initState() {
    super.initState();
    // Simulate 2-second blockchain verification delay.
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _processing = false);
    });
  }

  // ── Save Receipt ──────────────────────────────────────────────────────────

  void _saveReceipt() {
    _toastEntry?.remove();
    _toastEntry = OverlayEntry(
      builder: (_) => Toast(
        message: 'Receipt saved to OneDrive',
        onDone: () {
          _toastEntry?.remove();
          _toastEntry = null;
        },
        bgColor: AppColors.valid,
        iconColor: AppColors.text,
        toastIcons: Icons.cloud_done_outlined,
      ),
    );
    Overlay.of(context).insert(_toastEntry!);
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title
          Text(
            _processing ? 'Verifying…' : 'Verification Result',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // Main container
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

          if (!_processing) ...[const SizedBox(height: 16), _buildActions()],
        ],
      ),
    );
  }

  // ─── PROCESSING ────────────────────────────────────────────────────────────

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

  // ─── RESULT ────────────────────────────────────────────────────────────────

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

  // ─── ACTION BAR ────────────────────────────────────────────────────────────

  Widget _buildActions() {
    final bool isValid = widget.result.isValid;

    return Row(
      children: [
        AppButton(
          label: 'Save Receipt',
          icon: Icons.save_outlined,
          backgroundColor: isValid
              ? AppColors.verifyingAccent
              : Colors.transparent,
          hoverColor: isValid
              ? AppColors.verifyingAccent.withOpacity(0.82)
              : AppColors.surfaceHover,
          showBorder: !isValid,
          borderColor: AppColors.border.withOpacity(0.5),
          textColor: isValid ? Colors.white : AppColors.textDim,
          iconColor: isValid ? Colors.white : AppColors.textDim,
          enabled: isValid,
          tooltip: isValid
              ? null
              : 'Receipt cannot be saved for invalid credentials',
          onTap: _saveReceipt,
        ),
        const SizedBox(width: 10),
        AppButton(
          label: 'Verify Another',
          icon: Icons.qr_code_scanner_rounded,
          showBorder: true,
          borderColor: AppColors.verifyingAccent.withOpacity(0.5),
          textColor: AppColors.verifyingLight,
          iconColor: AppColors.verifyingLight,
          hoverColor: AppColors.verifyingAccent.withOpacity(0.08),
          onTap: widget.onVerifyAnother,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _toastEntry?.remove();
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CERTIFICATE CARD
// ═════════════════════════════════════════════════════════════════════════════

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
          // Status header
          _StatusHeader(verifyResult: verifyResult, accent: accent),

          // Card body
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
          child: Icon(verifyResult.headerIcon, size: 18, color: accent),
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

// ═════════════════════════════════════════════════════════════════════════════
//  VALID BODY
// ═════════════════════════════════════════════════════════════════════════════

class _ValidBody extends StatelessWidget {
  final VerificationResult result;

  const _ValidBody({required this.result});

  @override
  Widget build(BuildContext context) {
    final c = result.credential!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Credential name + type
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

        // Details grid
        _Row('Credential ID', c.id),
        _Row('Holder Name', c.holderName),
        _Row('Holder ID', c.holderId),
        // IssuedByRow(org: c.issuerOrg,),
        _Row('Issue Date', c.issueDate),
        _Row('Expiry Date', c.expiryDate ?? 'No expiry'),

        // Policy checks
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

// ═════════════════════════════════════════════════════════════════════════════
//  INVALID BODY
// ═════════════════════════════════════════════════════════════════════════════

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
        _Row('Issued By', c.issuedBy),
        _Row('Issue Date', c.issueDate),
        if (c.expiryDate != null) _Row('Expiry Date', c.expiryDate!),
      ],
    );
  }
}



// ═════════════════════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

Widget _divider() =>
    Container(height: 1, color: AppColors.border.withOpacity(0.6));

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
