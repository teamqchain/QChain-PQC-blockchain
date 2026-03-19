// screens/issuer/schema_detail_page.dart
//
// Schema Details — view + edit a single credential schema.
// Shows overview, field list (reorderable in edit mode), live form preview,
// and a save-confirmation dialog explaining downstream effects.
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   Add route constant:
//     static const schemaDetail = '/issue/schema-detail';
//
//   In _buildPage():
//     case RouteName.schemas:
//       return SchemasPage(
//         onViewSchema: (id) =>
//             _handleNavigate(RouteName.schemaDetail, arg: id),
//       );
//     case RouteName.schemaDetail:
//       final schema = IssuingMockData.schemas.firstWhere(
//         (s) => s.id == (_selectedCredentialId ?? ''),
//         orElse: () => IssuingMockData.schemas.first,
//       );
//       return SchemaDetailPage(
//         schema: schema,
//         onBack: () => _handleNavigate(RouteName.schemas),
//       );

import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/app_button.dart';

const _kCreatedBy = 'Mohammed A.';

// ─── EDITABLE FIELD MODEL ────────────────────────────────────────────────────

class _EditableField {
  final String id;
  final TextEditingController labelCtrl;
  SchemaFieldType type;
  bool isRequired;
  final TextEditingController optionsCtrl;
  final bool isNew;

  _EditableField({
    required this.id,
    required String label,
    required this.type,
    required this.isRequired,
    List<String> dropdownOptions = const [],
    this.isNew = false,
  }) : labelCtrl = TextEditingController(text: label),
       optionsCtrl = TextEditingController(text: dropdownOptions.join(', '));

  factory _EditableField.fromSchema(SchemaField f) => _EditableField(
    id: f.id,
    label: f.label,
    type: f.type,
    isRequired: f.required,
    dropdownOptions: f.dropdownOptions,
  );

  factory _EditableField.blank() => _EditableField(
    id: 'new_${DateTime.now().microsecondsSinceEpoch}',
    label: '',
    type: SchemaFieldType.text,
    isRequired: false,
    isNew: true,
  );

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

class SchemaDetailPage extends StatefulWidget {
  final SchemaRecord schema;
  final VoidCallback onBack;

  const SchemaDetailPage({
    super.key,
    required this.schema,
    required this.onBack,
  });

  @override
  State<SchemaDetailPage> createState() => _SchemaDetailPageState();
}

class _SchemaDetailPageState extends State<SchemaDetailPage> {
  bool _editing = false;
  String? _selectedFieldId;

  late List<_EditableField> _fields;
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _initFromSchema();
  }

  void _initFromSchema() {
    _fields = widget.schema.fields
        .map((f) => _EditableField.fromSchema(f))
        .toList();
    _nameCtrl = TextEditingController(text: widget.schema.name);
    _descCtrl = TextEditingController(text: widget.schema.description);
  }

  void _enterEdit() => setState(() => _editing = true);

  void _cancelEdit() {
    for (final f in _fields) f.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _initFromSchema();
    setState(() {
      _editing = false;
      _selectedFieldId = null;
    });
  }

  void _addField() => setState(() => _fields.add(_EditableField.blank()));

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

  Future<void> _requestSave() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _SaveConfirmDialog(onConfirm: () => setState(() => _editing = false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schema Details',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(child: _buildDetailCard()),
          const SizedBox(height: 16),
          _buildPageActions(),
        ],
      ),
    );
  }

  // ── DETAIL CARD ────────────────────────────────────────────────────────────

  Widget _buildDetailCard() {
    final s = widget.schema;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Overview
          Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _editing
                          ? _EditInput(
                              ctrl: _nameCtrl,
                              hint: 'Schema name…',
                              title: true,
                            )
                          : Text(
                              s.name,
                              style: AppTextStyles.navLabelActive.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                      const SizedBox(height: 6),
                      _editing
                          ? _EditInput(
                              ctrl: _descCtrl,
                              hint: 'Schema description…',
                              maxLines: 3,
                            )
                          : Text(
                              s.description,
                              style: AppTextStyles.bodyTiny.copyWith(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                height: 1.6,
                              ),
                            ),
                      const SizedBox(height: 14),
                      Row(

                        spacing: 10,
                        // runSpacing: 6,
                        children: [
                          _MetaChip(
                            icon: Icons.tag_rounded,
                            label: s.id,
                            mono: true,
                          ),
                          _MetaChip(
                            icon: Icons.calendar_today_outlined,
                            label: 'Created ${s.createdDate}',
                          ),
                          _MetaChip(
                            icon: Icons.person_outline_rounded,
                            label: _kCreatedBy,
                          ),
                          _CategoryChip(category: s.category),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                _IssuedBox(count: s.credentialsIssued),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.border),

          // Fields section
          Expanded(
            child: Column(
              children: [
                // Fields header bar
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF141414),
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.list_alt_outlined,
                        size: 14,
                        color: AppColors.issuingAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Schema Fields',
                        style: AppTextStyles.navLabelActive.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CountChip(count: _fields.length),
                      const Spacer(),
                    ],
                  ),
                ),

                // Column headers
                _FieldColHeader(editing: _editing),

                // Field rows
                Expanded(
                  child: _fields.isEmpty
                      ? _EmptyFields(editing: _editing)
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: _fields.length,
                          separatorBuilder: (_, __) =>
                              Container(height: 1, color: AppColors.border),
                          itemBuilder: (_, i) => _FieldRow(
                            field: _fields[i],
                            index: i,
                            total: _fields.length,
                            editing: _editing,
                            selected: _fields[i].id == _selectedFieldId,
                            onSelect: () => setState(() {
                              _selectedFieldId =
                                  _fields[i].id == _selectedFieldId
                                  ? null
                                  : _fields[i].id;
                            }),
                            onMoveUp: () => _moveUp(i),
                            onMoveDown: () => _moveDown(i),
                            onTypeChanged: (t) =>
                                setState(() => _fields[i].type = t),
                            onRequiredChanged: (v) =>
                                setState(() => _fields[i].isRequired = v),
                          ),
                        ),
                ),

                // Add / Delete bar (edit mode only)
                if (_editing)
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF161616),
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        _BarBtn(
                          icon: Icons.add_rounded,
                          label: 'Add Field',
                          color: AppColors.issuingAccent,
                          onTap: _addField,
                        ),
                        const SizedBox(width: 10),
                        _BarBtn(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete Field',
                          color: AppColors.revoked,
                          enabled:
                              _selectedFieldId != null &&
                              _fields.any(
                                (f) => f.id == _selectedFieldId && f.isNew,
                              ),
                          onTap: _deleteSelected,
                          tooltip: _selectedFieldId == null
                              ? 'Select a field row first'
                              : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── PAGE ACTIONS ────────────────────────────────────────────────────────────

  Widget _buildPageActions() => Row(
    children: [
      AppButton(
        icon: Icons.arrow_back_rounded,
        label: 'Back',
        onTap: widget.onBack,
        textColor: AppColors.textMuted,
        showBorder: true,
        borderColor: AppColors.borderLight,
        hoverColor: AppColors.surfaceHover,
      ),

      const SizedBox(width: 10),

      if (!_editing)
        AppButton(
          icon: Icons.edit_outlined,
          label: 'Edit',
          backgroundColor: AppColors.issuingAccent,
          hoverColor: AppColors.issuingAccent.withOpacity(0.82),
          onTap: _enterEdit,
        )
      else ...[
        AppButton(
          icon: Icons.save_outlined,
          label: 'Save',
          backgroundColor: AppColors.verifyingAccent,
          hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
          onTap: _requestSave,
        ),
        const SizedBox(width: 10),
        AppButton(
          icon: Icons.close_rounded,
          label: 'Cancel Edit',
          onTap: _cancelEdit,
          textColor: AppColors.revoked,
          showBorder: true,
          borderColor: AppColors.revoked,
          hoverColor: AppColors.revoked.withOpacity(0.08),
        ),
      ],
    ],
  );

  @override
  void dispose() {
    for (final f in _fields) f.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  FIELD ROW
// ═════════════════════════════════════════════════════════════════════════════

class _FieldRow extends StatefulWidget {
  final _EditableField field;
  final int index;
  final int total;
  final bool editing;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final void Function(SchemaFieldType) onTypeChanged;
  final void Function(bool) onRequiredChanged;

  const _FieldRow({
    required this.field,
    required this.index,
    required this.total,
    required this.editing,
    required this.selected,
    required this.onSelect,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onTypeChanged,
    required this.onRequiredChanged,
  });

  @override
  State<_FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<_FieldRow> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    return MouseRegion(
      cursor: widget.editing && widget.field.isNew
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.editing && widget.field.isNew ? widget.onSelect : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.issuingAccent.withOpacity(0.07)
                : _h && widget.editing
                ? AppColors.surfaceHover
                : Colors.transparent,
            border: f.isNew
                ? Border(
                    left: BorderSide(
                      color: AppColors.issuingAccent.withOpacity(0.65),
                      width: 3,
                    ),
                  )
                : null,
          ),
          padding: EdgeInsets.only(
            left: f.isNew ? 13 : 16,
            right: 16,
            top: 12,
            bottom: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Move up/down (edit mode)
                  if (widget.editing) ...[
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
                    const SizedBox(width: 6),
                  ],

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
                    child: widget.editing && f.isNew
                        ? _EditInput(ctrl: f.labelCtrl, hint: 'Field label…')
                        : Text(
                            f.labelCtrl.text.isNotEmpty
                                ? f.labelCtrl.text
                                : '—',
                            style: AppTextStyles.bodyTiny.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),

                  // Data type
                  Expanded(
                    flex: 2,
                    child: widget.editing && f.isNew
                        ? _TypeDropdown(
                            value: f.type,
                            onChanged: widget.onTypeChanged,
                          )
                        : _TypeChip(type: f.type),
                  ),
                  const SizedBox(width: 12),

                  // Required
                  Expanded(
                    flex: 2,
                    child: widget.editing
                        ? Opacity(
                            opacity: 0.45,
                            child: IgnorePointer(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Transform.scale(
                                    scale: 0.75,
                                    child: Switch(
                                      value: f.isRequired,
                                      onChanged: (_) {},
                                      activeColor: AppColors.issuingAccent,
                                      activeTrackColor: AppColors.issuingAccent
                                          .withOpacity(0.3),
                                      inactiveThumbColor: AppColors.textDim,
                                      inactiveTrackColor: AppColors.border,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
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
                            ),
                          )
                        : _RequiredBadge(required: f.isRequired),
                  ),

                  // Checkbox (edit mode, new fields only)
                  if (widget.editing && f.isNew)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Checkbox(
                        value: widget.selected,
                        onChanged: (_) => widget.onSelect(),
                        activeColor: AppColors.revoked,
                        checkColor: Colors.white,
                        side: const BorderSide(
                          color: AppColors.border,
                          width: 1.5,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),

              // Dropdown options input (edit mode, new dropdown fields only)
              if (widget.editing &&
                  f.isNew &&
                  f.type == SchemaFieldType.dropdown) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.only(left: widget.editing ? 52 : 34),
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
                        child: _EditInput(
                          ctrl: f.optionsCtrl,
                          hint: 'Option A, Option B, Option C…',
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Dropdown options pills (view mode)
              if (!widget.editing &&
                  f.type == SchemaFieldType.dropdown &&
                  f.parsedOptions.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 34),
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: f.parsedOptions
                        .map(
                          (opt) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHover,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              opt,
                              style: AppTextStyles.bodyTiny.copyWith(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        )
                        .toList(),
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
//  SAVE CONFIRMATION DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _SaveConfirmDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  const _SaveConfirmDialog({required this.onConfirm});

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
    child: Container(
      constraints: const BoxConstraints(maxWidth: 480),
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.verifyingAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.save_outlined,
                  size: 20,
                  color: AppColors.verifyingAccent,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Save Schema Changes',
                      style: AppTextStyles.navLabelActive.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Please review what these changes affect.',
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
          const SizedBox(height: 20),
          _EffectBox(
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.verifyingAccent,
            title: 'Existing credentials are unaffected',
            body:
                'Changes to this schema will NOT affect credentials that have already been issued. '
                'All previously issued credentials retain their original field structure.',
          ),
          const SizedBox(height: 10),
          _EffectBox(
            icon: Icons.upcoming_outlined,
            color: AppColors.issuingAccent,
            title: 'Applies to future issuance only',
            body:
                'The updated schema will only apply to new credentials issued after this change is saved.',
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                label: 'Cancel',
                onTap: () => Navigator.pop(context),
                showBorder: true,
                hoverColor: AppColors.surfaceHover,
                textColor: AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              AppButton(
                label: 'Confirm Save',
                backgroundColor: AppColors.verifyingAccent,
                hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
                onTap: () {
                  Navigator.pop(context);
                  onConfirm();
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _EffectBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _EffectBox({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  SMALL REUSABLE WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _FieldColHeader extends StatelessWidget {
  final bool editing;
  const _FieldColHeader({required this.editing});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF141414),
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    padding: EdgeInsets.only(
      left: editing ? 58 : 16,
      right: 16,
      top: 7,
      bottom: 7,
    ),
    child: Row(
      children: [
        const SizedBox(width: 34),
        const SizedBox(width: 12),
        _CH('FIELD LABEL', flex: 3),
        const SizedBox(width: 12),
        _CH('DATA TYPE', flex: 2),
        const SizedBox(width: 12),
        _CH('REQUIRED', flex: 2),
        if (editing) const SizedBox(width: 36),
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

class _EmptyFields extends StatelessWidget {
  final bool editing;
  const _EmptyFields({required this.editing});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.table_rows_outlined,
          size: 32,
          color: AppColors.textDim,
        ),
        const SizedBox(height: 10),
        Text(
          editing
              ? 'No fields yet. Tap "Add Field" to get started.'
              : 'No fields defined for this schema.',
          style: AppTextStyles.bodyTiny.copyWith(
            fontSize: 12,
            color: AppColors.textDim,
          ),
        ),
      ],
    ),
  );
}

class _CountChip extends StatelessWidget {
  final int count;
  const _CountChip({required this.count});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.issuingAccent.withOpacity(0.12),
      borderRadius: BorderRadius.circular(4),
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

class _IssuedBox extends StatelessWidget {
  final int count;
  const _IssuedBox({required this.count});
  @override
  Widget build(BuildContext context) {
    final color = count > 0 ? AppColors.issuingAccent : AppColors.textDim;
    return Container(
      width: 100,
      height: 107,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.issuingAccent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.issuingAccent.withOpacity(0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Credentials\nIssued',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 9,
              color: AppColors.textDim,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool mono;
  const _MetaChip({required this.icon, required this.label, this.mono = false});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: AppColors.textDim),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textDim,
          fontFamily: mono ? 'monospace' : null,
          fontWeight: mono ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    ],
  );
}

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});
  Color get _color {
    switch (category.toLowerCase()) {
      case 'academic':
        return const Color(0xFF8B5CF6);
      case 'medical':
        return const Color(0xFF06B6D4);
      case 'corporate':
        return const Color(0xFFF59E0B);
      default:
        return AppColors.textDim;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: _color.withOpacity(0.30)),
    ),
    child: Text(
      category,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: _color,
        letterSpacing: 0.2,
      ),
    ),
  );
}

class _TypeChip extends StatelessWidget {
  final SchemaFieldType type;
  final bool small;
  const _TypeChip({required this.type, this.small = false});
  Color get _color {
    switch (type) {
      case SchemaFieldType.text:
        return const Color(0xFF60A5FA);
      case SchemaFieldType.number:
        return const Color(0xFFA78BFA);
      case SchemaFieldType.date:
        return const Color(0xFF34D399);
      case SchemaFieldType.yesNo:
        return const Color(0xFFFBBF24);
      case SchemaFieldType.dropdown:
        return const Color(0xFFF97316);
    }
  }

  IconData get _icon {
    switch (type) {
      case SchemaFieldType.text:
        return Icons.text_fields_rounded;
      case SchemaFieldType.number:
        return Icons.tag_rounded;
      case SchemaFieldType.date:
        return Icons.calendar_today_outlined;
      case SchemaFieldType.yesNo:
        return Icons.toggle_on_outlined;
      case SchemaFieldType.dropdown:
        return Icons.arrow_drop_down_circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: small ? 6 : 8,
      vertical: small ? 2 : 4,
    ),
    decoration: BoxDecoration(
      color: _color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: _color.withOpacity(0.30)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icon, size: small ? 10 : 11, color: _color),
        const SizedBox(width: 4),
        Text(
          type.label,
          style: TextStyle(
            fontSize: small ? 9 : 10,
            fontWeight: FontWeight.w700,
            color: _color,
          ),
        ),
      ],
    ),
  );
}

class _RequiredBadge extends StatelessWidget {
  final bool required;
  const _RequiredBadge({required this.required});
  @override
  Widget build(BuildContext context) {
    final c = required ? AppColors.issuingAccent : AppColors.textDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withOpacity(0.30)),
      ),
      child: Text(
        required ? 'Required' : 'Optional',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}

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
      border: Border.all(color: AppColors.issuingAccent.withOpacity(0.4)),
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
    if (!widget.enabled && widget.tooltip != null)
      btn = Tooltip(message: widget.tooltip!, child: btn);
    return btn;
  }
}

class _EditInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool title;
  final int maxLines;
  const _EditInput({
    required this.ctrl,
    required this.hint,
    this.title = false,
    this.maxLines = 1,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.issuingAccent.withOpacity(0.04),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: AppColors.issuingAccent.withOpacity(0.45),
        width: 1.5,
      ),
    ),
    child: TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: title ? 16 : 12,
        fontWeight: title ? FontWeight.w800 : FontWeight.normal,
        color: AppColors.text,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: InputBorder.none,
        hintText: hint,
        hintStyle: AppTextStyles.bodyTiny.copyWith(
          fontSize: title ? 15 : 12,
          color: AppColors.textDim,
        ),
      ),
    ),
  );
}
