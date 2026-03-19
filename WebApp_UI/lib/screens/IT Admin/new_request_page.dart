// screens/issuer/request_new_capability_page.dart
//
// Request New Capability — 4-step wizard.
//   Step 1 — Select Capability
//   Step 2 — Provide Justification
//   Step 3 — Upload Supporting Documents
//   Step 4 — Review & Submit
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   import 'package:qportal_webapp/screens/issuer/request_new_capability_page.dart';
//
//   // Add route constant:
//   static const requestNewCapability = '/issue/settings/capabilities/new';
//
//   // In _buildPage():
//   case RouteName.requestNewCapability:
//     return RequestNewCapabilityPage(
//       onCancel:    () => _handleNavigate(RouteName.issuerCapabilities),
//       onReturnToRequests: () => _handleNavigate(RouteName.issuerCapabilities),
//     );
//
//   // In RequestCapabilitiesPage, wire the New Request button:
//   onTap: () => widget.onNewRequest?.call()
//   // and pass onNewRequest from app_shell.

import 'package:flutter/material.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
import 'package:qportal_webapp/components/stepper.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/app_button.dart';

// ─── CONSTANTS ────────────────────────────────────────────────────────────────

const _kStepLabels = [
  'Select Capability',
  'Justification',
  'Documents',
  'Review & Submit',
];

const _kCategories = [
  'University',
  'College',
  'School',
  'Government Agency',
  'Hospital',
  'Clinic',
  'Corporate',
  'Non-Profit',
  'Other',
];

const _kOptionalDocTypes = [
  'Trade License',
  'Accreditation Certificate',
  'Government Authorization Letter',
  'Other',
];

// Simulates the org's current capability. In production this comes from state/auth.
enum _CurrentCapability { issuer, verifier }

// ─── UPLOADED FILE MODEL ──────────────────────────────────────────────────────

class _UploadedFile {
  final String fileName;
  final bool
  isRequired; // true = formal letter, false = optional supporting doc
  final String docType; // label shown on review

  const _UploadedFile({
    required this.fileName,
    required this.isRequired,
    required this.docType,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class RequestNewCapabilityPage extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onReturnToRequests;

  const RequestNewCapabilityPage({
    super.key,
    required this.onCancel,
    required this.onReturnToRequests,
  });

  @override
  State<RequestNewCapabilityPage> createState() =>
      _RequestNewCapabilityPageState();
}

class _RequestNewCapabilityPageState extends State<RequestNewCapabilityPage> {
  int _step = 1;

  // ── Step 1 ────────────────────────────────────────────────────────────────
  // Org currently has Issuer access → requests Verifier, and vice versa.
  final _CurrentCapability _currentCap = _CurrentCapability.issuer;
  // No selection needed — there's only one option; we just confirm it.

  // ── Step 2 ────────────────────────────────────────────────────────────────
  String? _category;
  final _useCaseCtrl = TextEditingController();
  final _additionalCtrl = TextEditingController();
  bool _categoryError = false;
  bool _useCaseError = false;

  // ── Step 3 ────────────────────────────────────────────────────────────────
  _UploadedFile? _formalLetter;
  final List<_UploadedFile> _supportingDocs = [];
  bool _formalLetterError = false;
  bool _isDragOverFormal = false;
  bool _isDragOverOptional = false;

  // ── Step 4 ────────────────────────────────────────────────────────────────
  bool _submitting = false;
  bool _submitted = false;

  // ── helpers ───────────────────────────────────────────────────────────────

  String get _requestedCap => _currentCap == _CurrentCapability.issuer
      ? 'Verifier Access'
      : 'Issuer Access';

  bool _validateStep2() {
    setState(() {
      _categoryError = _category == null;
      _useCaseError = _useCaseCtrl.text.trim().isEmpty;
    });
    return !_categoryError && !_useCaseError;
  }

  bool _validateStep3() {
    setState(() => _formalLetterError = _formalLetter == null);
    return _formalLetter != null;
  }

  void _simulateFormalUpload(String name) => setState(
    () => _formalLetter = _UploadedFile(
      fileName: name,
      isRequired: true,
      docType: 'Formal Request Letter',
    ),
  );

  void _simulateOptionalUpload(String name, String type) {
    if (_supportingDocs.length >= 5) return;
    setState(
      () => _supportingDocs.add(
        _UploadedFile(fileName: name, isRequired: false, docType: type),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted)
      setState(() {
        _submitting = false;
        _submitted = true;
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
          // Page title
          Text(
            'Request New Capability',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),

          // Stepper
          IssuerStepStrip(
            currentStep: _step,
            stepLabels: _kStepLabels,
            accentColor: AppColors.adminAccent,
          ),
          const SizedBox(height: 12),

          // Step number
          Text(
            'Step $_step of ${_kStepLabels.length}',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textDim,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          // Step name
          Text(
            _kStepLabels[_step - 1],
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          // Step content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: KeyedSubtree(key: ValueKey(_step), child: _buildStep()),
            ),
          ),
          const SizedBox(height: 16),

          // Nav buttons
          _buildNavRow(),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      default:
        return _buildStep4();
    }
  }

  Widget _buildNavRow() {
    if (_step == 4 && _submitted) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppButton(
            label: 'Return to Requests',
            icon: Icons.arrow_back_rounded,
            onTap: widget.onReturnToRequests,
            showBorder: true,
            borderColor: AppColors.adminAccent,
          ),
        ],
      );
    }

    switch (_step) {
      case 1:
        return Row(
          children: [
            AppButton(label: 'Cancel', onTap: widget.onCancel, showBorder: false, backgroundColor: AppColors.revoked),
            const SizedBox(width: 10),
            AppButton(
              label: 'Next',
              backgroundColor: AppColors.adminAccent,
              hoverColor: AppColors.adminAccent.withOpacity(0.82),
              icon: Icons.arrow_forward_rounded,
              onTap: () => setState(() => _step = 2),
              iconRight: true,
            ),
          ],
        );
      case 2:
        return Row(
          children: [
            AppButton(
              label: 'Back',
              icon: Icons.arrow_back_rounded,
              onTap: () => setState(() => _step = 1),
              showBorder: true,
              borderColor: AppColors.border,
            ),
            const SizedBox(width: 10),
            AppButton(
              label: 'Next',
              backgroundColor: AppColors.adminAccent,
              hoverColor: AppColors.adminAccent.withOpacity(0.82),
              icon: Icons.arrow_forward_rounded,
              onTap: () {
                if (_validateStep2()) setState(() => _step = 3);
              },
              iconRight: true,
            ),
          ],
        );
      case 3:
        return Row(
          children: [
            AppButton(
              label: 'Back',
              icon: Icons.arrow_back_rounded,
              onTap: () => setState(() => _step = 2),
              showBorder: true,
              borderColor: AppColors.border,
            ),
            const SizedBox(width: 10),
            AppButton(
              label: 'Review',
              backgroundColor: AppColors.adminAccent,
              hoverColor: AppColors.adminAccent.withOpacity(0.82),
              icon: Icons.preview_outlined,
              onTap: () {
                if (_validateStep3()) setState(() => _step = 4);
              },
            ),
          ],
        );
      default: // step 4
        return Row(
          children: [
            AppButton(
              label: 'Back',
              icon: Icons.arrow_back_rounded,
              enabled: !_submitting && !_submitted,
              onTap: () => setState(() => _step = 3),
              showBorder: true,
              borderColor: AppColors.border,
            ),
            const SizedBox(width: 10),
            AppButton(
              label: 'Submit',
              backgroundColor: AppColors.adminAccent,
              hoverColor: AppColors.adminAccent.withOpacity(0.82),
              icon: Icons.send_outlined,
              enabled: !_submitting && !_submitted,
              onTap: _submit,
            ),
          ],
        );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STEP 1 — SELECT CAPABILITY
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep1() {
    return _Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current access info
            _InfoBox(
              icon: Icons.info_outline_rounded,
              color: AppColors.adminAccent,
              text:
                  'Your organisation currently has '
                  '${_currentCap == _CurrentCapability.issuer ? 'Issuer' : 'Verifier'} '
                  'access. You may request the additional capability below.',
            ),
            const SizedBox(height: 20),

            // Capability card — the one available option
            _CapabilityOption(
              icon: _currentCap == _CurrentCapability.issuer
                  ? Icons.fact_check_outlined
                  : Icons.workspace_premium_outlined,
              title: 'Request $_requestedCap',
              description: _currentCap == _CurrentCapability.issuer
                  ? 'Allow your organisation to verify credentials issued on the QPortal network.'
                  : 'Allow your organisation to issue digital credentials on the QPortal network.',
              accentColor: _currentCap == _CurrentCapability.issuer
                  ? AppColors.verifyingAccent
                  : AppColors.adminAccent,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STEP 2 — JUSTIFICATION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep2() {
    return _Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Organisation Category
            _FieldLabel(text: 'Organisation Category', required: true),
            const SizedBox(height: 7),
            _CategoryDropdown(
              value: _category,
              hasError: _categoryError,
              onChanged: (v) => setState(() {
                _category = v;
                _categoryError = false;
              }),
            ),
            if (_categoryError) ...[
              const SizedBox(height: 5),
              _ErrorRow('Please select an organisation category.'),
            ],
            const SizedBox(height: 20),

            // Use Case
            _FieldLabel(text: 'Use Case Description', required: true),
            const SizedBox(height: 7),
            _TextInput(
              controller: _useCaseCtrl,
              hint:
                  'Describe how your organisation intends to use this capability…',
              maxLines: 4,
              hasError: _useCaseError,
              onChanged: (_) => setState(() => _useCaseError = false),
            ),
            if (_useCaseError) ...[
              const SizedBox(height: 5),
              _ErrorRow('Use case description is required.'),
            ],
            const SizedBox(height: 20),

            // Additional Details
            _FieldLabel(text: 'Additional Details'),
            const SizedBox(height: 7),
            _TextInput(
              controller: _additionalCtrl,
              hint:
                  'Any additional context, references, or supporting information…',
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STEP 3 — UPLOAD DOCUMENTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep3() {
    return _Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Formal Letter (required) ─────────────────────────────────
            Row(
              children: [
                const Text(
                  'Formal Request Letter',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '*',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.revoked,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'A signed formal letter on official letterhead is required.',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                color: AppColors.textDim,
              ),
            ),
            const SizedBox(height: 10),

            _formalLetter != null
                ? _UploadedFileTile(
                    file: _formalLetter!,
                    onDelete: () => setState(() => _formalLetter = null),
                  )
                : _DropZone(
                    isDragOver: _isDragOverFormal,
                    hasError: _formalLetterError,
                    onEnter: () => setState(() => _isDragOverFormal = true),
                    onExit: () => setState(() => _isDragOverFormal = false),
                    onTap: () =>
                        _simulateFormalUpload('formal_request_letter.pdf'),
                    onBrowse: () => _simulateFormalUpload('formal_letter.pdf'),
                    onOneDrive: () =>
                        _simulateFormalUpload('formal_letter_od.pdf'),
                  ),
            if (_formalLetterError && _formalLetter == null) ...[
              const SizedBox(height: 6),
              _ErrorRow('The formal request letter is required.'),
            ],

            const SizedBox(height: 28),

            // ── Optional Supporting Docs ─────────────────────────────────
            const Text(
              'Supporting Documents (Optional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload additional documents such as a Trade License, '
              'Accreditation Certificate, Government Authorization Letter, or other.',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                color: AppColors.textDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),

            // Uploaded optional docs list
            if (_supportingDocs.isNotEmpty) ...[
              ..._supportingDocs.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _UploadedFileTile(
                    file: f,
                    onDelete: () => setState(() => _supportingDocs.remove(f)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Optional upload zone (hidden when 5 docs already uploaded)
            if (_supportingDocs.length < 5)
              _DropZone(
                isDragOver: _isDragOverOptional,
                hasError: false,
                onEnter: () => setState(() => _isDragOverOptional = true),
                onExit: () => setState(() => _isDragOverOptional = false),
                onTap: () => _showOptionalDocPicker(),
                onBrowse: () => _showOptionalDocPicker(),
                onOneDrive: () => _showOptionalDocPicker(),
              ),
          ],
        ),
      ),
    );
  }

  void _showOptionalDocPicker() {
    showDialog(
      context: context,
      builder: (_) => _DocTypePicker(
        onPick: (type) {
          final fileName = '${type.toLowerCase().replaceAll(' ', '_')}.pdf';
          _simulateOptionalUpload(fileName, type);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STEP 4 — REVIEW & SUBMIT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep4() {
    return _Card(
      child: _submitted
          ? _buildSubmitSuccess()
          : _submitting
          ? _buildSubmitting()
          : _buildReview(),
    );
  }

  Widget _buildReview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReviewSection(
            title: 'Capability Requested',
            rows: [
              _ReviewRow('Request Type', _requestedCap),
              _ReviewRow(
                'Current Access',
                _currentCap == _CurrentCapability.issuer
                    ? 'Issuer'
                    : 'Verifier',
              ),
            ],
          ),
          const SizedBox(height: 20),

          _ReviewSection(
            title: 'Organisation Information',
            rows: [_ReviewRow('Category', _category ?? '—')],
          ),
          const SizedBox(height: 20),

          _ReviewSection(
            title: 'Justification',
            rows: [
              _ReviewRow('Use Case', _useCaseCtrl.text.trim()),
              if (_additionalCtrl.text.trim().isNotEmpty)
                _ReviewRow('Additional Details', _additionalCtrl.text.trim()),
            ],
          ),
          const SizedBox(height: 20),

          _ReviewSection(
            title: 'Documents',
            rows: [
              if (_formalLetter != null)
                _ReviewRow(_formalLetter!.docType, _formalLetter!.fileName),
              ..._supportingDocs.map((f) => _ReviewRow(f.docType, f.fileName)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitting() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: AppColors.adminAccent,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 18),
          Text(
            'Submitting your request…',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.verifyingAccent.withOpacity(0.12),
                border: Border.all(
                  color: AppColors.verifyingAccent.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 30,
                color: AppColors.verifyingAccent,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Request Submitted',
              style: AppTextStyles.navLabelActive.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),

            Text(
              'Your request has been sent successfully.\n'
              'Request details have been sent to your email for follow-up.',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.65,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _useCaseCtrl.dispose();
    _additionalCtrl.dispose();
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DROP ZONE
// ═════════════════════════════════════════════════════════════════════════════

class _DropZone extends StatelessWidget {
  final bool isDragOver;
  final bool hasError;
  final VoidCallback onEnter;
  final VoidCallback onExit;
  final VoidCallback onTap;
  final VoidCallback onBrowse;
  final VoidCallback onOneDrive;

  const _DropZone({
    required this.isDragOver,
    required this.hasError,
    required this.onEnter,
    required this.onExit,
    required this.onTap,
    required this.onBrowse,
    required this.onOneDrive,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppColors.revoked
        : isDragOver
        ? AppColors.adminAccent
        : AppColors.border;

    return Column(
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => onEnter(),
          onExit: (_) => onExit(),
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                color: isDragOver
                    ? AppColors.adminAccent.withOpacity(0.04)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    size: 36,
                    color: isDragOver
                        ? AppColors.adminAccent
                        : AppColors.textDim,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Drag & drop your file here',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDragOver
                          ? AppColors.adminAccent
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Only PDF files are allowed.\n'
                    'Scanned documents are not accepted.\n'
                    'Maximum 1 file.',
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
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppButton(
              icon: Icons.folder_open_outlined,
              label: 'Browse from Computer',
              backgroundColor: AppColors.adminAccent,
              hoverColor: AppColors.adminAccent.withOpacity(0.82),
              onTap: onBrowse,
            ),
            const SizedBox(width: 10),
            AppButton(
              icon: Icons.cloud_outlined,
              label: 'Upload from OneDrive',
              backgroundColor: AppColors.adminAccent,
              hoverColor: AppColors.adminAccent.withOpacity(0.82),
              onTap: onOneDrive,
            ),
          ],
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  UPLOADED FILE TILE
// ═════════════════════════════════════════════════════════════════════════════

class _UploadedFileTile extends StatelessWidget {
  final _UploadedFile file;
  final VoidCallback onDelete;

  const _UploadedFileTile({required this.file, required this.onDelete});

  @override
  Widget build(BuildContext context) {
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${file.fileName} uploaded successfully',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),
          _DeleteBtn(onTap: onDelete),
        ],
      ),
    );
  }
}

// ─── DELETE BUTTON (inline) ───────────────────────────────────────────────────

class _DeleteBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _DeleteBtn({required this.onTap});

  @override
  State<_DeleteBtn> createState() => _DeleteBtnState();
}

class _DeleteBtnState extends State<_DeleteBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _h
              ? AppColors.revoked.withOpacity(0.18)
              : AppColors.revoked.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.delete_outline,
          size: 16,
          color: AppColors.revoked,
        ),
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  DOC TYPE PICKER DIALOG (optional supporting docs)
// ═════════════════════════════════════════════════════════════════════════════

class _DocTypePicker extends StatefulWidget {
  final void Function(String type) onPick;
  const _DocTypePicker({required this.onPick});

  @override
  State<_DocTypePicker> createState() => _DocTypePickerState();
}

class _DocTypePickerState extends State<_DocTypePicker> {
  String _type = _kOptionalDocTypes.first;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
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
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Document Type',
              style: AppTextStyles.navLabelActive.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceHover,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: AppColors.adminAccent.withOpacity(0.5),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _type,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E1E1E),
                  iconEnabledColor: AppColors.textDim,
                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                  items: _kOptionalDocTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _type = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                AppButton(
                  label: 'Cancel',
                  onTap: () => Navigator.pop(context),
                  backgroundColor: AppColors.revoked,
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Upload',
                  backgroundColor: AppColors.adminAccent,
                  hoverColor: AppColors.adminAccent.withOpacity(0.82),
                  icon: Icons.upload_file_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onPick(_type);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  REVIEW WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _ReviewSection extends StatelessWidget {
  final String title;
  final List<_ReviewRow> rows;

  const _ReviewSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.navLabelActive.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.adminLight,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceHover,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: rows
                .asMap()
                .entries
                .map(
                  (e) => Column(
                    children: [
                      e.value,
                      if (e.key < rows.length - 1)
                        Container(height: 1, color: AppColors.border),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
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
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                color: AppColors.text,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STEP 1 — CAPABILITY OPTION CARD
// ═════════════════════════════════════════════════════════════════════════════

class _CapabilityOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;

  const _CapabilityOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withOpacity(0.35), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withOpacity(0.3)),
            ),
            child: Icon(icon, size: 22, color: accentColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.check_circle_rounded, size: 20, color: accentColor),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ─── CARD ─────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    ),
  );
}

// ─── STEP HEADER ──────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final int step;
  final String label;
  const _StepHeader({required this.step, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.adminAccent.withOpacity(0.14),
          border: Border.all(color: AppColors.adminAccent.withOpacity(0.4)),
        ),
        child: Center(
          child: Text(
            '$step',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.adminLight,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        label,
        style: AppTextStyles.navLabelActive.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

// ─── FIELD LABEL ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel({required this.text, this.required = false});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        text,
        style: AppTextStyles.bodyTiny.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: AppColors.textMuted,
        ),
      ),
      if (required) ...[
        const SizedBox(width: 3),
        const Text(
          '*',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.revoked,
          ),
        ),
      ],
    ],
  );
}

// ─── CATEGORY DROPDOWN ────────────────────────────────────────────────────────

class _CategoryDropdown extends StatelessWidget {
  final String? value;
  final bool hasError;
  final void Function(String?) onChanged;

  const _CategoryDropdown({
    required this.value,
    required this.hasError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.surfaceHover,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(
        color: hasError
            ? AppColors.revoked
            : value != null
            ? AppColors.adminAccent.withOpacity(0.55)
            : AppColors.border,
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: const Color(0xFF1E1E1E),
        iconEnabledColor: AppColors.textDim,
        hint: Text(
          'Select a category…',
          style: AppTextStyles.bodyTiny.copyWith(
            fontSize: 12,
            color: AppColors.textDim,
          ),
        ),
        style: const TextStyle(fontSize: 13, color: AppColors.text),
        items: _kCategories
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

// ─── TEXT INPUT ───────────────────────────────────────────────────────────────

class _TextInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final bool hasError;
  final void Function(String)? onChanged;

  const _TextInput({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.hasError = false,
    this.onChanged,
  });

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
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
              ? AppColors.adminAccent.withOpacity(0.6)
              : AppColors.border,
          width: (_focused || widget.hasError) ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        maxLines: widget.maxLines,
        style: const TextStyle(fontSize: 13, color: AppColors.text),
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
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

// ─── INFO BOX ─────────────────────────────────────────────────────────────────

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoBox({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── ERROR ROW ────────────────────────────────────────────────────────────────

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
