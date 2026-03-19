// screens/verifier/batch_verify_page.dart
//
// Batch Verify — 4-step wizard.
//   Step 1 — Download Template & Upload File
//   Step 2 — Preview & Validate
//   Step 3 — Verify All  (progress bar)
//   Step 4 — Verification Results (table + filters + export)
//
// UI structure, helpers, and sub-widgets mirror issue_batch_credential_page.dart
// exactly. Only verification-specific content is changed.
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   import 'package:qportal_webapp/screens/verifier/batch_verify_page.dart';
//
//   case RouteName.batchVerify:
//     return BatchVerifyPage(
//       onCancel:        () => _handleNavigate(RouteName.dashboard),
//       onVerifyAnother: () => _handleNavigate(RouteName.batchVerify),
//     );

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/filterButton.dart';
import 'package:qportal_webapp/components/searchBar.dart';
import 'package:qportal_webapp/components/stepper.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/app_button.dart';

// ─── CONSTANTS ────────────────────────────────────────────────────────────────

const _kTotalSteps = 4;

const _kStepLabels = [
  'Upload File',
  'Validate & Preview',
  'Verify All',
  'Results',
];

/// Columns required in the verification template.
/// Issuer is optional; everything else is required.
const _kTemplateColumns = [
  'Credential ID',
  'Holder Name',
  'Holder ID',
  'Credential Type',
  'Issuer', // optional
];

const _kAccent = AppColors.verifyingAccent;

// ─── VERIFICATION OUTCOME ─────────────────────────────────────────────────────

enum _VerifyOutcome { valid, revoked, suspended, expired, invalid }

extension _VerifyOutcomeX on _VerifyOutcome {
  String get label {
    switch (this) {
      case _VerifyOutcome.valid:
        return 'VALID';
      case _VerifyOutcome.revoked:
        return 'REVOKED';
      case _VerifyOutcome.suspended:
        return 'SUSPENDED';
      case _VerifyOutcome.expired:
        return 'EXPIRED';
      case _VerifyOutcome.invalid:
        return 'INVALID';
    }
  }

  Color get color {
    switch (this) {
      case _VerifyOutcome.valid:
        return AppColors.verifyingAccent;
      case _VerifyOutcome.revoked:
        return AppColors.revoked;
      case _VerifyOutcome.suspended:
        return AppColors.suspended;
      case _VerifyOutcome.expired:
        return AppColors.expired;
      case _VerifyOutcome.invalid:
        return AppColors.revoked;
    }
  }

  Color get rowTint {
    switch (this) {
      case _VerifyOutcome.valid:
        return AppColors.verifyingAccent.withOpacity(0.04);
      case _VerifyOutcome.revoked:
        return AppColors.revoked.withOpacity(0.05);
      case _VerifyOutcome.suspended:
        return AppColors.suspended.withOpacity(0.05);
      case _VerifyOutcome.expired:
        return AppColors.expired.withOpacity(0.04);
      case _VerifyOutcome.invalid:
        return AppColors.revoked.withOpacity(0.05);
    }
  }
}

// ─── RESULT ROW MODEL ────────────────────────────────────────────────────────

class _VerifyResult {
  final String credentialId;
  final String holderName;
  final String credentialType;
  final String issuer;
  final _VerifyOutcome outcome;
  final String reason;

  const _VerifyResult({
    required this.credentialId,
    required this.holderName,
    required this.credentialType,
    required this.issuer,
    required this.outcome,
    required this.reason,
  });
}

// ─── MOCK RESULT GENERATOR ────────────────────────────────────────────────────

List<_VerifyResult> _buildMockResults(List<BatchRow> validRows) {
  final cycle = [
    _VerifyOutcome.valid,
    _VerifyOutcome.valid,
    _VerifyOutcome.valid,
    _VerifyOutcome.revoked,
    _VerifyOutcome.suspended,
    _VerifyOutcome.expired,
    _VerifyOutcome.invalid,
  ];
  const reasons = {
    _VerifyOutcome.valid: '—',
    _VerifyOutcome.revoked: 'Disciplinary action — revoked 10 May 2025',
    _VerifyOutcome.suspended: 'Under audit review until 30 Apr 2026',
    _VerifyOutcome.expired: 'Expired 01 Jan 2026 — renewal required',
    _VerifyOutcome.invalid: 'Credential data does not match blockchain record',
  };

  return List.generate(validRows.length, (i) {
    final outcome = cycle[i % cycle.length];
    final row = validRows[i];
    return _VerifyResult(
      credentialId: row.holderId,
      holderName: row.holderName,
      credentialType: row.fields['Degree Title'] ?? 'BSc Degree',
      issuer: 'University of Sharjah',
      outcome: outcome,
      reason: reasons[outcome]!,
    );
  });
}

// ─── RESULT FILTER ────────────────────────────────────────────────────────────

enum _ResultFilter { all, validOnly, invalidOnly, needsAttention }

extension _ResultFilterX on _ResultFilter {
  String get label {
    switch (this) {
      case _ResultFilter.all:
        return 'All';
      case _ResultFilter.validOnly:
        return 'Valid Only';
      case _ResultFilter.invalidOnly:
        return 'Invalid Only';
      case _ResultFilter.needsAttention:
        return 'Needs Attention';
    }
  }

  bool matches(_VerifyOutcome o) {
    switch (this) {
      case _ResultFilter.all:
        return true;
      case _ResultFilter.validOnly:
        return o == _VerifyOutcome.valid;
      case _ResultFilter.invalidOnly:
        return o == _VerifyOutcome.revoked || o == _VerifyOutcome.invalid;
      case _ResultFilter.needsAttention:
        return o == _VerifyOutcome.suspended || o == _VerifyOutcome.expired;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class BatchVerifyPage extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onVerifyAnother;

  /// Called when the user taps "Manage Policies".
  final VoidCallback onManagePolicies;

  const BatchVerifyPage({
    super.key,
    required this.onCancel,
    required this.onVerifyAnother,
    required this.onManagePolicies,
  });

  @override
  State<BatchVerifyPage> createState() => _BatchVerifyPageState();
}

class _BatchVerifyPageState extends State<BatchVerifyPage> {
  // ── navigation ────────────────────────────────────────────────────────────
  int _step = 1;

  // ── step 1 ────────────────────────────────────────────────────────────────
  bool _fileUploaded = false;
  String _uploadedFileName = '';
  bool _step1Error = false;
  bool _isDragOver = false;

  // ── step 2 ────────────────────────────────────────────────────────────────
  List<BatchRow> _rows = [];
  List<bool> _rowSelected = [];
  bool _selectAll = false;
  String _tableSearch = '';
  final _tableSearchCtrl = TextEditingController();

  // ── step 3 ────────────────────────────────────────────────────────────────
  bool _isVerifying = false;
  int _verifiedCount = 0;
  Timer? _verifyTimer;

  // ── step 4 ────────────────────────────────────────────────────────────────
  List<_VerifyResult> _results = [];
  _ResultFilter _filter = _ResultFilter.all;
  String _resultSearch = '';

  // ── helpers ───────────────────────────────────────────────────────────────

  int get _validCount =>
      _rows.where((r) => r.state == BatchRowState.valid).length;
  int get _warningCount =>
      _rows.where((r) => r.state == BatchRowState.warning).length;
  int get _errorCount =>
      _rows.where((r) => r.state == BatchRowState.error).length;

  List<BatchRow> get _filteredPreviewRows {
    final q = _tableSearch.toLowerCase().trim();
    if (q.isEmpty) return _rows;
    return _rows
        .where(
          (r) =>
              r.holderName.toLowerCase().contains(q) ||
              r.holderId.toLowerCase().contains(q) ||
              (r.fields['Degree Title'] ?? '').toLowerCase().contains(q) ||
              (r.fields['College'] ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  List<_VerifyResult> get _filteredResults {
    var list = _results.where((r) => _filter.matches(r.outcome)).toList();
    final q = _resultSearch.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list
          .where(
            (r) =>
                r.credentialId.toLowerCase().contains(q) ||
                r.holderName.toLowerCase().contains(q) ||
                r.credentialType.toLowerCase().contains(q) ||
                r.outcome.label.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  void _loadDummyRows() {
    _rows = List<BatchRow>.from(IssuingMockData.batchPreview);
    _rowSelected = List.filled(_rows.length, false);
    _selectAll = false;
  }

  void _simulateUpload(String name) => setState(() {
    _fileUploaded = true;
    _uploadedFileName = name;
    _step1Error = false;
  });

  void _removeFile() => setState(() {
    _fileUploaded = false;
    _uploadedFileName = '';
  });

  void _deleteRow(int idx) {
    setState(() {
      _rows.removeAt(idx);
      _rowSelected.removeAt(idx);
      _selectAll = _rowSelected.isNotEmpty && _rowSelected.every((s) => s);
    });
  }

  Future<void> _startBatchVerify() async {
    final validRows = _rows
        .where((r) => r.state == BatchRowState.valid)
        .toList();
    final total = validRows.length;
    setState(() {
      _isVerifying = true;
      _verifiedCount = 0;
    });

    _verifyTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      setState(() {
        _verifiedCount++;
        if (_verifiedCount >= total) {
          t.cancel();
          _isVerifying = false;
          _results = _buildMockResults(validRows);
          _step = 4;
        }
      });
    });
  }

  void _goNext() {
    switch (_step) {
      case 1:
        if (!_fileUploaded) {
          setState(() => _step1Error = true);
          return;
        }
        _loadDummyRows();
        setState(() {
          _step1Error = false;
          _step = 2;
        });
        break;
      case 2:
        setState(() => _step = 3);
        break;
      case 3:
        if (!_isVerifying) _startBatchVerify();
        break;
      default:
        break;
    }
  }

  void _goBack() {
    if (_step > 1 && !_isVerifying) setState(() => _step--);
  }

  // ─── ROOT BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title
          Text(
            'Batch Verify',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // Stepper
          IssuerStepStrip(
            currentStep: _step,
            stepLabels: _kStepLabels,
            accentColor: _kAccent,
          ),
          const SizedBox(height: 12),

          // Step label
          Text(
            'Step $_step of $_kTotalSteps',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textDim,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _kStepLabels[_step - 1],
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          Expanded(child: _buildStepContent()),
          const SizedBox(height: 16),

          if (_step < 4) _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
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

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1 — Download Template & Upload File
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStep1() {
    return Stack(
      children: [
        Positioned.fill(
          child: _card(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 35),
                  _buildTemplateBanner(),
                  const SizedBox(height: 18),
                  _fileUploaded ? _buildUploadedFile() : _buildDropZone(),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 20,
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
    );
  }

  Widget _buildTemplateBanner() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2B2100),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
              border: Border(
                bottom: BorderSide(color: Color(0xFFFFB300), width: .5),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.table_chart_rounded,
                  size: 15,
                  color: Color(0xFFFFB300),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Download Template',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFB300),
                        ),
                      ),
                      Text(
                        'Fill in each row for one credential to verify. '
                        'Credential ID must match a record on the QChain network.',
                        style: AppTextStyles.bodyTiny.copyWith(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _SmallButton(
                  label: 'Download .xlsx',
                  icon: Icons.download_rounded,
                  color: const Color(0xFFFFB300),
                  onTap: () {},
                ),
              ],
            ),
          ),

          // Column chips
          Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _kTemplateColumns.map((col) {
                final isOpt = col == 'Issuer';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        col,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (!isOpt)
                        const Text(
                          ' *',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.redAccent,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
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
            onTap: () => _simulateUpload('batch_verify.xlsx'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 44),
              decoration: BoxDecoration(
                color: _step1Error
                    ? AppColors.revoked.withOpacity(0.03)
                    : _isDragOver
                    ? _kAccent.withOpacity(0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: _step1Error
                      ? AppColors.revoked.withOpacity(0.45)
                      : _isDragOver
                      ? _kAccent
                      : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    size: 40,
                    color: _isDragOver ? _kAccent : AppColors.textDim,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Drag & drop your file here',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isDragOver ? _kAccent : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Only .xlsx files are allowed.\n'
                    'Maximum 500 rows per file.  Only one file at a time.',
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
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppButton(
              icon: Icons.computer,
              label: 'Browse from Computer',
              backgroundColor: _kAccent,
              hoverColor: _kAccent.withOpacity(0.82),
              onTap: () => _simulateUpload('verify_batch.xlsx'),
            ),
            const SizedBox(width: 10),
            AppButton(
              icon: Icons.cloud_outlined,
              label: 'Upload from OneDrive',
              backgroundColor: _kAccent,
              hoverColor: _kAccent.withOpacity(0.82),
              onTap: () => _simulateUpload('verify_batch_od.xlsx'),
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

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2 — Validate & Preview
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStep2() {
    final filtered = _filteredPreviewRows;

    return _card(
      child: Column(
        children: [
          _buildTableToolbar(),
          Container(height: 1, color: AppColors.border),
          _buildTableHeaderRow(),
          Container(height: 1, color: AppColors.border),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No records match your search.',
                      style: TextStyle(color: AppColors.textDim, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        Container(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) {
                      final row = filtered[i];
                      final globalIdx = _rows.indexOf(row);
                      return _ValidationRow(
                        row: row,
                        rowIndex: globalIdx + 1,
                        isSelected: globalIdx >= 0
                            ? _rowSelected[globalIdx]
                            : false,
                        accentColor: _kAccent,
                        onSelect: (v) {
                          if (globalIdx >= 0) {
                            setState(() {
                              _rowSelected[globalIdx] = v;
                              _selectAll = _rowSelected.every((s) => s);
                            });
                          }
                        },
                        onDelete:
                            (row.state == BatchRowState.error ||
                                row.state == BatchRowState.warning)
                            ? () => _deleteRow(globalIdx)
                            : null,
                      );
                    },
                  ),
          ),
          _buildStatusBar(),
        ],
      ),
    );
  }

  Widget _buildTableToolbar() {
    final selectedCount = _rowSelected.where((s) => s).length;

    return Container(
      color: const Color(0xFF161616),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _uploadedFileName,
                  style: AppTextStyles.navLabelActive.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  selectedCount > 0
                      ? '$selectedCount of ${_rows.length} rows selected'
                      : '${_rows.length} rows total  ·  $_validCount valid for verification',
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 10,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          ...[
            (Icons.refresh, 'Refresh', () => setState(() {})),
            (Icons.delete_outline, 'Delete', () {}),
            (Icons.filter_list, 'Filter', () {}),
          ].map(
            (t) => ToolbarIconBtn(
              icon: t.$1,
              tooltip: t.$2,
              onTap: t.$3,
              color: t.$2 == 'Delete' ? Colors.red : null,
            ),
          ),
          const SizedBox(width: 6),
          // Search
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: QSearchBar(
              controller: _tableSearchCtrl,
              query: _tableSearch,
              onChanged: (v) => setState(() => _tableSearch = v),
              onClear: () {
                _tableSearchCtrl.clear();
                setState(() => _tableSearch = '');
              },
              barWidth: 200,
              searchLabel: 'Search rows…',
              activeColor: _kAccent,
            ),
          ),
          // Icon toolbar
          
        ],
      ),
    );
  }

  Widget _buildTableHeaderRow() {
    return Container(
      color: AppColors.verifyingAccent.withOpacity(0.16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Checkbox(
              value: _selectAll,
              tristate: true,
              onChanged: (v) => setState(() {
                _selectAll = v ?? false;
                _rowSelected = List.filled(_rows.length, _selectAll);
              }),
              activeColor: _kAccent,
              side: const BorderSide(color: AppColors.textMuted),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          _th('', flex: 1),
          _th('STUDENT ID', flex: 2),
          _th('STUDENT NAME', flex: 3),
          _th('DEGREE TITLE', flex: 4),
          _th('COLLEGE', flex: 4),
          _th('GRADE', flex: 2),
          _th('GRAD. YEAR', flex: 2),
          _th('EXPIRY DATE', flex: 2),
          _th('STATUS', flex: 2),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _statusChip('$_validCount Valid', AppColors.valid),
          const SizedBox(width: 8),
          _statusChip('$_warningCount Warning', AppColors.suspended),
          const SizedBox(width: 8),
          _statusChip('$_errorCount Error', AppColors.revoked),
          const Spacer(),
          Text(
            'Only valid rows will be verified.',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 10,
              color: AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3 — Verify All  (progress)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStep3() {
    final total = _validCount;
    final progress = total > 0 ? _verifiedCount / total : 0.0;

    return _card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionDivider('VERIFICATION SUMMARY'),
            const SizedBox(height: 14),
            _summaryRow('Records to Verify', '$_validCount credentials'),
            _summaryRow(
              'Skipped (errors)',
              '$_errorCount error  ·  $_warningCount warning',
            ),
            _summaryRow('Verification Method', 'Blockchain Lookup — QChain'),
            const SizedBox(height: 22),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 22),

            if (_isVerifying) ...[
              // Progress indicator
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Verifying...  $_verifiedCount / $total',
                    style: AppTextStyles.navLabelActive.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceHover,
                  valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% complete',
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 10,
                  color: AppColors.textDim,
                ),
              ),
            ] else ...[
              // Pre-start info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kAccent.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, size: 22, color: _kAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_validCount credentials will be verified',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kAccent,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Each credential will be individually checked against '
                            'the QChain blockchain. Invalid rows from Step 2 '
                            'have been excluded.',
                            style: AppTextStyles.bodyTiny.copyWith(
                              fontSize: 11,
                              color: AppColors.textDim,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 4 — Verification Results
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStep4() {
    final filtered = _filteredResults;
    final validCount = _results
        .where((r) => r.outcome == _VerifyOutcome.valid)
        .length;
    final invalidCount = _results
        .where(
          (r) =>
              r.outcome == _VerifyOutcome.revoked ||
              r.outcome == _VerifyOutcome.invalid,
        )
        .length;
    final attentionCount = _results
        .where(
          (r) =>
              r.outcome == _VerifyOutcome.suspended ||
              r.outcome == _VerifyOutcome.expired,
        )
        .length;

    return _card(
      child: Column(
        children: [
          // ── Toolbar ──────────────────────────────────────────────────
          _buildResultsToolbar(validCount, invalidCount, attentionCount),
          Container(height: 1, color: AppColors.border),

          // ── Column header ────────────────────────────────────────────
          Container(
            color: AppColors.verifyingAccent.withOpacity(0.16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                _th('', flex: 1),
                const SizedBox(width: 12),
                _th('CREDENTIAL ID', flex: 2),
                const SizedBox(width: 12),
                _th('HOLDER NAME', flex: 3),
                const SizedBox(width: 12),
                _th('CREDENTIAL TYPE', flex: 4),
                const SizedBox(width: 12),
                _th('ISSUER', flex: 3),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: Text(
                    'RESULT',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
                _th('REASON', flex: 5),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.border),

          // ── Result rows ──────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No results match this filter.',
                      style: AppTextStyles.bodyTiny.copyWith(
                        fontSize: 12,
                        color: AppColors.textDim,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        Container(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) =>
                        _ResultRow(result: filtered[i], index: i + 1),
                  ),
          ),

          // ── Export bar ───────────────────────────────────────────────
          _buildExportBar(),

          // ── Done buttons ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF161616),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppButton(
                  label: 'Return to Dashboard',
                  showBorder: true,
                  borderColor: AppColors.verifyingAccent,
                  hoverColor: AppColors.surfaceHover,
                  onTap: widget.onCancel,
                  width: 190,
                ),
                const SizedBox(width: 12),
                AppButton(
                  label: 'Verify Another Batch',
                  backgroundColor: _kAccent,
                  hoverColor: _kAccent.withOpacity(0.82),
                  onTap: widget.onVerifyAnother,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsToolbar(
    int validCount,
    int invalidCount,
    int attentionCount,
  ) {
    return Container(
      color: const Color(0xFF161616),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Stat chips
          _statusChip('$validCount Valid', AppColors.verifyingAccent),
          const SizedBox(width: 6),
          _statusChip('$invalidCount Invalid', AppColors.revoked),
          const SizedBox(width: 6),
          _statusChip('$attentionCount Attention', AppColors.suspended),
          const Spacer(),

          // Filter icon
          ToolbarIconBtn(
            icon: Icons.filter_list,
            tooltip: 'Filter',
            onTap: () {
              // TODO: implement filter logic
            },
          ),
          const SizedBox(width: 6),

          // Search
          // Container(
          //   width: 200,
          //   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          //   decoration: BoxDecoration(
          //     color: AppColors.surfaceHover,
          //     borderRadius: BorderRadius.circular(6),
          //     border: Border.all(color: AppColors.border),
          //   ),
          //   child: Row(
          //     children: [
          //       const Icon(Icons.search, size: 13, color: AppColors.textDim),
          //       const SizedBox(width: 6),
          //       Expanded(
          //         child: TextField(
          //           style: const TextStyle(fontSize: 11, color: Colors.white),
          //           decoration: InputDecoration(
          //             isDense: true,
          //             border: InputBorder.none,
          //             hintText: 'Search results…',
          //             hintStyle: AppTextStyles.bodyTiny.copyWith(
          //               fontSize: 11,
          //               color: AppColors.textDim,
          //             ),
          //           ),
          //           onChanged: (v) => setState(() => _resultSearch = v),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          QSearchBar(
            controller: _tableSearchCtrl,
            query: _resultSearch,
            onChanged: (v) => setState(() => _resultSearch = v),
            onClear: () {
              _tableSearchCtrl.clear();
              setState(() => _resultSearch = '');
            },
            barWidth: 200,
            searchLabel: 'Search rows…',
            activeColor: _kAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildExportBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            'EXPORT RESULTS',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.textDim,
            ),
          ),
          const SizedBox(width: 12),
          AppButton(
            height: 35,
            label: 'CSV',
            icon: Icons.table_rows_outlined,
            showBorder: true,
            borderColor: AppColors.verifyingAccent,
            hoverColor: AppColors.surfaceHover,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          AppButton(
            height: 35,
            label: 'XLSX',
            icon: Icons.table_chart_outlined,
            showBorder: true,
            borderColor: AppColors.verifyingAccent,
            hoverColor: AppColors.surfaceHover,

            onTap: () {},
          ),
          const SizedBox(width: 8),
          AppButton(
            height: 35,
            label: 'PDF',
            icon: Icons.picture_as_pdf_outlined,
            showBorder: true,
            borderColor: AppColors.verifyingAccent,
            hoverColor: AppColors.surfaceHover,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM BUTTONS ───────────────────────────────────────────────────────

  Widget _buildBottomButtons() {
    final isStep3 = _step == 3;
    final btnLabel = isStep3
        ? (_isVerifying ? 'Verifying…' : 'Verify All')
        : 'Next →';

    return Row(
      children: [
        if (_step == 1)
          AppButton(
            label: 'Cancel',
            backgroundColor: Colors.red,
            showBorder: true,
            borderColor: Colors.redAccent,
            hoverColor: AppColors.surfaceHover,
            width: 80,
            onTap: widget.onCancel,
          ),
        if (_step == 1) const SizedBox(width: 10),
        if (_step > 1 && !_isVerifying)
          AppButton(
            label: '← Back',
            showBorder: true,
            borderColor: AppColors.border,
            hoverColor: AppColors.surfaceHover,
            width: 80,
            onTap: _goBack,
          ),
        if (_step > 1 && !_isVerifying) const SizedBox(width: 10),
        AppButton(
          label: btnLabel,
          backgroundColor: _kAccent,
          hoverColor: _kAccent.withOpacity(0.82),
          enabled: !_isVerifying,
          onTap: _goNext,
        ),
        // Inline error messages (step 1)
        if (_step == 1 && _step1Error) ...[
          const SizedBox(width: 14),
          const Icon(Icons.error_outline, size: 13, color: Colors.redAccent),
          const SizedBox(width: 4),
          const Text(
            'Please upload a file before continuing.',
            style: TextStyle(fontSize: 11, color: Colors.redAccent),
          ),
        ],
      ],
    );
  }

  // ─── SHARED HELPERS ───────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFF111111),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    clipBehavior: Clip.hardEdge,
    child: child,
  );

  Widget _sectionDivider(String label) => Row(
    children: [
      Text(
        label,
        style: AppTextStyles.bodyTiny.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: AppColors.textDim,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 1, color: AppColors.border)),
    ],
  );

  Widget _th(String text, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(
      text,
      style: AppTextStyles.bodyTiny.copyWith(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: AppColors.white,
      ),
    ),
  );

  Widget _statusChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
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
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _tableSearchCtrl.dispose();
    _verifyTimer?.cancel();
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// RESULT ROW — Step 4
// ═════════════════════════════════════════════════════════════════════════════

class _ResultRow extends StatefulWidget {
  final _VerifyResult result;
  final int index;
  const _ResultRow({required this.result, required this.index});

  @override
  State<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<_ResultRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? r.outcome.color.withOpacity(0.09) : r.outcome.rowTint,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            // #
            Expanded(
              flex: 1,
              child: Text(
                '${widget.index}',
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 11,
                  color: AppColors.textDim,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Credential ID
            Expanded(
              flex: 2,
              child: Text(
                r.credentialId,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.issuingLight,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            // Holder Name
            Expanded(
              flex: 3,
              child: Text(
                r.holderName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
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
            const SizedBox(width: 12),
            // Issuer
            Expanded(
              flex: 3,
              child: Text(
                r.issuer,
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 11,
                  color: AppColors.textDim,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            // Result badge
            SizedBox(
              width: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: r.outcome.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: r.outcome.color.withOpacity(0.35)),
                ),
                child: Text(
                  r.outcome.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: r.outcome.color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 50),
            // Reason
            Expanded(
              flex: 5,
              child: Text(
                r.reason,
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 10,
                  color: r.outcome == _VerifyOutcome.valid
                      ? AppColors.textDim
                      : r.outcome.color.withOpacity(0.85),
                  height: 1.4,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FILTER CHIP
// ═════════════════════════════════════════════════════════════════════════════

// class _FilterChip extends StatefulWidget {
//   final String label;
//   final bool selected;
//   final VoidCallback onTap;
//   const _FilterChip({
//     required this.label,
//     required this.selected,
//     required this.onTap,
//   });
//   @override
//   State<_FilterChip> createState() => _FilterChipState();
// }

// class _FilterChipState extends State<_FilterChip> {
//   bool _h = false;
//   @override
//   Widget build(BuildContext context) => MouseRegion(
//     cursor: SystemMouseCursors.click,
//     onEnter: (_) => setState(() => _h = true),
//     onExit: (_) => setState(() => _h = false),
//     child: GestureDetector(
//       onTap: widget.onTap,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 130),
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//         decoration: BoxDecoration(
//           color: widget.selected
//               ? _kAccent.withOpacity(0.15)
//               : _h
//               ? AppColors.surfaceHover
//               : Colors.transparent,
//           borderRadius: BorderRadius.circular(6),
//           border: Border.all(
//             color: widget.selected
//                 ? _kAccent.withOpacity(0.45)
//                 : AppColors.border,
//           ),
//         ),
//         child: Text(
//           widget.label,
//           style: TextStyle(
//             fontSize: 11,
//             fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
//             color: widget.selected ? _kAccent : AppColors.textMuted,
//           ),
//         ),
//       ),
//     ),
//   );
// }

// ═════════════════════════════════════════════════════════════════════════════
// VALIDATION ROW  (identical behavior to issue_batch_credential_page.dart,
//                  accent colour passed in to use verifyingAccent)
// ═════════════════════════════════════════════════════════════════════════════

class _ValidationRow extends StatefulWidget {
  final BatchRow row;
  final int rowIndex;
  final bool isSelected;
  final Color accentColor;
  final ValueChanged<bool> onSelect;
  final VoidCallback? onDelete;

  const _ValidationRow({
    required this.row,
    required this.rowIndex,
    required this.isSelected,
    required this.accentColor,
    required this.onSelect,
    this.onDelete,
  });

  @override
  State<_ValidationRow> createState() => _ValidationRowState();
}

class _ValidationRowState extends State<_ValidationRow> {
  bool _hovered = false;

  Color get _stateColor {
    switch (widget.row.state) {
      case BatchRowState.valid:
        return AppColors.valid;
      case BatchRowState.warning:
        return AppColors.suspended;
      case BatchRowState.error:
        return AppColors.revoked;
    }
  }

  String get _stateLabel {
    switch (widget.row.state) {
      case BatchRowState.valid:
        return 'Valid';
      case BatchRowState.warning:
        return 'Warning';
      case BatchRowState.error:
        return 'Error';
    }
  }

  IconData get _stateIcon {
    switch (widget.row.state) {
      case BatchRowState.valid:
        return Icons.check_circle;
      case BatchRowState.warning:
        return Icons.warning_amber_rounded;
      case BatchRowState.error:
        return Icons.cancel;
    }
  }

  Widget _cell(String colKey, {int flex = 2, bool dimEmpty = false}) {
    final value = widget.row.fields[colKey] ?? '';
    final error = widget.row.fieldErrors[colKey];
    final isEmpty = value.trim().isEmpty;

    return Expanded(
      flex: flex,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEmpty ? '—' : value,
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 11,
              color: isEmpty
                  ? AppColors.textDim.withOpacity(0.5)
                  : dimEmpty
                  ? AppColors.textDim
                  : AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (error != null) ...[
            const SizedBox(height: 2),
            Text(
              error,
              style:  TextStyle(
                fontSize: 9,
                color: (error == "missing")
                    ? AppColors.suspended
                    : AppColors.revoked,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelect(!widget.isSelected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: widget.isSelected
              ? widget.accentColor.withOpacity(0.05)
              : _hovered
              ? AppColors.surfaceHover
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 28,
                child: Checkbox(
                  value: widget.isSelected,
                  onChanged: (v) => widget.onSelect(v ?? false),
                  activeColor: widget.accentColor,
                  side: const BorderSide(color: AppColors.border),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  '${widget.rowIndex}',
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                ),
              ),
              _cell('Student ID', flex: 2),
              Expanded(
                flex: 3,
                child: Text(
                  widget.row.holderName,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _cell('Degree Title', flex: 4, dimEmpty: true),
              _cell('College', flex: 4, dimEmpty: true),
              _cell('Grade', flex: 2),
              _cell('Graduation Year', flex: 2),
              _cell('Expiry Date', flex: 2),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(_stateIcon, size: 12, color: _stateColor),
                    const SizedBox(width: 4),
                    Text(
                      _stateLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _stateColor,
                      ),
                    ),
                  ],
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
// SMALL HELPERS  (identical to issue_batch_credential_page.dart)
// ═════════════════════════════════════════════════════════════════════════════

class _SmallButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SmallButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  @override
  State<_SmallButton> createState() => _SmallButtonState();
}

class _SmallButtonState extends State<_SmallButton> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _h
              ? widget.color.withOpacity(0.20)
              : widget.color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: widget.color.withOpacity(0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 12, color: widget.color),
            const SizedBox(width: 5),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReportBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ReportBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  @override
  State<_ReportBtn> createState() => _ReportBtnState();
}

class _ReportBtnState extends State<_ReportBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _h
              ? widget.color.withOpacity(0.14)
              : widget.color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: widget.color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 13, color: widget.color),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: widget.color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.download,
              size: 11,
              color: widget.color.withOpacity(0.6),
            ),
          ],
        ),
      ),
    ),
  );
}
