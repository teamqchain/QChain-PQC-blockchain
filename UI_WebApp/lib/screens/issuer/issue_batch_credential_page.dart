// view/issuing/issue_batch_credential_page.dart
//
// Issue Batch Credential — 5-step wizard
//
// Column naming decision:
//   We use "Student ID" as the single holder identifier throughout the template
//   and table. University staff are familiar with Student ID, and it maps
//   directly to the Holder ID in the system. No need to show both columns.
//
// Integration:
//   case RouteName.issueBatch:
//     return IssueBatchCredentialPage(
//       onCancel:            () => onNavigate(RouteName.dashboard),
//       onIssueAnotherBatch: () => onNavigate(RouteName.issueBatch),
//     );

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qportal_webapp/widgets/schemeType.dart';
import 'package:qportal_webapp/components/filterButton.dart';
import 'package:qportal_webapp/components/searchBar.dart';
import 'package:qportal_webapp/components/stepper.dart';
import 'package:qportal_webapp/models/ISSUER/batchRow_model.dart';
import 'package:qportal_webapp/models/ISSUER/schema_model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';
// import 'package:qportal_webapp/view/responsive_layout.dart';

// ─── CONSTANTS ────────────────────────────────────────────────────────────────

const _kTotalSteps = 5;
const _kOrgName = 'University of Sharjah';
const _kIssuerName = 'Mohammed A.';

const _kStepLabels = [
  'Select Credential Type',
  'Upload File',
  'Validate & Preview',
  'Issue All',
  'Result',
];

/// The fixed ordered columns shown in the upload template and validation table.
/// "Student ID" is the holder identifier — it maps to HolderID in the system.
const _kTemplateColumns = [
  'Student ID',
  'Degree Title',
  'College',
  'Grade',
  'Graduation Year',
  'Expiry Date',
];

// ─── PAGE ─────────────────────────────────────────────────────────────────────

class IssueBatchCredentialPage extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onIssueAnotherBatch;

  const IssueBatchCredentialPage({
    super.key,
    required this.onCancel,
    required this.onIssueAnotherBatch,
  });

  @override
  State<IssueBatchCredentialPage> createState() =>
      _IssueBatchCredentialPageState();
}

class _IssueBatchCredentialPageState extends State<IssueBatchCredentialPage> {
  // ── navigation ─────────────────────────────────────────────────────────────
  int _step = 1;

  // ── step 1 ─────────────────────────────────────────────────────────────────
  SchemaRecord? _selectedSchema;
  bool _step1Error = false;

  // ── step 2 ─────────────────────────────────────────────────────────────────
  bool _fileUploaded = false;
  String _uploadedFileName = '';
  bool _step2Error = false;
  bool _isDragOver = false;

  // ── step 3 ─────────────────────────────────────────────────────────────────
  List<BatchRow> _rows = [];
  List<bool> _rowSelected = [];
  bool _selectAll = false;
  String _tableSearch = '';
  final _tableSearchCtrl = TextEditingController();

  // ── step 4 ─────────────────────────────────────────────────────────────────
  bool _isIssuing = false;
  int _issuedCount = 0;
  Timer? _issueTimer;

  // ── step 5 ─────────────────────────────────────────────────────────────────
  int _successCount = 0;
  int _failCount = 0;

  // ─── helpers ─────────────────────────────────────────────────────────────

  List<SchemaRecord> get _activeSchemas =>
      SchemaMockData.schemas.where((s) => s.isActive).toList();

  int get _validCount =>
      _rows.where((r) => r.state == BatchRowState.valid).length;
  int get _warningCount =>
      _rows.where((r) => r.state == BatchRowState.warning).length;
  int get _errorCount =>
      _rows.where((r) => r.state == BatchRowState.error).length;

  /// Next is blocked only if any errors or warnings STILL exist.
  /// User can delete bad rows to unblock.
  // bool get _canProceedStep3 => _errorCount == 0 && _warningCount == 0;
  bool get _canProceedStep3 => true;

  List<BatchRow> get _filteredRows {
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

  void _loadDummyRows() {
    _rows = List<BatchRow>.from(BatchMockData.batchPreview);
    _rowSelected = List.filled(_rows.length, false);
    _selectAll = false;
  }

  void _simulateUpload(String fileName) {
    setState(() {
      _fileUploaded = true;
      _uploadedFileName = fileName;
      _step2Error = false;
    });
  }

  void _removeFile() {
    setState(() {
      _fileUploaded = false;
      _uploadedFileName = '';
    });
  }

  void _deleteRow(int globalIndex) {
    setState(() {
      _rows.removeAt(globalIndex);
      _rowSelected.removeAt(globalIndex);
      // Recalculate select-all state
      _selectAll = _rowSelected.isNotEmpty && _rowSelected.every((s) => s);
    });
  }

  Future<void> _startBatchIssue() async {
    final total = _validCount;
    setState(() {
      _isIssuing = true;
      _issuedCount = 0;
    });

    _issueTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      setState(() {
        _issuedCount++;
        if (_issuedCount >= total) {
          t.cancel();
          _isIssuing = false;
          _successCount = total;
          _failCount = 0; // all bad rows were deleted before this step
          _step = 5;
        }
      });
    });
  }

  void _goNext() {
    switch (_step) {
      case 1:
        if (_selectedSchema == null) {
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
        if (!_fileUploaded) {
          setState(() => _step2Error = true);
          return;
        }
        setState(() {
          _step2Error = false;
          _step = 3;
        });
        break;
      case 3:
        if (!_canProceedStep3) return; // button is disabled — no-op
        setState(() => _step = 4);
        break;
      case 4:
        _startBatchIssue();
        break;
      default:
        break;
    }
  }

  void _goBack() {
    if (_step > 1) setState(() => _step--);
  }

  // ─── ROOT BUILD ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Issue Batch Credential',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          IssuerStepStrip(
            currentStep: _step,
            stepLabels: _kStepLabels,
            accentColor: AppColors.issuingAccent,
          ),
          const SizedBox(height: 12),
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
          if (_step < 5) _buildBottomButtons(),
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
      case 4:
        return _buildStep4();
      case 5:
        return _buildStep5();
      default:
        return const SizedBox.shrink();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1 — Select Credential Type
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStep1() {
    final schemas = _activeSchemas;

    if (schemas.isEmpty) {
      return _card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.schema_outlined,
                size: 44,
                color: AppColors.textDim,
              ),
              const SizedBox(height: 14),
              Text(
                'You have no credential types yet.',
                style: AppTextStyles.navLabelActive.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 5),
              Text(
                'Create your first schema before issuing.',
                style: AppTextStyles.bodyTiny.copyWith(
                  color: AppColors.textDim,
                ),
              ),
              const SizedBox(height: 14),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  'Go to Schemas →',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.issuingAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left 50% — schema list
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Text(
                    'CREDENTIAL TYPES',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.textDim,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: schemas.length,
                    itemBuilder: (_, i) => SchemaListItem(
                      schema: schemas[i],
                      isSelected: _selectedSchema?.id == schemas[i].id,
                      onTap: () => setState(() {
                        _selectedSchema = schemas[i];
                        _step1Error = false;
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, color: AppColors.border),
          // Right 50% — preview
          Expanded(
            child: _selectedSchema == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 36,
                          color: AppColors.textDim,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Select a credential type\nto see details',
                          style: AppTextStyles.bodyTiny.copyWith(
                            color: AppColors.textDim,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildSchemaPreview(_selectedSchema!),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchemaPreview(SchemaRecord s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.issuingAccent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.description_outlined,
                size: 17,
                color: AppColors.issuingAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: AppTextStyles.navLabelActive.copyWith(fontSize: 13),
                  ),
                  Text(
                    s.category,
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 9,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          s.description,
          style: AppTextStyles.bodyTiny.copyWith(
            fontSize: 11,
            height: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 16),
        _sectionDivider('UPLOAD TEMPLATE COLUMNS'),
        const SizedBox(height: 10),
        // Show exactly the template columns
        ..._kTemplateColumns.map(
          (col) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.table_chart_outlined,
                  size: 11,
                  color: AppColors.textDim,
                ),
                const SizedBox(width: 7),
                Text(col, style: AppTextStyles.bodyTiny.copyWith(fontSize: 11)),
                if (col != 'Expiry Date')
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      '*',
                      style: TextStyle(fontSize: 11, color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '* required  ·  Student ID = Holder ID in the system',
          style: AppTextStyles.bodyTiny.copyWith(
            fontSize: 9,
            color: AppColors.textDim,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _statChip('${s.credentialsIssued}', 'Issued'),
            const SizedBox(width: 8),
            _statChip('${_kTemplateColumns.length}', 'Columns'),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2 — Upload File
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStep2() {
    return _card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTemplateBanner(),
            const SizedBox(height: 18),
            _fileUploaded ? _buildUploadedFile() : _buildDropZone(),
          ],
        ),
      ),
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
          // Banner header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              // color: const Color(0xFFFFB300).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(9),
              ),
              border: const Border(
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
                      Text(
                        'Download Template',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFB300),
                        ),
                      ),
                      Text(
                        'Fill in each row for one credential recipient. '
                        'Student ID must match a registered holder.',
                        style: AppTextStyles.bodyTiny.copyWith(
                          fontSize: 10,
                          color: Colors.red,
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
                // final isId = col == 'Student ID';
                final isOpt = col == 'Expiry Date';
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
                        style: TextStyle(
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
            onTap: () => _simulateUpload('batch_credentials.xlsx'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 44),
              decoration: BoxDecoration(
                color: _isDragOver
                    ? AppColors.issuingAccent.withOpacity(0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: _isDragOver
                      ? AppColors.issuingAccent
                      : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    size: 40,
                    color: _isDragOver
                        ? AppColors.issuingAccent
                        : AppColors.textDim,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Drag & drop your file here',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isDragOver
                          ? AppColors.issuingAccent
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Only .csv or .xlsx files are allowed.\n'
                    'Max row count is 1,000.  Only one file can be uploaded.',
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
              label: 'Browse Computer',
              backgroundColor: AppColors.issuingAccent,
              hoverColor: AppColors.issuingAccent.withOpacity(0.82),
              onTap: () => _simulateUpload('graduates_2025.xlsx'),
            ),
            const SizedBox(width: 10),
            AppButton(
              icon: Icons.cloud_outlined,
              label: 'Upload from OneDrive',
              backgroundColor: AppColors.issuingAccent,
              hoverColor: AppColors.issuingAccent.withOpacity(0.82),
              onTap: () => _simulateUpload('onedrive_batch.xlsx'),
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
                  color: Colors.red.withOpacity(0.1),
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
  // STEP 3 — Validate & Preview
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStep3() {
    final filtered = _filteredRows;

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
                Text(
                  selectedCount > 0
                      ? '$selectedCount of ${_rows.length} rows selected'
                      : '${_rows.length} rows total',
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 10,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
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
              activeColor: AppColors.issuingAccent,
            ),
          ),
          // Icon toolbar
          ...[
            (Icons.refresh, 'Refresh', () => setState(() {})),
            (Icons.edit_outlined, 'Edit', () {}),
            (Icons.delete_outline, 'Delete', () {}),
            (Icons.filter_list, 'Filter', () {}),
          ].map((t) => ToolbarIconBtn(
            icon: t.$1,
            tooltip: t.$2,
            onTap: t.$3,
            color: t.$2 == 'Delete' ? Colors.red : null,
          )),
        ],
      ),
    );
  }

  Widget _buildTableHeaderRow() {
    return Container(
      color: AppColors.issuingAccent.withOpacity(0.16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Checkbox
          SizedBox(
            width: 28,
            child: Checkbox(
              value: _selectAll,
              tristate: true,
              onChanged: (v) => setState(() {
                _selectAll = v ?? false;
                _rowSelected = List.filled(_rows.length, _selectAll);
              }),
              activeColor: AppColors.issuingAccent,
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
          // if (!_canProceedStep3)
          //   Row(
          //     children: [
          //       const Icon(
          //         Icons.info_outline,
          //         size: 12,
          //         color: AppColors.textDim,
          //       ),
          //       const SizedBox(width: 5),
          //       Text(
          //         'Delete error and warning rows to continue.',
          //         style: AppTextStyles.bodyTiny.copyWith(
          //           fontSize: 10,
          //           color: AppColors.textDim,
          //         ),
          //       ),
          //     ],
          //   ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 4 — Issue All Summary
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStep4() {
    final total = _validCount;
    final progress = total > 0 ? _issuedCount / total : 0.0;

    return _card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionDivider('BATCH SUMMARY'),
            const SizedBox(height: 14),
            _summaryRow('Credential Type', _selectedSchema!.name),
            _summaryRow('Valid Records', '$_validCount credentials'),
            _summaryRow('Issued By', _kIssuerName),
            _summaryRow('Organization', _kOrgName),
            _summaryRow('Signing Algorithm', 'Dilithium (CRYSTALS-Dilithium3)'),
            const SizedBox(height: 22),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 22),
            if (_isIssuing) ...[
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.issuingAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Issuing credentials…  $_issuedCount / $total',
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
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.issuingAccent,
                  ),
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.issuingAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.issuingAccent.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, size: 22, color: AppColors.issuingAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_validCount credentials will be issued',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.issuingAccent,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Each credential will be individually signed with '
                            'Dilithium and anchored to the blockchain.',
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
  // STEP 5 — Result
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStep5() {
    return _card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Result header card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.issuingAccent.withOpacity(0.08),
                    AppColors.issuingAccent.withOpacity(0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.issuingAccent.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.issuingAccent.withOpacity(0.15),
                    ),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 28,
                      color: AppColors.issuingAccent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch Issue Complete',
                          style: AppTextStyles.navLabelActive.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$_kOrgName  ·  $_kIssuerName',
                          style: AppTextStyles.bodyTiny.copyWith(
                            fontSize: 10,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionDivider('RESULT BREAKDOWN'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _resultStat(
                    value: '$_successCount',
                    label: 'Successfully Issued',
                    icon: Icons.check_circle,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _resultStat(
                    value: '$_failCount',
                    label: 'Failed / Skipped',
                    icon: Icons.cancel_outlined,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _resultStat(
                    value: '${_successCount + _failCount}',
                    label: 'Total Processed',
                    icon: Icons.layers_outlined,
                    color: AppColors.issuingAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 20),
            _sectionDivider('GENERATE REPORT'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _ReportBtn(
                  label: 'Full Report',
                  icon: Icons.description_outlined,
                  color: AppColors.issuingAccent,
                  onTap: () {},
                ),
                _ReportBtn(
                  label: 'Successful Only',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF4CAF50),
                  onTap: () {},
                ),
                _ReportBtn(
                  label: 'Rejected Only',
                  icon: Icons.cancel_outlined,
                  color: Colors.redAccent,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Reports are exported as .xlsx files.',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 10,
                color: AppColors.textDim,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppButton(
                  label: 'Return to Dashboard',
                  onTap: widget.onCancel,
                  width: 190,
                  showBorder: true,
                  borderColor: AppColors.issuingAccent,
                  hoverColor: AppColors.surfaceHover,
                ),
                const SizedBox(width: 12),
                AppButton(
                  label: 'Issue Another Batch',
                  backgroundColor: AppColors.issuingAccent,
                  hoverColor: AppColors.issuingAccent.withOpacity(0.82),
                  onTap: widget.onIssueAnotherBatch,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultStat({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.bodyTiny.copyWith(
            fontSize: 10,
            color: AppColors.textDim,
          ),
        ),
      ],
    ),
  );

  // ─── BOTTOM BUTTONS ───────────────────────────────────────────────────────

  Widget _buildBottomButtons() {
    // In step 3 the Next button is disabled (greyed) instead of showing an
    // error banner — the inline status bar already communicates the issue.
    final isStep4 = _step == 4;
    final canNext = _step == 3 ? _canProceedStep3 : true;

    return Row(
      children: [
        if (_step == 1)
          AppButton(label: 'Cancel', onTap: widget.onCancel, width: 80, backgroundColor: Colors.red, showBorder: true, borderColor: Colors.redAccent, hoverColor: AppColors.surfaceHover),
        if (_step == 1) const SizedBox(width: 10),
        if (_step > 1 && !_isIssuing)
          AppButton(label: '← Back', onTap: _goBack, width: 80, showBorder: true, borderColor: AppColors.border, hoverColor: AppColors.surfaceHover),
        if (_step > 1 && !_isIssuing) const SizedBox(width: 10),
        AppButton(
          label: isStep4 ? (_isIssuing ? 'Issuing…' : 'Issue All') : 'Next →',
          backgroundColor: AppColors.issuingAccent,
          hoverColor: AppColors.issuingAccent.withOpacity(0.82),
          enabled: !_isIssuing && canNext,
          onTap: _goNext,
        ),
        if (_step == 1 && _step1Error) ...[
          const SizedBox(width: 14),
          const Icon(Icons.error_outline, size: 13, color: Colors.redAccent),
          const SizedBox(width: 4),
          const Text(
            'Please select a credential type to continue.',
            style: TextStyle(fontSize: 11, color: Colors.redAccent),
          ),
        ],
        if (_step == 2 && _step2Error) ...[
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

  Widget _statChip(String value, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.surfaceHover,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTextStyles.bodyTiny.copyWith(
            fontSize: 10,
            color: AppColors.textDim,
          ),
        ),
      ],
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
    _issueTimer?.cancel();
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// VALIDATION TABLE ROW
//
// Shows all 7 columns. Under each cell that has a fieldError for its column,
// the error message is rendered in small red text — NOT under the status badge.
// The status badge shows only Valid / Warning / Error, no reason text.
// Error/warning rows have a delete icon; valid rows do not.
// ═════════════════════════════════════════════════════════════════════════════

class _ValidationRow extends StatefulWidget {
  final BatchRow row;
  final int rowIndex;
  final bool isSelected;
  final ValueChanged<bool> onSelect;
  final VoidCallback? onDelete; // null = not deletable (valid rows)

  const _ValidationRow({
    required this.row,
    required this.rowIndex,
    required this.isSelected,
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

  /// Builds one data cell. If [colKey] has a fieldError, the error message
  /// is shown in small red text directly below the cell value.
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
                  : (dimEmpty ? AppColors.textDim : AppColors.textMuted),
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
                color: (error == "missing")? AppColors.suspended: AppColors.revoked,
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
    final canDelete = widget.onDelete != null;

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
              ? AppColors.issuingAccent.withOpacity(0.05)
              : _hovered
              ? AppColors.surfaceHover
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox
              SizedBox(
                width: 28,
                child: Checkbox(
                  value: widget.isSelected,
                  onChanged: (v) => widget.onSelect(v ?? false),
                  activeColor: AppColors.issuingAccent,
                  side: const BorderSide(color: AppColors.border),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              // Row number
              Expanded(
                flex: 1,
                child: Text(
                  '',
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                ),
              ),
              // Student ID
              _cell('Student ID', flex: 2),
              // Student Name (not in fields map — comes from studentName)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.row.holderName,
                      style: AppTextStyles.bodyTiny.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Degree Title
              _cell('Degree Title', flex: 4, dimEmpty: true),
              // College
              _cell('College', flex: 4, dimEmpty: true),
              // Grade
              _cell('Grade', flex: 2),
              // Graduation Year
              _cell('Graduation Year', flex: 2),
              // Expiry Date
              _cell('Expiry Date', flex: 2),
              // Status badge — label only, no reason text
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
              // Delete button (only for error / warning rows)
              // SizedBox(
              //   width: 30,
              //   child: canDelete
              //       ? GestureDetector(
              //           onTap: widget.onDelete,
              //           child: MouseRegion(
              //             cursor: SystemMouseCursors.click,
              //             child: AnimatedOpacity(
              //               duration: const Duration(milliseconds: 120),
              //               opacity: _hovered ? 1.0 : 0.4,
              //               child: Container(
              //                 padding: const EdgeInsets.all(4),
              //                 decoration: BoxDecoration(
              //                   color: Colors.red.withOpacity(0.12),
              //                   borderRadius: BorderRadius.circular(5),
              //                 ),
              //                 child: const Icon(
              //                   Icons.delete_outline,
              //                   size: 13,
              //                   color: Colors.redAccent,
              //                 ),
              //               ),
              //             ),
              //           ),
              //         )
              //       : const SizedBox.shrink(),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SMALL HELPER WIDGETS
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
              ? widget.color.withOpacity(0.2)
              : widget.color.withOpacity(0.1),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
            Icon(widget.icon, size: 14, color: widget.color),
            const SizedBox(width: 7),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: widget.color,
              ),
            ),
            const SizedBox(width: 5),
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


