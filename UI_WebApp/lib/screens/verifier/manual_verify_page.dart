// screens/verifier/manual_verify_page.dart
//
// Manual Verify — three modes: Credential ID, OTP, Upload Document.
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   import 'package:qportal_webapp/screens/verifier/manual_verify_page.dart';
//   import 'package:qportal_webapp/models/verifying_models.dart';
//
//   case RouteName.manualVerify:
//     return ManualVerifyPage(
//       onBack: () => _handleNavigate(RouteName.dashboard),
//       onVerify: (result) {
//         _selectedVerificationResult = result;
//         _handleNavigate(RouteName.verificationResult);
//       },
//     );
//
//   // Add _selectedVerificationResult to _AppShellState and pass it into
//   // VerificationResultPage just as _selectedCredentialId is used for credentials.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qportal_webapp/components/label.dart';
import 'package:qportal_webapp/models/verifiying_models.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/app_button.dart';

// ─── VERIFICATION MODE ────────────────────────────────────────────────────────

enum _VerifyMode { credentialId, otp, document }

enum _DocProcessing { none, reading, verifying, failed }

extension _VerifyModeX on _VerifyMode {
  String get label {
    switch (this) {
      case _VerifyMode.credentialId:
        return 'Credential ID';
      case _VerifyMode.otp:
        return 'OTP';
      case _VerifyMode.document:
        return 'Upload Document';
    }
  }

  IconData get icon {
    switch (this) {
      case _VerifyMode.credentialId:
        return Icons.badge_outlined;
      case _VerifyMode.otp:
        return Icons.pin_outlined;
      case _VerifyMode.document:
        return Icons.upload_file_outlined;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class ManualVerifyPage extends StatefulWidget {
  final VoidCallback onBack;

  /// Called with a [VerificationResult] when the verifier presses Verify.
  /// The caller should navigate to VerificationResultPage passing this result.
  final void Function(VerificationResult result) onVerify;

  /// Called when the user taps "Manage Policies".
  final VoidCallback onManagePolicies;

  const ManualVerifyPage({
    super.key,
    required this.onBack,
    required this.onVerify,
    required this.onManagePolicies,
  });

  @override
  State<ManualVerifyPage> createState() => _ManualVerifyPageState();
}

class _ManualVerifyPageState extends State<ManualVerifyPage> {
  _VerifyMode _mode = _VerifyMode.credentialId;

  // ── Mode 1 ────────────────────────────────────────────────────────────────
  final _credIdCtrl = TextEditingController();
  bool _credIdError = false;

  // ── Mode 2 ────────────────────────────────────────────────────────────────
  final _otpCtrl = TextEditingController();
  bool _otpError = false;

  // ── Mode 3 ────────────────────────────────────────────────────────────────
  bool _fileUploaded = false;
  String _uploadedFileName = '';
  bool _isDragOver = false;
  bool _fileError = false;

  // Document processing state
  _DocProcessing _docState = _DocProcessing.none;

  // ── Verify ────────────────────────────────────────────────────────────────

  void _verify() {
    // Document mode handles its own flow via _startDocumentProcessing.
    if (_mode == _VerifyMode.document) {
      if (!_fileUploaded) {
        setState(() => _fileError = true);
        return;
      }
      _startDocumentProcessing();
      return;
    }

    // Validate inputs for the active mode.
    switch (_mode) {
      case _VerifyMode.credentialId:
        if (_credIdCtrl.text.trim().isEmpty) {
          setState(() => _credIdError = true);
          return;
        }
        break;
      case _VerifyMode.otp:
        if (_otpCtrl.text.trim().isEmpty) {
          setState(() => _otpError = true);
          return;
        }
        break;
      default:
        break;
    }

    // Simulate a lookup — return a mock result.
    // In production this calls the blockchain / API layer.
    widget.onVerify(VerifyingMockData.tampered());
  }

  /// Starts the document verification processing sequence (success path).
  void _startDocumentProcessing() {
    setState(() => _docState = _DocProcessing.reading);

    // Step 1: "Reading file..." (1.2s)
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _docState = _DocProcessing.verifying);

      // Step 2: "Verifying against blockchain..." (1.5s)
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() => _docState = _DocProcessing.none);
        widget.onVerify(VerifyingMockData.valid());
      });
    });
  }

  /// Simulates a document that cannot be read.
  void _startDocumentProcessingFail() {
    setState(() => _docState = _DocProcessing.reading);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _docState = _DocProcessing.failed);
    });
  }

  void _docTryAgain() {
    setState(() {
      _docState = _DocProcessing.none;
      _fileUploaded = false;
      _uploadedFileName = '';
    });
  }

  void _simulateUpload(String name) => setState(() {
    _fileUploaded = true;
    _uploadedFileName = name;
    _fileError = false;
  });

  void _removeFile() => setState(() {
    _fileUploaded = false;
    _uploadedFileName = '';
  });

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
            'Manual Verify',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // Tab switcher
          _ModeSelector(
            selected: _mode,
            onSelect: (m) => setState(() => _mode = m),
          ),
          const SizedBox(height: 14),

          // Content container
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: KeyedSubtree(
                        key: ValueKey(_mode),
                        child: _buildContent(),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 12,
                  child: AppButton(
                    label: 'Manage Policies',
                    icon: Icons.policy_outlined,
                    showBorder: true,
                    borderColor: AppColors.verifyingAccent.withOpacity(0.4),
                    textColor: AppColors.verifyingAccent,
                    iconColor: AppColors.verifyingAccent,
                    hoverColor: AppColors.verifyingAccent.withOpacity(0.08),
                    onTap: widget.onManagePolicies,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              AppButton(
                label: 'Back',
                icon: Icons.arrow_back_rounded,
                showBorder: true,
                borderColor: AppColors.border,
                onTap: widget.onBack,
              ),
              const SizedBox(width: 10),
              _docState == _DocProcessing.failed
                  ? AppButton(
                      label: 'Try Again',
                      icon: Icons.refresh_rounded,
                      backgroundColor: AppColors.revoked.withOpacity(0.15),
                      hoverColor: AppColors.revoked.withOpacity(0.25),
                      textColor: AppColors.revoked,
                      iconColor: AppColors.revoked,
                      showBorder: true,
                      borderColor: AppColors.revoked.withOpacity(0.35),
                      onTap: _docTryAgain,
                    )
                  : AppButton(
                      label: 'Verify',
                      icon: Icons.verified_outlined,
                      backgroundColor: AppColors.verifyingAccent,
                      hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
                      onTap: _verify,
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_mode) {
      case _VerifyMode.credentialId:
        return _buildCredentialIdMode();
      case _VerifyMode.otp:
        return _buildOtpMode();
      case _VerifyMode.document:
        return _buildDocumentMode();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MODE 1 — CREDENTIAL ID
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCredentialIdMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input section
          Label(text: 'Enter Credential ID', required: true,),
          const SizedBox(height: 8),
          _InputField(
            controller: _credIdCtrl,
            hint: 'e.g. QC-2025-007192',
            hasError: _credIdError,
            onChanged: (_) => setState(() => _credIdError = false),
          ),
          if (_credIdError) ...[
            const SizedBox(height: 5),
            _ErrorRow('Please enter a Credential ID.'),
          ],
          const SizedBox(height: 28),

          // Instructions
          _InstructionCard(
            title: 'How to find the Credential ID',
            subtitle:
                'Guide the credential holder to locate the Credential ID using these steps:',
            steps: const [
              'Open the QWallet app',
              'Go to the Wallet tab',
              'Locate the credential based on its category',
              'Click Details to find the Credential ID',
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MODE 2 — OTP
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildOtpMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input section
          Label(text: 'Enter OTP', required: true,),
          const SizedBox(height: 8),
          _InputField(
            controller: _otpCtrl,
            hint: 'Enter 6-digit OTP',
            hasError: _otpError,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (_) => setState(() => _otpError = false),
          ),
          if (_otpError) ...[
            const SizedBox(height: 5),
            _ErrorRow('Please enter the OTP code.'),
          ],
          const SizedBox(height: 28),

          // Instructions
          _InstructionCard(
            title: 'How to generate an OTP',
            subtitle:
                'Ask the credential holder to generate a one-time password using these steps:',
            steps: const [
              'Open the QWallet app',
              'Go to the Wallet tab',
              'Locate the credential based on its category',
              'Click Details to open the credential information',
              'Scroll to the bottom of the page',
              'Click Generate OTP',
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MODE 3 — UPLOAD DOCUMENT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDocumentMode() {
    // Processing / failed states take over the whole content area.
    if (_docState == _DocProcessing.reading ||
        _docState == _DocProcessing.verifying) {
      return _buildDocProcessing();
    }
    if (_docState == _DocProcessing.failed) {
      return _buildDocFailed();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: _fileUploaded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUploadedFile(),
                _buildUploadedFileActions(),
              ],
            )
          : _buildDropZone(),
    );
  }

  Widget _buildDocProcessing() {
    final bool isReading = _docState == _DocProcessing.reading;
    return Center(
      key: ValueKey(_docState),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: AppColors.verifyingAccent,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isReading ? 'Reading file...' : 'Verifying against blockchain...',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocFailed() {
    return Center(
      key: const ValueKey('doc-failed'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.revoked.withOpacity(0.12),
                border: Border.all(
                  color: AppColors.revoked.withOpacity(0.35),
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 24,
                color: AppColors.revoked,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Could not read credential',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.revoked,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We could not read this as a QChain credential. Make sure the '
              'file was exported from QWallet or the QChain Portal directly.',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                color: AppColors.textDim,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isDragOver = true),
          onExit: (_) => setState(() => _isDragOver = false),
          child: GestureDetector(
            onTap: () => _simulateUpload('credential_document.pdf'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 44),
              decoration: BoxDecoration(
                color: _fileError
                    ? AppColors.revoked.withOpacity(0.03)
                    : _isDragOver
                    ? AppColors.verifyingAccent.withOpacity(0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: _fileError
                      ? AppColors.revoked.withOpacity(0.5)
                      : _isDragOver
                      ? AppColors.verifyingAccent
                      : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    size: 40,
                    color: _fileError
                        ? AppColors.revoked.withOpacity(0.55)
                        : _isDragOver
                        ? AppColors.verifyingAccent
                        : AppColors.textDim,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Drag & drop your credential file here',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isDragOver
                          ? AppColors.verifyingAccent
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Only PDF files are accepted.\n'
                    'Maximum 1 file allowed.',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 11,
                      color: AppColors.textDim,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_fileError) ...[
          const SizedBox(height: 6),
          _ErrorRow('Please upload a credential document to verify.'),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppButton(
              icon: Icons.folder_open_outlined,
              label: 'Browse from Computer',
              backgroundColor: AppColors.verifyingAccent,
              hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
              onTap: () => _simulateUpload('credential_document.pdf'),
            ),
            const SizedBox(width: 10),
            AppButton(
              icon: Icons.cloud_outlined,
              label: 'Upload from OneDrive',
              backgroundColor: AppColors.verifyingAccent,
              hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
              onTap: () => _simulateUpload('credential_od.pdf'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUploadedFile() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1A),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.5),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle,
              size: 20,
              color: Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _uploadedFileName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'File uploaded successfully',
                  style: TextStyle(fontSize: 10, color: Color(0xFF4CAF50)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _removeFile,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadedFileActions() {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _startDocumentProcessingFail,
              child: Text(
                'Simulate unsuccessful read',
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 10,
                  color: AppColors.revoked.withOpacity(0.5),
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.revoked.withOpacity(0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _credIdCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  MODE SELECTOR (tab strip)
// ═════════════════════════════════════════════════════════════════════════════

class _ModeSelector extends StatelessWidget {
  final _VerifyMode selected;
  final void Function(_VerifyMode) onSelect;

  const _ModeSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: _VerifyMode.values
            .map(
              (m) => Expanded(
                child: _ModeTab(
                  mode: m,
                  selected: m == selected,
                  onTap: () => onSelect(m),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ModeTab extends StatefulWidget {
  final _VerifyMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ModeTab> createState() => _ModeTabState();
}

class _ModeTabState extends State<_ModeTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color accent = AppColors.verifyingAccent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: widget.selected
                ? accent.withOpacity(0.12)
                : _hovered
                ? AppColors.surfaceHover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: widget.selected
                ? Border.all(color: accent.withOpacity(0.3))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.mode.icon,
                size: 14,
                color: widget.selected ? accent : AppColors.textDim,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  widget.mode.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: widget.selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: widget.selected ? accent : AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  INSTRUCTION CARD
// ═════════════════════════════════════════════════════════════════════════════

class _InstructionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> steps;

  const _InstructionCard({
    required this.title,
    required this.subtitle,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.verifyingAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.verifyingAccent.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppColors.verifyingAccent,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.verifyingLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 11,
              color: AppColors.textDim,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Numbered steps
          ...steps.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step number badge
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.verifyingAccent.withOpacity(0.14),
                      border: Border.all(
                        color: AppColors.verifyingAccent.withOpacity(0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.verifyingLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        e.value,
                        style: AppTextStyles.bodyTiny.copyWith(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// class _FieldLabel extends StatelessWidget {
//   final String text;
//   const _FieldLabel(this.text);

//   @override
//   Widget build(BuildContext context) => Text(
//     text,
//     style: AppTextStyles.bodyTiny.copyWith(
//       fontSize: 11,
//       fontWeight: FontWeight.w700,
//       letterSpacing: 0.2,
//       color: AppColors.textMuted,
//     ),
//   );
// }

class _InputField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final bool hasError;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onChanged;

  const _InputField({
    required this.controller,
    required this.hint,
    this.hasError = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (v) => setState(() => _focused = v),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: widget.hasError
              ? AppColors.revoked
              : _focused
              ? AppColors.verifyingAccent.withOpacity(0.6)
              : AppColors.border,
          width: (widget.hasError || _focused) ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        style: const TextStyle(fontSize: 13, color: AppColors.text),
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: InputBorder.none,
          hintText: widget.hint,
          hintStyle: AppTextStyles.bodyTiny.copyWith(
            fontSize: 12,
            color: AppColors.textDim,
          ),
        ),
      ),
    ),
  );
}

class _ErrorRow extends StatelessWidget {
  final String text;
  const _ErrorRow(this.text);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.error_outline, size: 12, color: AppColors.revoked),
      const SizedBox(width: 5),
      Text(
        text,
        style: const TextStyle(fontSize: 11, color: AppColors.revoked),
      ),
    ],
  );
}
