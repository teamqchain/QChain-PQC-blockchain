import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/connection_error.dart';
import 'package:qportal_webapp/components/filterButton.dart';
import 'package:qportal_webapp/components/tableHeader.dart';
import 'package:qportal_webapp/services/holder_api.dart';
import 'package:qportal_webapp/services/issuer_api.dart';
import 'package:qportal_webapp/utils/currentUser.dart';
import 'package:qportal_webapp/utils/dateFormatter.dart';
import 'package:qportal_webapp/tables/holder_table.dart';
import 'package:qportal_webapp/widgets/previewCard.dart';
import 'package:qportal_webapp/widgets/schemeType.dart';
import 'package:qportal_webapp/components/searchBar.dart';
import 'package:qportal_webapp/components/stepper.dart';
import 'package:qportal_webapp/models/ISSUER/credentials_model.dart';
import 'package:qportal_webapp/models/holder_model.dart';
import 'package:qportal_webapp/models/ISSUER/schema_model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/view/responsive_layout.dart';
import 'package:qportal_webapp/components/countChip.dart';
import 'package:qportal_webapp/components/datePicker.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'dart:convert';


const _kTotalSteps = 5;


const _kStepLabels = [
  'Select Credential Type',
  'Find Holder',
  'Fill Credential Details',
  'Credential Preview',
  'Confirm & Issue',
];

const _kSchemaDefaults = <String, Map<String, String>>{
  'SCH-001': {
    'f1': 'BSc Computer Science',
    'f2': 'College of Computing & Informatics',
    'f3': 'STU-2025-0291',
    'f4': 'Merit',
    'f5': '2025',
  },
  'SCH-002': {
    'f1': 'MSc Cybersecurity',
    'f2': 'College of Computing & Informatics',
    'f3': 'STU-2025-0312',
    'f4': 'Thesis Track',
    'f5': '2025',
  },
  'SCH-003': {
    'f1': 'Quantum Machine Learning',
    'f2': 'College of Computing & Informatics',
    'f3': 'STU-2025-0445',
    'f4': '2025',
  },
  'SCH-004': {
    'f1': 'Diploma in Business Technology',
    'f2': 'College of Business Administration',
    'f3': 'STU-2025-0547',
    'f4': 'Merit',
  },
  'SCH-005': {
    'f1': 'Advanced Information Security',
    'f2': '120',
    'f3': 'Pass',
    'f4': 'TRN-2025-0101',
  },
  'SCH-006': {
    'f1': 'Full Practicing License',
    'f2': 'ML-2025-0184',
    'f3': 'Internal Medicine',
    'f4': 'Yes',
  },
  'SCH-007': {
    'f1': 'Postdoctoral Research Fellow',
    'f2': 'Quantum Computing',
    'f3': 'RES-2025-0001',
    'f4': 'Full-Time',
  },
  'SCH-008': {
    'f1': 'Information Technology',
    'f2': 'EMP-2025-0618',
    'f3': 'Senior Engineer',
  },
};


class IssueSingleCredentialPage extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onIssueAnother;

  final CredentialRecord? reissueFrom;

  const IssueSingleCredentialPage({
    super.key,
    required this.onCancel,
    required this.onIssueAnother,
    this.reissueFrom,
  });

  @override
  State<IssueSingleCredentialPage> createState() =>
      _IssueSingleCredentialPageState();
}

class _IssueSingleCredentialPageState extends State<IssueSingleCredentialPage> {
  List<HolderRecord> _holders = [];
  bool _holdersLoading = false;
  bool _holdersError = false;

  int _step = 1;

  // step 1
  SchemaRecord? _selectedSchema;
  bool _step1Error = false;

  // step 2
  HolderRecord? _selectedHolder;
  String _holderSearch = '';
  bool _step2Error = false;
  final _searchCtrl = TextEditingController();

  // step 3
  final Map<String, String> _fieldValues = {};
  final Map<String, TextEditingController> _fieldCtrl = {};
  DateTime? _expiryDate;
  bool _noExpiry = true;
  bool _step3Error = false;

  // step 5
  bool _confirmed = false;
  bool _isIssuing = false;
  bool _issued = false;
  String _issuingStatus = '';
  String _issuedId = '';
  String _issueError = '';

  @override
  void initState() {
    super.initState();
    final cred = widget.reissueFrom;
    if (cred != null) _bootstrapReissue(cred);
  }


  // This method attempts to pre-fill the issuing form based on an existing credential record (for re-issuing).
  // It tries to match the credential's type and holder to existing schemas and holders in the system,
  // and then seeds the form fields with the credential's attributes.
  // This allows for a smoother re-issuing experience,
  // as the issuer doesn't have to start from scratch when re-issuing a credential.

  void _bootstrapReissue(CredentialRecord cred) {
    final schemas = _activeSchemas;
    _selectedSchema = schemas.cast<SchemaRecord?>().firstWhere(
      (s) => s!.name == cred.credentialType,
      orElse: () => schemas.cast<SchemaRecord?>().firstWhere(
        (s) =>
            cred.credentialType.toLowerCase().contains(s!.name.toLowerCase()) ||
            s.name.toLowerCase().contains(cred.credentialType.toLowerCase()),
        orElse: () => null,
      ),
    );

    _selectedHolder = HolderRecord(
      id: cred.holderId,
      fullName: cred.holderName,
      email: cred.holderEmail,
      emiratesID: cred.holderEmiratesID,
      type: HolderType.bachelorStudent, 
      college: '',
    );

    if (_selectedSchema != null) {
      _initFields(_selectedSchema!);
      for (final f in _selectedSchema!.fields) {
        final attrVal = cred.attributes[f.label];
        if (attrVal != null) {
          _fieldValues[f.id] = attrVal;
          _fieldCtrl[f.id]?.text = attrVal;
        }
      }
    }

    if (cred.expiryDate != null && cred.expiryDate!.isNotEmpty) {
      _noExpiry = false;
    } else {
      _noExpiry = true;
    }

    if (_selectedSchema != null) _step = 3;
  }


  List<SchemaRecord> get _activeSchemas =>
      SchemaMockData.schemas.where((s) => s.isActive).toList();

  List<HolderRecord> get _filteredHolders {
    final q = _holderSearch.toLowerCase().trim();
    if (q.isEmpty) return _holders;
    return _holders
        .where(
          (h) =>
              h.fullName.toLowerCase().contains(q) ||
              h.id.toLowerCase().contains(q) ||
              h.email.toLowerCase().contains(q) ||
              h.college.toLowerCase().contains(q) ||
              h.emiratesID.toLowerCase().contains(q),
        )
        .toList();
  }

  void _initFields(SchemaRecord schema) {
    for (final c in _fieldCtrl.values) {
      c.dispose();
    }
    _fieldCtrl.clear();
    _fieldValues.clear();
    _expiryDate = null;
    _noExpiry = true;

    final defaults = _kSchemaDefaults[schema.id] ?? {};

    for (final f in schema.fields) {
      if (f.type == SchemaFieldType.text || f.type == SchemaFieldType.number) {
        final defaultVal = defaults[f.id] ?? '';
        _fieldValues[f.id] = defaultVal;
        final ctrl = TextEditingController(text: defaultVal);
        ctrl.addListener(() => _fieldValues[f.id] = ctrl.text);
        _fieldCtrl[f.id] = ctrl;
      } else {
        _fieldValues[f.id] = '';
      }
    }
  }

  bool _validateStep3() {
    if (_selectedSchema == null) return false;
    for (final f in _selectedSchema!.fields) {
      if (f.required && (_fieldValues[f.id] ?? '').trim().isEmpty) {
        return false;
      }
    }
    return _noExpiry || _expiryDate != null;
  }

  List<String> _getFilteredDropdownOptions(SchemaField f) {
    final schemaMap = SchemaMockData.degreesByCollege[_selectedSchema!.id];

    if (f.label == 'College') {
      if (schemaMap != null) return schemaMap.keys.toList();
      return f.dropdownOptions;
    }

    if (f.label == 'Degree Title') {
      String collegeValue = '';
      for (final field in _selectedSchema!.fields) {
        if (field.label == 'College') {
          collegeValue = _fieldValues[field.id] ?? '';
          break;
        }
      }

      if (collegeValue.isEmpty) return [];

      return schemaMap?[collegeValue] ?? [];
    }
    return f.dropdownOptions;
  }

  Future<void> _startIssuing() async {
    final holder = _selectedHolder!;
    final emiratesID = holder.emiratesID;
    if (emiratesID.isEmpty) {
      if (!mounted) return;
      setState(() {
        _issuingStatus = 'Error: holder has no registered Emirates ID.';
      });
      return;
    }

    setState(() {
      _isIssuing = true;
      _issuingStatus = 'Signing credential with Dilithium...';
    });

    final infoMap = <String, String>{};
    for (final f in _selectedSchema!.fields) {
      infoMap[f.label] = _fieldValues[f.id] ?? '';
    }
    if (!_noExpiry && _expiryDate != null) {
      infoMap['expiryDate'] = DateFormatter.formatIsoDate(_expiryDate! as String?);
    }


    String dynamicCredentialType = _selectedSchema!.name;

    final titleKeys = [
      'Degree Title', 
      'Programme Name', 
      'Programme Title', 
      'Fellowship Title', 
    ];

    for (final key in titleKeys) {
      if (infoMap.containsKey(key) && infoMap[key]!.trim().isNotEmpty) {
        dynamicCredentialType = infoMap[key]!.trim();
        break; 
      }
    }

    if (_selectedSchema!.id == 'SCH-003' &&
        infoMap.containsKey('Research Field')) {
      dynamicCredentialType = 'PhD ${infoMap['Research Field']}'.trim();
    }

    setState(() => _issuingStatus = 'Submitting to blockchain...');

    final result = await IssuerApi.issueCredential(
      holderEmiratesID: emiratesID,
      credentialType: dynamicCredentialType, 
      info: jsonEncode(infoMap),
    );

    if (!mounted) return;

    setState(() {
      _isIssuing = false;
      if (result.success) {
        _issued = true;
        _issuedId = result.credentialID;
        _issueError = '';
      } else {
        _issueError = result.error ?? 'Unknown error';
      }
    });
  }

  void _goNext() {
    switch (_step) {
      case 1:
        if (_selectedSchema == null) {
          setState(() => _step1Error = true);
          return;
        }
        _initFields(_selectedSchema!);
        setState(() {
          _step1Error = false;
          _step = 2;
        });
        _loadHolders(); 
        break;

      case 2:
        if (_selectedHolder == null) {
          setState(() => _step2Error = true);
          return;
        }
        setState(() {
          _step2Error = false;
          _step = 3;
        });
        break;
      case 3:
        if (!_validateStep3()) {
          setState(() => _step3Error = true);
          return;
        }
        setState(() {
          _step3Error = false;
          _step = 4;
        });
        break;
      case 4:
        setState(() => _step = 5);
        break;
      case 5:
        if (_confirmed) {
          setState(() => _issueError = ''); 
          _startIssuing();
        }
        break;
    }
  }

  void _goBack() {
    if (_step > 1) setState(() => _step--);
  }

  Future<void> _loadHolders() async {
    if (!mounted) return;
    setState(() {
      _holdersLoading = true;
      _holdersError = false;
    });
    try {
      final data = await HolderApi.getHolders();
      if (!mounted) return;
      setState(() {
        _holders = data;
        _holdersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _holdersLoading = false;
        _holdersError = true;
      });
    }
  }

  // ─── ROOT BUILD ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_issued) return _buildSuccess();

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Issue Single Credential',
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
          _buildBottomButtons(),
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

    if (_holdersLoading && _holders.isEmpty) {
      return _card(child: const Center(child: CircularProgressIndicator()));
    }

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

          // left side
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

          // right side
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
        // Header
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
        _previewDivider('WHAT IS REQUIRED'),
        const SizedBox(height: 8),
        ...s.requirements.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.circle,
                    size: 4,
                    color: AppColors.issuingAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r,
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        _previewDivider('CREDENTIAL FIELDS'),
        const SizedBox(height: 8),
        ...s.fields.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                Icon(
                  Icons.subdirectory_arrow_right,
                  size: 12,
                  color: AppColors.textDim,
                ),
                const SizedBox(width: 6),
                Text(
                  f.label,
                  style: AppTextStyles.bodyTiny.copyWith(fontSize: 11),
                ),
                if (f.required)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '*',
                      style: TextStyle(fontSize: 11, color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        Row(
          children: [
            _statChip('${s.credentialsIssued}', 'Issued'),
            const SizedBox(width: 8),
            _statChip('${s.fieldsCount}', 'Fields'),
          ],
        ),
      ],
    );
  }

  Widget _previewDivider(String label) {
    return Row(
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
  }

  Widget _statChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
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
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2 — Find Holder
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStep2() {
    if (_holdersLoading && _holders.isEmpty) {
      return _card(child: const Center(child: CircularProgressIndicator()));
    }
    if (_holdersError) {
      return _card(child: ConnectionErrorWidget(onRetry: _loadHolders));
    }

    final holders = _filteredHolders;

    return _card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                CountChip(count: _holders.length, label: "holder"),
                Spacer(),
                ToolbarIconBtn(
                  icon: Icons.filter_list_rounded,
                  tooltip: 'Filter',
                  onTap: () {},
                ),
                const SizedBox(width: 10),
                QSearchBar(
                  controller: _searchCtrl,
                  query: _holderSearch,
                  onChanged: (v) => setState(() => _holderSearch = v),
                  onClear: () => setState(() => _holderSearch = ''),
                  searchLabel: 'Search holders...',
                  barWidth: 240,
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.issuingAccent.withOpacity(0.16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(
              children: [
                const SizedBox(width: 40),
                ColHead('NAME', flex: 3),
                ColHead('TYPE', flex: 2),
                ColHead('COLLEGE', flex: 3),
                ColHead('EID', flex: 2),
                const SizedBox(width: 80),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.border),


          Expanded(
            child: holders.isEmpty
                ? const Center(
                    child: Text(
                      'No holders found.',
                      style: TextStyle(color: AppColors.textDim, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    itemCount: holders.length,
                    separatorBuilder: (_, __) =>
                        Container(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) => HolderRow(
                      holder: holders[i],
                      isSelected:
                          _selectedHolder?.emiratesID == holders[i].emiratesID,
                      onToggle: () => setState(() {
                        _step2Error = false;
                        if (_selectedHolder?.emiratesID ==
                            holders[i].emiratesID) {
                          _selectedHolder = null; 
                        } else {
                          _selectedHolder = holders[i];
                        }
                      }),
                    ),
                  ),
          ),

          if (_selectedHolder != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                border: const Border(
                  top: BorderSide(color: Color(0xFF4CAF50), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 13,
                    color: Color(0xFF4CAF50),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedHolder!.fullName} selected — ${_selectedHolder!.emiratesID}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3 — Fill Credential Details
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStep3() {
    final schema = _selectedSchema!;

    return _card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _holderChip(schema),
            const SizedBox(height: 20),

            ...schema.fields.map((f) => _buildField(f)),

            const SizedBox(height: 4),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 14),

            _buildExpiryRow(),
          ],
        ),
      ),
    );
  }

  Widget _holderChip(SchemaRecord schema) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          HolderAvatar(holder: _selectedHolder!),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedHolder!.fullName,
                  style: AppTextStyles.navLabelActive.copyWith(fontSize: 12),
                ),
                Text(
                  '${_selectedHolder!.emiratesID}  ·  ${_selectedHolder!.type.label}',
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 10,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.issuingAccent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              schema.name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.issuingAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(SchemaField f) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(f.label, required: f.required),
          const SizedBox(height: 6),
          if (f.type == SchemaFieldType.text ||
              f.type == SchemaFieldType.number)
            _StyledTextField(
              controller: _fieldCtrl[f.id]!,
              hint: f.type == SchemaFieldType.number
                  ? 'Enter number…'
                  : 'Enter ${f.label.toLowerCase()}…',
              keyboardType: f.type == SchemaFieldType.number
                  ? TextInputType.number
                  : TextInputType.text,
            )
          else if (f.type == SchemaFieldType.dropdown)
            Builder(
              builder: (context) {
                final options = _getFilteredDropdownOptions(f);
                final currentValue = _fieldValues[f.id] ?? '';
                final validValue = options.contains(currentValue)
                    ? currentValue
                    : null;

                final isDisabled = f.label == 'Degree Title' && options.isEmpty;

                return _StyledDropdown(
                  value: validValue,
                  hint: isDisabled
                      ? 'Select College first...'
                      : 'Select ${f.label.toLowerCase()}',
                  options: options,
                  onChanged: isDisabled
                      ? null
                      : (v) => setState(() {
                          _fieldValues[f.id] = v ?? '';
                          _step3Error = false;
                        }),
                );
              },
            )
          else if (f.type == SchemaFieldType.yesNo)
            _YesNoToggle(
              value: _fieldValues[f.id],
              onChanged: (v) => setState(() {
                _fieldValues[f.id] = v;
                _step3Error = false;
              }),
            )
          else if (f.type == SchemaFieldType.date)
            DatePickerButton(
              value: (_fieldValues[f.id] ?? '').isEmpty
                  ? null
                  : _fieldValues[f.id],
              onPick: (picked) => setState(() {
                _fieldValues[f.id] = DateFormatter.formatIsoDate(picked as String?);
                _step3Error = false;
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildExpiryRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Expiry Date', required: !_noExpiry),
              const SizedBox(height: 6),
              DatePickerButton(
                value: _noExpiry
                    ? 'No expiry set'
                    : (_expiryDate != null ? DateFormatter.formatIsoDate(_expiryDate! as String?) : null),
                disabled: _noExpiry,
                hint: 'Select expiry date',
                onPick: (picked) => setState(() {
                  _expiryDate = picked;
                  _step3Error = false;
                }),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('No Expiry'),
            const SizedBox(height: 4),
            IgnorePointer(
              child: Switch(
                value: _noExpiry,
                onChanged: (v) {},
                activeThumbColor: AppColors.issuingAccent,
                activeTrackColor: AppColors.issuingAccent.withOpacity(0.22),
                inactiveThumbColor: AppColors.textDim,
                inactiveTrackColor: AppColors.surfaceHover,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 4 — Credential Preview
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStep4() {
    return _card(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: CredentialPreviewCard(
              schema: _selectedSchema!,
              holder: _selectedHolder!,
              fieldValues: Map.from(_fieldValues),
              expiryDate: _noExpiry ? null : _expiryDate,
              noExpiry: _noExpiry,
              orgName: kOrgName,
              issuerName: kCurrentUser,
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 5 — Confirm & Issue
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStep5() {
    if (_isIssuing) {
      return _card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 38,
                height: 38,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.issuingAccent,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _issuingStatus,
                style: AppTextStyles.navLabelActive.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return _card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _previewDivider('SUMMARY'),
            const SizedBox(height: 14),
            _summaryRow('Issued To', _selectedHolder!.fullName),
            _summaryRow('Holder ID', _selectedHolder!.id),
            _summaryRow('Credential Type', _selectedSchema!.name),
            _summaryRow(
              'Expiry Date',
              _noExpiry
                  ? 'No expiry'
                  : _expiryDate != null
                  ? DateFormatter.formatIsoDate(_expiryDate! as String?)
                  : '—',
            ),
            _summaryRow('Issued By', kCurrentUser),
            _summaryRow('Organization', kOrgName),
            _summaryRow('Signing Algorithm', 'Dilithium (CRYSTALS-Dilithium3)'),
            const SizedBox(height: 20),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => _confirmed = !_confirmed),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _confirmed,
                      onChanged: (v) => setState(() => _confirmed = v ?? false),
                      activeColor: AppColors.issuingAccent,
                      checkColor: Colors.white,
                      side: const BorderSide(
                        color: AppColors.border,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'I confirm this information is correct and I am authorized '
                      'to issue this credential on behalf of $kOrgName.',
                      style: AppTextStyles.bodyTiny.copyWith(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
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

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 170,
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

  // ── SUCCESS ───────────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.issuingAccent.withOpacity(0.14),
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 40,
                color: AppColors.issuingAccent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Credential Issued Successfully',
              style: AppTextStyles.navLabelActive.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceHover,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Credential ID: $_issuedId',
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '"${_selectedHolder?.fullName}" has been notified via QWallet',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                color: AppColors.textDim,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (isSmallScreen(context)) ...[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppButton(
                    label: 'See All Credentials',
                    onTap: widget.onCancel,
                    width: 190,
                    showBorder: true,
                    borderColor: AppColors.border,
                    hoverColor: AppColors.surfaceHover,
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Issue Another Credential',
                    backgroundColor: AppColors.issuingAccent,
                    hoverColor: AppColors.issuingAccent.withOpacity(0.82),
                    onTap: widget.onIssueAnother,
                    width: 190,
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppButton(
                    label: 'See All Credentials',
                    onTap: widget.onCancel,
                    width: 164,
                    showBorder: true,
                    borderColor: AppColors.issuingAccent,
                    hoverColor: AppColors.surfaceHover,
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'Issue Another Credential',
                    backgroundColor: AppColors.issuingAccent,
                    hoverColor: AppColors.issuingAccent.withOpacity(0.82),
                    onTap: widget.onIssueAnother,
                    width: 190,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── BOTTOM BUTTONS ───────────────────────────────────────────────────────

  Widget _buildBottomButtons() {
    String? errorMsg;
    if (_step == 1 && _step1Error) {
      errorMsg = 'Please select a credential type to continue.';
    } else if (_step == 2 && _step2Error) {
      errorMsg = 'Please select a holder to continue.';
    } else if (_step == 3 && _step3Error) {
      errorMsg = 'Please complete all required fields.';
    } else if (_step == 5 && _issueError.isNotEmpty) {
      errorMsg = _issueError;
    }

    return Row(
      children: [
        if (_step == 1)
          AppButton(
            label: 'Cancel',
            onTap: widget.onCancel,
            width: 80,
            backgroundColor: Colors.red,
            showBorder: true,
            borderColor: Colors.redAccent,
            hoverColor: AppColors.surfaceHover,
          ),
        if (_step == 1) const SizedBox(width: 10),
        if (_step > 1)
          AppButton(
            label: '← Back',
            onTap: _goBack,
            width: 80,
            showBorder: true,
            borderColor: AppColors.border,
            hoverColor: AppColors.surfaceHover,
          ),
        if (_step > 1) const SizedBox(width: 10),
        if (_step == 4)
          AppButton(
            label: 'Edit Details',
            onTap: () => setState(() => _step = 3),
            width: 107,
            showBorder: true,
            borderColor: AppColors.issuingAccent,
            hoverColor: AppColors.surfaceHover,
          ),
        if (_step == 4) const SizedBox(width: 10),
        AppButton(
          label: _step == _kTotalSteps ? 'Issue Credential' : 'Next →',
          backgroundColor: AppColors.issuingAccent,
          hoverColor: AppColors.issuingAccent.withOpacity(0.82),
          enabled: _step == _kTotalSteps ? _confirmed : true,
          onTap: _goNext,
          width: _step == _kTotalSteps ? 150 : 90,
        ),
        if (errorMsg != null) ...[
          const SizedBox(width: 14),
          const Icon(Icons.error_outline, size: 13, color: Colors.redAccent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              errorMsg,
              style: const TextStyle(fontSize: 11, color: Colors.redAccent),
            ),
          ),
        ],
      ],
    );
  }

  // Helper
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }

  Widget _fieldLabel(String label, {bool required = false}) => Row(
    children: [
      Text(
        label,
        style: AppTextStyles.bodyTiny.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      ),
      if (required)
        const Text(
          '  *',
          style: TextStyle(fontSize: 11, color: Colors.redAccent),
        ),
    ],
  );

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final c in _fieldCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  const _StyledTextField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    style: const TextStyle(fontSize: 12, color: Colors.white),
    decoration: InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textDim),
      filled: true,
      fillColor: AppColors.surfaceHover,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: AppColors.issuingAccent, width: 1.5),
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// STYLED DROPDOWN
// ═════════════════════════════════════════════════════════════════════════════

class _StyledDropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> options;
  final ValueChanged<String?>? onChanged; 

  const _StyledDropdown({
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onChanged == null; 

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      hint: Text(
        hint,
        style: TextStyle(
          fontSize: 12,
          color: isDisabled ? AppColors.textMuted : AppColors.textDim,
        ),
      ),
      dropdownColor: const Color(0xFF1C1C1C),
      style: const TextStyle(fontSize: 12, color: Colors.white),
      icon: Icon(
        Icons.keyboard_arrow_down,
        size: 18,
        color: isDisabled
            ? AppColors.textMuted.withOpacity(0.3)
            : AppColors.textDim,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        filled: true,
        fillColor: isDisabled
            ? AppColors.surfaceHover.withOpacity(0.4)
            : AppColors.surfaceHover,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: AppColors.issuingAccent, width: 1.5),
        ),
      ),
      items: isDisabled || options.isEmpty
          ? null
          : options
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
      onChanged: onChanged,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// YES / NO TOGGLE
// ═════════════════════════════════════════════════════════════════════════════

class _YesNoToggle extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  const _YesNoToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
    children: ['Yes', 'No'].map((opt) {
      final sel = value == opt;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => onChanged(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.issuingAccent.withOpacity(0.14)
                    : AppColors.surfaceHover,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: sel ? AppColors.issuingAccent : AppColors.border,
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Text(
                opt,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? AppColors.issuingAccent : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}
