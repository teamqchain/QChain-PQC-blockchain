// screens/issuer/create_schema_page.dart
//
// Create New Schema — 4-step wizard.
//   Step 1 — Basic Info          (name, description, category)
//   Step 2 — Define Fields       (add / delete / reorder field rows)
//   Step 3 — Schema Preview      (QWallet card + Verifier card)
//   Step 4 — Register            (warning + blockchain register)
//
// ── Integration ──────────────────────────────────────────────────────────────
//   Add route constant in RouteName:
//     static const createSchema = '/issue/schema-create';
//
//   Add to RouteName.all:
//     createSchema,
//
//   Update SchemasPage callback:
//     SchemasPage(
//       onViewSchema:      (id) => _handleNavigate(RouteName.schemaDetail, arg: id),
//       onCreateNewSchema: ()   => _handleNavigate(RouteName.createSchema),
//     );
//
//   Add to _buildPage():
//     case RouteName.createSchema:
//       return CreateSchemaPage(
//         onCancel:       () => _handleNavigate(RouteName.schemas),
//         onReturnToDash: () => _handleNavigate(RouteName.dashboard),
//         onAddNewSchema: () => _handleNavigate(RouteName.createSchema),
//       );

import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/label.dart';
import 'package:qportal_webapp/components/stepper.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/app_button.dart';

// ─── CONSTANTS ────────────────────────────────────────────────────────────────

const _kStepLabels = ['Basic Info', 'Define Fields', 'Preview', 'Register'];

const _kCategories = [
  'Academic',
  'Government',
  'Professional',
  'Medical',
  'Corporate',
  'Other',
];

const _kNameWordLimit = 8;
const _kDescWordLimit = 60;

// ═════════════════════════════════════════════════════════════════════════════
//  FIELD MODEL
// ═════════════════════════════════════════════════════════════════════════════

class _Field {
  final String id;
  final TextEditingController labelCtrl;
  SchemaFieldType type;
  bool isRequired;
  final TextEditingController optionsCtrl;

  _Field({
    required this.id,
    String label = '',
    this.type = SchemaFieldType.text,
    this.isRequired = true,
    String options = '',
  }) : labelCtrl = TextEditingController(text: label),
       optionsCtrl = TextEditingController(text: options);

  factory _Field.blank() =>
      _Field(id: 'f_${DateTime.now().microsecondsSinceEpoch}');

  List<String> get parsedOptions => optionsCtrl.text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  void dispose() {
    labelCtrl.dispose();
    optionsCtrl.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class CreateSchemaPage extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onReturnToDash;
  final VoidCallback onAddNewSchema;

  const CreateSchemaPage({
    super.key,
    required this.onCancel,
    required this.onReturnToDash,
    required this.onAddNewSchema,
  });

  @override
  State<CreateSchemaPage> createState() => _CreateSchemaPageState();
}

class _CreateSchemaPageState extends State<CreateSchemaPage> {
  int _step = 1;

  // ── Step 1 state ──────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _category;
  String _nameError = '';
  String _descError = '';
  bool _categoryError = false;

  // ── Step 2 state ──────────────────────────────────────────────────────────
  final List<_Field> _fields = [];
  String? _selectedFieldId;

  // ── word helpers ──────────────────────────────────────────────────────────

  int _wordCount(String text) =>
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  // ── step 1 validation ─────────────────────────────────────────────────────

  bool _validateStep1() {
    final nameWc = _wordCount(_nameCtrl.text);
    final descWc = _wordCount(_descCtrl.text);
    final ne = _nameCtrl.text.trim().isEmpty
        ? 'Schema name is required.'
        : nameWc > _kNameWordLimit
        ? 'Name must be $_kNameWordLimit words or fewer ($nameWc used).'
        : '';
    final de = _descCtrl.text.trim().isEmpty
        ? 'Description is required.'
        : descWc > _kDescWordLimit
        ? 'Description must be $_kDescWordLimit words or fewer ($descWc used).'
        : '';
    setState(() {
      _nameError = ne;
      _descError = de;
      _categoryError = _category == null;
    });
    return ne.isEmpty && de.isEmpty && _category != null;
  }

  // ── step 2 readiness ──────────────────────────────────────────────────────

  bool get _step2Ready =>
      _fields.isNotEmpty &&
      _fields.every((f) => f.labelCtrl.text.trim().isNotEmpty);

  String? get _step2Tooltip {
    if (_fields.isEmpty) return 'Add at least one field to continue.';
    if (!_step2Ready) return 'All fields must have a label.';
    return null;
  }

  // ── field management ───────────────────────────────────────────────────────

  void _addField() {
    final f = _Field.blank();
    setState(() {
      _fields.add(f);
      _selectedFieldId = f.id;
    });
  }

  void _deleteSelected() {
    if (_selectedFieldId == null) return;
    final f = _fields.firstWhere((x) => x.id == _selectedFieldId);
    f.dispose();
    setState(() {
      _fields.removeWhere((x) => x.id == _selectedFieldId);
      _selectedFieldId = null;
    });
  }

  void _moveUp(int i) {
    if (i <= 0) return;
    setState(() {
      final tmp = _fields[i];
      _fields[i] = _fields[i - 1];
      _fields[i - 1] = tmp;
    });
  }

  void _moveDown(int i) {
    if (i >= _fields.length - 1) return;
    setState(() {
      final tmp = _fields[i];
      _fields[i] = _fields[i + 1];
      _fields[i + 1] = tmp;
    });
  }

  // ── cancel from last step ─────────────────────────────────────────────────

  void _confirmCancel() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DiscardDialog(onDiscard: widget.onCancel),
    );
  }

  // ── register ───────────────────────────────────────────────────────────────

  void _register() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RegisterDialog(
        onReturnToDash: widget.onReturnToDash,
        onAddNewSchema: widget.onAddNewSchema,
      ),
    );
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
            'Create New Schema',
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
            accentColor: AppColors.issuingAccent,
          ),
          const SizedBox(height: 18),

          // Step content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              child: KeyedSubtree(key: ValueKey(_step), child: _buildStep()),
            ),
          ),
          const SizedBox(height: 16),

          // Navigation buttons
          _buildNavRow(),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 1:
        return _Step1Body(
          nameCtrl: _nameCtrl,
          descCtrl: _descCtrl,
          category: _category,
          nameError: _nameError,
          descError: _descError,
          categoryError: _categoryError,
          onCategoryChanged: (v) => setState(() {
            _category = v;
            _categoryError = false;
          }),
          onTextChanged: () => setState(() {}),
        );
      case 2:
        return _Step2Body(
          fields: _fields,
          selectedId: _selectedFieldId,
          onSelect: (id) => setState(() => _selectedFieldId = id),
          onAdd: _addField,
          onDelete: _deleteSelected,
          onMoveUp: _moveUp,
          onMoveDown: _moveDown,
          onTypeChanged: (i, t) => setState(() => _fields[i].type = t),
          onRequiredChanged: (i, v) =>
              setState(() => _fields[i].isRequired = v),
          onRebuild: () => setState(() {}),
        );
      case 3:
        return _Step3Body(
          schemaName: _nameCtrl.text,
          category: _category ?? '',
          fields: _fields,
        );
      default:
        return const _Step4Body();
    }
  }

  Widget _buildNavRow() {
    switch (_step) {
      case 1:
        return Row(
          children: [
            AppButton(label: 'Cancel', onTap: widget.onCancel, backgroundColor: Colors.red, showBorder: true, borderColor: Colors.redAccent, hoverColor: AppColors.surfaceHover),
            const SizedBox(width: 10),
            AppButton(
              label: 'Next',
              backgroundColor: AppColors.issuingAccent,
              hoverColor: AppColors.issuingAccent.withOpacity(0.82),
              icon: Icons.arrow_forward_rounded,
              onTap: () {
                if (_validateStep1()) setState(() => _step = 2);
              },
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
              hoverColor: AppColors.surfaceHover,
            ),
            const SizedBox(width: 10),
            AppButton(
              label: 'Next',
              backgroundColor: AppColors.issuingAccent,
              hoverColor: AppColors.issuingAccent.withOpacity(0.82),
              icon: Icons.arrow_forward_rounded,
              enabled: _step2Ready,
              tooltip: _step2Tooltip,
              onTap: () => setState(() => _step = 3),
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
              hoverColor: AppColors.surfaceHover,
            ),
            const SizedBox(width: 10),
            AppButton(
              label: 'Next',
              backgroundColor: AppColors.issuingAccent,
              hoverColor: AppColors.issuingAccent.withOpacity(0.82),
              icon: Icons.arrow_forward_rounded,
              onTap: () => setState(() => _step = 4),
              iconRight: true,
            ),
          ],
        );
      default: // step 4
        return Row(
          children: [
            AppButton(label: 'Cancel', onTap: _confirmCancel, backgroundColor: Colors.red, showBorder: true, borderColor: Colors.redAccent, hoverColor: AppColors.surfaceHover),
            const SizedBox(width: 10),
            AppButton(
              label: 'Register',
              backgroundColor: AppColors.issuingAccent,
              hoverColor: AppColors.issuingAccent.withOpacity(0.82),
              icon: Icons.link_rounded,
              onTap: _register,
            ),
          ],
        );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STEP 1 — BASIC INFO
// ═════════════════════════════════════════════════════════════════════════════

class _Step1Body extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final String? category;
  final String nameError;
  final String descError;
  final bool categoryError;
  final void Function(String?) onCategoryChanged;
  final VoidCallback onTextChanged;

  const _Step1Body({
    required this.nameCtrl,
    required this.descCtrl,
    required this.category,
    required this.nameError,
    required this.descError,
    required this.categoryError,
    required this.onCategoryChanged,
    required this.onTextChanged,
  });

  int _wc(String t) =>
      t.trim().isEmpty ? 0 : t.trim().split(RegExp(r'\s+')).length;

  @override
  Widget build(BuildContext context) {
    final nameWc = _wc(nameCtrl.text);
    final descWc = _wc(descCtrl.text);

    return _Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(step: 1, label: 'Basic Schema Information'),
            const SizedBox(height: 24),

            // Schema Name
            Label(
              text: 'Schema Name',
              required: true,
              counter: '$nameWc / $_kNameWordLimit words',
              counterExceeded: nameWc > _kNameWordLimit,
            ),
            const SizedBox(height: 6),
            _TextInput(
              controller: nameCtrl,
              hint: 'e.g. BSc Degree Certificate',
              hasError: nameError.isNotEmpty,
              onChanged: (_) => onTextChanged(),
            ),
            if (nameError.isNotEmpty) ...[
              const SizedBox(height: 5),
              _ErrorRow(nameError),
            ],
            const SizedBox(height: 20),

            // Schema Description
            Label(
              text: 'Schema Description',
              required: true,
              counter: '$descWc / $_kDescWordLimit words',
              counterExceeded: descWc > _kDescWordLimit,
            ),
            const SizedBox(height: 6),
            _TextInput(
              controller: descCtrl,
              hint: 'Describe what this schema represents and when it is used…',
              maxLines: 4,
              hasError: descError.isNotEmpty,
              onChanged: (_) => onTextChanged(),
            ),
            if (descError.isNotEmpty) ...[
              const SizedBox(height: 5),
              _ErrorRow(descError),
            ],
            const SizedBox(height: 20),

            // Category
            Label(text: 'Schema Category', required: true),
            const SizedBox(height: 6),
            _CategoryDropdown(
              value: category,
              hasError: categoryError,
              onChanged: onCategoryChanged,
            ),
            if (categoryError) ...[
              const SizedBox(height: 5),
              _ErrorRow('Please select a category.'),
            ],
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STEP 2 — DEFINE FIELDS
// ═════════════════════════════════════════════════════════════════════════════

class _Step2Body extends StatelessWidget {
  final List<_Field> fields;
  final String? selectedId;
  final void Function(String?) onSelect;
  final VoidCallback onAdd;
  final VoidCallback onDelete;
  final void Function(int) onMoveUp;
  final void Function(int) onMoveDown;
  final void Function(int, SchemaFieldType) onTypeChanged;
  final void Function(int, bool) onRequiredChanged;
  final VoidCallback onRebuild;

  const _Step2Body({
    required this.fields,
    required this.selectedId,
    required this.onSelect,
    required this.onAdd,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onTypeChanged,
    required this.onRequiredChanged,
    required this.onRebuild,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          // ── Header bar ────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF161616),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _SectionTitle(step: 2, label: 'Define Schema Fields'),
                const Spacer(),
                if (fields.isNotEmpty) _CountChip(count: fields.length),
              ],
            ),
          ),

          // ── Column header (only when fields exist) ────────────────────
          if (fields.isNotEmpty) _FieldColHeader(),

          // ── Field rows ─────────────────────────────────────────────────
          Expanded(
            child: fields.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.table_rows_outlined,
                          size: 36,
                          color: AppColors.textDim,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No fields yet.\nClick "Add Field" to define the first field.',
                          style: AppTextStyles.bodyTiny.copyWith(
                            fontSize: 12,
                            color: AppColors.textDim,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: fields.length,
                    separatorBuilder: (_, __) =>
                        Container(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) => _FieldRow(
                      field: fields[i],
                      index: i,
                      total: fields.length,
                      selected: fields[i].id == selectedId,
                      onSelect: () => onSelect(
                        fields[i].id == selectedId ? null : fields[i].id,
                      ),
                      onMoveUp: () => onMoveUp(i),
                      onMoveDown: () => onMoveDown(i),
                      onTypeChanged: (t) => onTypeChanged(i, t),
                      onRequiredChanged: (v) => onRequiredChanged(i, v),
                      onRebuild: onRebuild,
                    ),
                  ),
          ),

          // ── Add / Delete bar — always visible ─────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF161616),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                _BarBtn(
                  icon: Icons.add_rounded,
                  label: 'Add Field',
                  color: AppColors.issuingAccent,
                  onTap: onAdd,
                ),
                const SizedBox(width: 10),
                _BarBtn(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete Field',
                  color: AppColors.revoked,
                  enabled: selectedId != null,
                  tooltip: selectedId == null
                      ? 'Select a field row first'
                      : null,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── FIELD ROW ────────────────────────────────────────────────────────────────

class _FieldRow extends StatefulWidget {
  final _Field field;
  final int index;
  final int total;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final void Function(SchemaFieldType) onTypeChanged;
  final void Function(bool) onRequiredChanged;
  final VoidCallback onRebuild;

  const _FieldRow({
    required this.field,
    required this.index,
    required this.total,
    required this.selected,
    required this.onSelect,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onTypeChanged,
    required this.onRequiredChanged,
    required this.onRebuild,
  });

  @override
  State<_FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<_FieldRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.field;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: widget.selected
              ? AppColors.issuingAccent.withOpacity(0.07)
              : _hovered
              ? AppColors.surfaceHover
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Move up / down
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MoveBtn(
                        icon: Icons.keyboard_arrow_up_rounded,
                        enabled: widget.index > 0,
                        onTap: widget.onMoveUp,
                      ),
                      _MoveBtn(
                        icon: Icons.keyboard_arrow_down_rounded,
                        enabled: widget.index < widget.total - 1,
                        onTap: widget.onMoveDown,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),

                  // Index badge
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.issuingAccent.withOpacity(0.12),
                      border: Border.all(
                        color: AppColors.issuingAccent.withOpacity(0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.index + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.issuingLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Field label
                  Expanded(
                    flex: 3,
                    child: _RowInput(
                      controller: f.labelCtrl,
                      hint: 'Field label…',
                      onChanged: (_) => widget.onRebuild(),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Field type
                  Expanded(
                    flex: 2,
                    child: _TypeDropdown(
                      value: f.type,
                      onChanged: (t) {
                        widget.onTypeChanged(t);
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Required toggle
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: 0.78,
                        child: Switch(
                          value: f.isRequired,
                          onChanged: (v) {
                            widget.onRequiredChanged(v);
                            setState(() {});
                          },
                          activeColor: AppColors.issuingAccent,
                          activeTrackColor: AppColors.issuingAccent.withOpacity(
                            0.3,
                          ),
                          inactiveThumbColor: AppColors.textDim,
                          inactiveTrackColor: AppColors.border,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      Text(
                        f.isRequired ? 'Required' : 'Optional',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: f.isRequired
                              ? AppColors.issuingAccent
                              : AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),

                  // Select checkbox
                  Checkbox(
                    value: widget.selected,
                    onChanged: (_) => widget.onSelect(),
                    activeColor: AppColors.revoked,
                    checkColor: Colors.white,
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              // Dropdown options (only visible when type == dropdown)
              if (f.type == SchemaFieldType.dropdown) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 62),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.list_rounded,
                        size: 11,
                        color: AppColors.textDim,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Options:',
                        style: AppTextStyles.bodyTiny.copyWith(
                          fontSize: 10,
                          color: AppColors.textDim,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _RowInput(
                          controller: f.optionsCtrl,
                          hint: 'Option A, Option B, Option C…',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STEP 3 — PREVIEW
// ═════════════════════════════════════════════════════════════════════════════

class _Step3Body extends StatelessWidget {
  final String schemaName;
  final String category;
  final List<_Field> fields;

  const _Step3Body({
    required this.schemaName,
    required this.category,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(step: 3, label: 'Schema Preview'),
            const SizedBox(height: 6),
            Text(
              'Review how this schema will appear across the system before registering.',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                color: AppColors.textDim,
              ),
            ),
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (_, c) {
                if (c.maxWidth > 580) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _QWalletCard(
                          schemaName: schemaName,
                          category: category,
                          fields: fields,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _VerifierCard(
                          schemaName: schemaName,
                          fields: fields,
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _QWalletCard(
                      schemaName: schemaName,
                      category: category,
                      fields: fields,
                    ),
                    const SizedBox(height: 16),
                    _VerifierCard(schemaName: schemaName, fields: fields),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── QWALLET CARD ─────────────────────────────────────────────────────────────

class _QWalletCard extends StatelessWidget {
  final String schemaName;
  final String category;
  final List<_Field> fields;

  const _QWalletCard({
    required this.schemaName,
    required this.category,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    final name = schemaName.trim().isEmpty ? 'Untitled Schema' : schemaName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.wallet_outlined,
              size: 13,
              color: AppColors.issuingAccent,
            ),
            const SizedBox(width: 7),
            Text(
              'QWallet Credential Card',
              style: AppTextStyles.navLabelActive.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.issuingDark, AppColors.issuingMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.issuingAccent.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: AppColors.issuingAccent.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        category.isEmpty ? 'General' : category,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.valid.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: AppColors.valid.withOpacity(0.4),
                      ),
                    ),
                    child: const Text(
                      'VALID',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.valid,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: Colors.white.withOpacity(0.08)),
              const SizedBox(height: 14),

              // Field stubs
              if (fields.isEmpty)
                Text(
                  'No fields defined',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.35),
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ...fields.take(6).map((f) {
                  final lbl = f.labelCtrl.text.trim().isEmpty
                      ? 'Field ${fields.indexOf(f) + 1}'
                      : f.labelCtrl.text.trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            lbl,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              if (fields.length > 6)
                Text(
                  '+ ${fields.length - 6} more field${fields.length - 6 == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.3),
                    fontStyle: FontStyle.italic,
                  ),
                ),

              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Holder Name',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        size: 11,
                        color: AppColors.issuingLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'QPortal',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── VERIFIER CARD ────────────────────────────────────────────────────────────

class _VerifierCard extends StatelessWidget {
  final String schemaName;
  final List<_Field> fields;

  const _VerifierCard({required this.schemaName, required this.fields});

  @override
  Widget build(BuildContext context) {
    final name = schemaName.trim().isEmpty ? 'Untitled Schema' : schemaName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.fact_check_outlined,
              size: 13,
              color: AppColors.verifyingAccent,
            ),
            const SizedBox(width: 7),
            Text(
              'Verifier Result Card',
              style: AppTextStyles.navLabelActive.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.verifyingDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.verifyingAccent.withOpacity(0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.verifyingAccent.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Verified banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.verifyingAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.verifyingAccent.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 13,
                      color: AppColors.verifyingAccent,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Verified — $name',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.verifyingLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Field stubs
              if (fields.isEmpty)
                Text(
                  'No fields defined',
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ...fields.take(6).map((f) {
                  final lbl = f.labelCtrl.text.trim().isEmpty
                      ? 'Field ${fields.indexOf(f) + 1}'
                      : f.labelCtrl.text.trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            lbl,
                            style: AppTextStyles.bodyTiny.copyWith(
                              fontSize: 10,
                              color: AppColors.textDim,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.verifyingAccent.withOpacity(
                                0.08,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              if (fields.length > 6)
                Text(
                  '+ ${fields.length - 6} more field${fields.length - 6 == 1 ? '' : 's'}',
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 10,
                    color: AppColors.textDim,
                    fontStyle: FontStyle.italic,
                  ),
                ),

              const SizedBox(height: 14),
              Container(
                height: 1,
                color: AppColors.verifyingAccent.withOpacity(0.1),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.link_rounded,
                    size: 11,
                    color: AppColors.textDim,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Blockchain verified · QPortal',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 10,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STEP 4 — REGISTER TO BLOCKCHAIN
// ═════════════════════════════════════════════════════════════════════════════

class _Step4Body extends StatelessWidget {
  const _Step4Body();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(step: 4, label: 'Register Schema to Blockchain'),
              const SizedBox(height: 28),

              // Warning box
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.suspended.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.suspended.withOpacity(0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 22,
                      color: AppColors.suspended,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Warning',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.suspended,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Once registered, fields cannot be removed. '
                            'New optional fields can be added later.',
                            style: AppTextStyles.bodyTiny.copyWith(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              height: 1.65,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Info box
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.issuingAccent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.issuingAccent.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      size: 15,
                      color: AppColors.issuingAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Clicking Register will permanently record this schema '
                        'on the blockchain and make it available in the '
                        'Issue Credential form.',
                        style: AppTextStyles.bodyTiny.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          height: 1.6,
                        ),
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
//  DISCARD CONFIRM DIALOG (Cancel from last step)
// ═════════════════════════════════════════════════════════════════════════════

class _DiscardDialog extends StatelessWidget {
  final VoidCallback onDiscard;
  const _DiscardDialog({required this.onDiscard});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 48,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.revoked.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 19,
                    color: AppColors.revoked,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Discard Schema?',
                  style: AppTextStyles.navLabelActive.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Text(
              'You are about to leave without registering. '
              'All changes made to this schema — including basic info, '
              'fields, and preview — will be permanently lost.',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'Stay',
                  onTap: () => Navigator.pop(context),
                  textColor: AppColors.textMuted,
                  showBorder: true,
                  borderColor: AppColors.border,
                  hoverColor: AppColors.surfaceHover,
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Discard',
                  backgroundColor: AppColors.revoked,
                  hoverColor: AppColors.revoked.withOpacity(0.82),
                  icon: Icons.delete_outline_rounded,
                  onTap: () {
                    Navigator.pop(context);
                    onDiscard();
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
//  REGISTER DIALOG  (progress → success)
// ═════════════════════════════════════════════════════════════════════════════

class _RegisterDialog extends StatefulWidget {
  final VoidCallback onReturnToDash;
  final VoidCallback onAddNewSchema;

  const _RegisterDialog({
    required this.onReturnToDash,
    required this.onAddNewSchema,
  });

  @override
  State<_RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<_RegisterDialog> {
  bool _done = false;
  double _progress = 0;
  String _statusLabel = 'Preparing schema…';

  @override
  void initState() {
    super.initState();
    _runRegistration();
  }

  Future<void> _runRegistration() async {
    final steps = [
      (0.15, 'Validating fields…'),
      (0.35, 'Generating schema DID…'),
      (0.55, 'Compiling credential definition…'),
      (0.75, 'Writing to blockchain…'),
      (0.90, 'Confirming transaction…'),
      (1.0, 'Complete'),
    ];

    for (final (value, label) in steps) {
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() {
        _progress = value;
        _statusLabel = label;
      });
    }

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 48,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: _done ? _buildSuccess() : _buildProgress(),
        ),
      ),
    );
  }

  // ── progress state ──────────────────────────────────────────────────────

  Widget _buildProgress() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated ring
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 3.5,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.issuingAccent,
                  ),
                ),
              ),
              Text(
                '${(_progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.issuingAccent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        Text(
          'Registering Schema',
          style: AppTextStyles.navLabelActive.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _statusLabel,
            key: ValueKey(_statusLabel),
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 5,
            width: double.infinity,
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.issuingAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── success state ───────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        const SizedBox(height: 18),

        Text(
          'Schema Registered',
          style: AppTextStyles.navLabelActive.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),

        Text(
          'Schema is now available in the\nIssue Credential form.',
          style: AppTextStyles.bodyTiny.copyWith(
            fontSize: 13,
            color: AppColors.textMuted,
            height: 1.65,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Return to Dashboard',
                onTap: () {
                  Navigator.pop(context);
                  widget.onReturnToDash();
                },
                showBorder: true,
                borderColor: AppColors.issuingAccent,
                hoverColor: AppColors.surfaceHover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Add New Schema',
                backgroundColor: AppColors.issuingAccent,
                hoverColor: AppColors.issuingAccent.withOpacity(0.82),
                icon: Icons.add_rounded,
                onTap: () {
                  Navigator.pop(context);
                  widget.onAddNewSchema();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHARED LAYOUT WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ─── STEP CARD (outer container) ─────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    clipBehavior: Clip.hardEdge,
    child: child,
  );
}

// ─── SECTION TITLE ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final int step;
  final String label;
  const _SectionTitle({required this.step, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.issuingAccent.withOpacity(0.14),
          border: Border.all(color: AppColors.issuingAccent.withOpacity(0.4)),
        ),
        child: Center(
          child: Text(
            '$step',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.issuingLight,
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

// ─── FIELD LABEL ROW ──────────────────────────────────────────────────────────



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
              ? AppColors.issuingAccent.withOpacity(0.6)
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
            ? AppColors.issuingAccent.withOpacity(0.55)
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

// ─── ROW INPUT (compact, inline in field rows) ────────────────────────────────

class _RowInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final void Function(String)? onChanged;

  const _RowInput({
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceHover,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppColors.issuingAccent.withOpacity(0.35)),
    ),
    child: TextField(
      controller: controller,
      style: const TextStyle(fontSize: 12, color: AppColors.text),
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: InputBorder.none,
        hintText: hint,
        hintStyle: AppTextStyles.bodyTiny.copyWith(
          fontSize: 11,
          color: AppColors.textDim,
        ),
      ),
    ),
  );
}

// ─── TYPE DROPDOWN (compact, for field rows) ──────────────────────────────────

class _TypeDropdown extends StatelessWidget {
  final SchemaFieldType value;
  final void Function(SchemaFieldType) onChanged;

  const _TypeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: AppColors.surfaceHover,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppColors.issuingAccent.withOpacity(0.35)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<SchemaFieldType>(
        value: value,
        isExpanded: true,
        isDense: true,
        dropdownColor: const Color(0xFF1E1E1E),
        iconEnabledColor: AppColors.textDim,
        style: const TextStyle(fontSize: 11, color: AppColors.text),
        items: SchemaFieldType.values
            .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
            .toList(),
        onChanged: (t) {
          if (t != null) onChanged(t);
        },
      ),
    ),
  );
}

// ─── FIELD COLUMN HEADER ──────────────────────────────────────────────────────

class _FieldColHeader extends StatelessWidget {
  const _FieldColHeader();

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF141414),
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    padding: const EdgeInsets.only(left: 58, right: 16, top: 7, bottom: 7),
    child: Row(
      children: [
        const SizedBox(width: 34), // index badge space
        const SizedBox(width: 12),
        _CH('FIELD LABEL', flex: 3),
        const SizedBox(width: 10),
        _CH('TYPE', flex: 2),
        const SizedBox(width: 10),
        _CH('REQUIRED', flex: 2),
        const SizedBox(width: 36), // checkbox
      ],
    ),
  );
}

Widget _CH(String label, {int flex = 1}) => Expanded(
  flex: flex,
  child: Text(
    label,
    style: AppTextStyles.bodyTiny.copyWith(
      fontSize: 9,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
      color: AppColors.textDim,
    ),
  ),
);

// ─── COUNT CHIP ───────────────────────────────────────────────────────────────

class _CountChip extends StatelessWidget {
  final int count;
  const _CountChip({required this.count});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.issuingAccent.withOpacity(0.12),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: AppColors.issuingAccent.withOpacity(0.3)),
    ),
    child: Text(
      '$count field${count == 1 ? '' : 's'}',
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.issuingAccent,
      ),
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

// ─── MOVE BUTTON ──────────────────────────────────────────────────────────────

class _MoveBtn extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _MoveBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_MoveBtn> createState() => _MoveBtnState();
}

class _MoveBtnState extends State<_MoveBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.enabled
        ? SystemMouseCursors.click
        : SystemMouseCursors.basic,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 18,
        height: 16,
        decoration: BoxDecoration(
          color: _h && widget.enabled
              ? AppColors.issuingAccent.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Icon(
          widget.icon,
          size: 14,
          color: widget.enabled
              ? AppColors.textMuted
              : AppColors.textDim.withOpacity(0.3),
        ),
      ),
    ),
  );
}

// ─── BAR BUTTON (Add Field / Delete Field) ────────────────────────────────────

class _BarBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  final String? tooltip;

  const _BarBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
    this.tooltip,
  });

  @override
  State<_BarBtn> createState() => _BarBtnState();
}

class _BarBtnState extends State<_BarBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.enabled ? widget.color : widget.color.withOpacity(0.26);

    Widget btn = MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _h && widget.enabled
                ? c.withOpacity(0.18)
                : c.withOpacity(0.10),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 13, color: c),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!widget.enabled && widget.tooltip != null) {
      btn = Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}
