// widgets/verifier/policy_shared_widgets.dart
//
// Shared building blocks used by both ViewPolicyPage and CreatePolicyPage.
// Extract from view_policy_page.dart by making these public; update that file
// to import from here instead of redefining them locally.
//
// Exports:
//   • kPolicyIssuerTypes      — List<String>
//   • kPolicyAppliesToOptions — List<String>
//   • PolicyRulesState        — immutable-style rule holder with copyWith
//   • PolicyRuleRow           — one rule row (label + optional field + toggle)
//   • PolicyToggle            — animated sliding toggle
//   • PolicyDatePickerField   — tappable date display that opens showDatePicker
//   • PolicyDropdownField<T>  — single-select dark dropdown
//   • PolicyMultiSelectField  — chip-style field that opens PolicyMultiSelectDialog
//   • PolicyMultiSelectDialog — full dialog with checkboxes, Clear All, Apply

import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';

// ─── CONSTANTS ────────────────────────────────────────────────────────────────

const kPolicyIssuerTypes = <String>[
  'University',
  'Government',
  'Medical Board',
  'Professional Body',
  'Corporate',
  'Ministry',
  'International Body',
];

const kPolicyAppliesToOptions = <String>[
  'All',
  'Academic',
  'Medical',
  'Government',
  'University',
  'Professional',
  'Corporate',
];

// ─── RULE STATE ───────────────────────────────────────────────────────────────

class PolicyRulesState {
  final bool notExpiredEnabled;
  final bool issuedAfterEnabled;
  final DateTime? issuedAfterDate;
  final bool issuedBeforeEnabled;
  final DateTime? issuedBeforeDate;
  final bool issuerTypeEnabled;
  final String? issuerType;
  final bool credTypeEnabled;
  final String? credType;

  const PolicyRulesState({
    this.notExpiredEnabled = false,
    this.issuedAfterEnabled = false,
    this.issuedAfterDate,
    this.issuedBeforeEnabled = false,
    this.issuedBeforeDate,
    this.issuerTypeEnabled = false,
    this.issuerType,
    this.credTypeEnabled = false,
    this.credType,
  });

  PolicyRulesState copyWith({
    bool? notExpiredEnabled,
    bool? issuedAfterEnabled,
    DateTime? issuedAfterDate,
    bool clearIssuedAfterDate = false,
    bool? issuedBeforeEnabled,
    DateTime? issuedBeforeDate,
    bool clearIssuedBeforeDate = false,
    bool? issuerTypeEnabled,
    String? issuerType,
    bool clearIssuerType = false,
    bool? credTypeEnabled,
    String? credType,
    bool clearCredType = false,
  }) {
    return PolicyRulesState(
      notExpiredEnabled: notExpiredEnabled ?? this.notExpiredEnabled,
      issuedAfterEnabled: issuedAfterEnabled ?? this.issuedAfterEnabled,
      issuedAfterDate: clearIssuedAfterDate
          ? null
          : (issuedAfterDate ?? this.issuedAfterDate),
      issuedBeforeEnabled: issuedBeforeEnabled ?? this.issuedBeforeEnabled,
      issuedBeforeDate: clearIssuedBeforeDate
          ? null
          : (issuedBeforeDate ?? this.issuedBeforeDate),
      issuerTypeEnabled: issuerTypeEnabled ?? this.issuerTypeEnabled,
      issuerType: clearIssuerType ? null : (issuerType ?? this.issuerType),
      credTypeEnabled: credTypeEnabled ?? this.credTypeEnabled,
      credType: clearCredType ? null : (credType ?? this.credType),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  POLICY RULE ROW
// ═════════════════════════════════════════════════════════════════════════════

class PolicyRuleRow extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool enabled;
  final void Function(bool) onToggle;
  final Widget? child;

  const PolicyRuleRow({
    super.key,
    required this.label,
    required this.sublabel,
    required this.enabled,
    required this.onToggle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sublabel,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textDim,
                    height: 1.4,
                  ),
                ),
                if (child != null) ...[const SizedBox(height: 10), child!],
              ],
            ),
          ),
          const SizedBox(width: 24),
          PolicyToggle(value: enabled, onToggle: onToggle),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  POLICY TOGGLE
// ═════════════════════════════════════════════════════════════════════════════

class PolicyToggle extends StatelessWidget {
  final bool value;
  final void Function(bool) onToggle;

  const PolicyToggle({super.key, required this.value, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final Color track = value
        ? AppColors.verifyingAccent.withOpacity(0.35)
        : AppColors.border;
    final Color thumb = value ? AppColors.verifyingAccent : AppColors.textDim;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onToggle(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42,
          height: 24,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: track,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value
                  ? AppColors.verifyingAccent.withOpacity(0.6)
                  : AppColors.border,
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: thumb, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  POLICY DATE PICKER FIELD
// ═════════════════════════════════════════════════════════════════════════════

class PolicyDatePickerField extends StatefulWidget {
  final DateTime? value;
  final bool enabled;
  final String hintText;
  final void Function(DateTime) onPicked;

  const PolicyDatePickerField({
    super.key,
    required this.value,
    required this.enabled,
    required this.hintText,
    required this.onPicked,
  });

  @override
  State<PolicyDatePickerField> createState() => _PolicyDatePickerFieldState();
}

class _PolicyDatePickerFieldState extends State<PolicyDatePickerField> {
  bool _hovered = false;

  String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} '
      '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} '
      '${d.year}';

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.value ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2099),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.verifyingAccent,
            onPrimary: Colors.white,
            surface: Color(0xFF1A1A1A),
            onSurface: AppColors.text,
          ), dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF141414)),
        ),
        child: child!,
      ),
    );
    if (picked != null) widget.onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value != null;
    final isEnabled = widget.enabled;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: isEnabled ? _pick : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isEnabled && _hovered
                ? AppColors.surfaceHover
                : const Color(0xFF141414),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: isEnabled
                  ? (_hovered
                        ? AppColors.verifyingAccent.withOpacity(0.55)
                        : AppColors.borderLight)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: isEnabled
                    ? AppColors.verifyingAccent
                    : AppColors.textDim,
              ),
              const SizedBox(width: 8),
              Text(
                hasValue ? _format(widget.value!) : widget.hintText,
                style: TextStyle(
                  fontSize: 12,
                  color: hasValue ? AppColors.text : AppColors.textDim,
                  fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
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
//  POLICY DROPDOWN FIELD  (single-select)
// ═════════════════════════════════════════════════════════════════════════════

class PolicyDropdownField<T> extends StatelessWidget {
  final T? value;
  final bool enabled;
  final String hintText;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;

  const PolicyDropdownField({
    super.key,
    required this.value,
    required this.enabled,
    required this.hintText,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: enabled ? AppColors.surfaceHover : const Color(0xFF141414),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: enabled
              ? AppColors.verifyingAccent.withOpacity(0.4)
              : AppColors.border,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          iconSize: 18,
          dropdownColor: const Color(0xFF1C1C1C),
          style: const TextStyle(fontSize: 12, color: AppColors.text),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: enabled ? AppColors.verifyingAccent : AppColors.textDim,
          ),
          hint: Text(
            hintText,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textDim,
              fontStyle: FontStyle.italic,
            ),
          ),
          onChanged: enabled ? onChanged : null,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemLabel(item),
                    style: const TextStyle(fontSize: 12, color: AppColors.text),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  POLICY MULTI-SELECT FIELD  (opens PolicyMultiSelectDialog)
// ═════════════════════════════════════════════════════════════════════════════

class PolicyMultiSelectField extends StatefulWidget {
  final List<String> selected;
  final List<String> options;
  final bool enabled;
  final String hintText;
  final void Function(List<String>) onChanged;

  const PolicyMultiSelectField({
    super.key,
    required this.selected,
    required this.options,
    required this.enabled,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<PolicyMultiSelectField> createState() => _PolicyMultiSelectFieldState();
}

class _PolicyMultiSelectFieldState extends State<PolicyMultiSelectField> {
  bool _hovered = false;

  void _openPanel() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => PolicyMultiSelectDialog(
        options: widget.options,
        selected: List.from(widget.selected),
      ),
    );
    if (result != null) widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = widget.selected.isNotEmpty;

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? _openPanel : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: widget.enabled && _hovered
                ? AppColors.surfaceHover
                : const Color(0xFF141414),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: widget.enabled
                  ? (_hovered
                        ? AppColors.verifyingAccent.withOpacity(0.55)
                        : AppColors.borderLight)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasSelection ? widget.selected.join(', ') : widget.hintText,
                  style: TextStyle(
                    fontSize: 12,
                    color: hasSelection ? AppColors.text : AppColors.textDim,
                    fontStyle: hasSelection
                        ? FontStyle.normal
                        : FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasSelection) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.verifyingAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.verifyingAccent.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    '${widget.selected.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.verifyingLight,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: widget.enabled
                    ? AppColors.verifyingAccent
                    : AppColors.textDim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  POLICY MULTI-SELECT DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class PolicyMultiSelectDialog extends StatefulWidget {
  final List<String> options;
  final List<String> selected;

  const PolicyMultiSelectDialog({
    super.key,
    required this.options,
    required this.selected,
  });

  @override
  State<PolicyMultiSelectDialog> createState() =>
      _PolicyMultiSelectDialogState();
}

class _PolicyMultiSelectDialogState extends State<PolicyMultiSelectDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
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
            // Header
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
                      Icons.checklist_rounded,
                      size: 17,
                      color: AppColors.verifyingAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Specific Schemas Only',
                      style: AppTextStyles.navLabelActive.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.verifyingAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_selected.length} selected',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.verifyingLight,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Option list
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                children: widget.options.map((opt) {
                  final checked = _selected.contains(opt);
                  return _PolicyMultiSelectOption(
                    label: opt,
                    checked: checked,
                    onTap: () => setState(() {
                      checked ? _selected.remove(opt) : _selected.add(opt);
                    }),
                  );
                }).toList(),
              ),
            ),

            // Footer buttons
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  AppButton(
                    label: 'Clear All',
                    showBorder: true,
                    borderColor: AppColors.border,
                    hoverColor: AppColors.surfaceHover,
                    textColor: AppColors.textDim,
                    onTap: () => setState(() => _selected.clear()),
                  ),
                  const Spacer(),
                  AppButton(
                    label: 'Cancel',
                    showBorder: true,
                    borderColor: AppColors.border,
                    hoverColor: AppColors.surfaceHover,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    icon: Icons.check_rounded,
                    label: 'Apply',
                    backgroundColor: AppColors.verifyingAccent,
                    hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
                    onTap: () => Navigator.pop(context, _selected.toList()),
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

// ─── MULTI-SELECT OPTION ROW ──────────────────────────────────────────────────

class _PolicyMultiSelectOption extends StatefulWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;

  const _PolicyMultiSelectOption({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  @override
  State<_PolicyMultiSelectOption> createState() =>
      _PolicyMultiSelectOptionState();
}

class _PolicyMultiSelectOptionState extends State<_PolicyMultiSelectOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: _hovered
              ? AppColors.verifyingAccent.withOpacity(0.06)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: widget.checked
                      ? AppColors.verifyingAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: widget.checked
                        ? AppColors.verifyingAccent
                        : AppColors.textMuted,
                    width: 1.5,
                  ),
                ),
                child: widget.checked
                    ? const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: widget.checked
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: widget.checked ? AppColors.text : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
