// screens/verifier/view_policy_page.dart
//
// Policy Details — displays all policy information and allows editing rules.
//
// Layout contract:
//   Padding → Column
//     Title (fixed)
//     Expanded SingleChildScrollView → main container
//       Policy Name field
//       Rules section → inner container with 5 rules
//       Applies To section → inner container with 2 dropdowns
//     Action bar (fixed) — Back/Cancel + Edit/Save
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   case RouteName.policyDetail:
//     final policy = kMockPolicies.firstWhere(
//       (p) => p.id == (_selectedPolicyId ?? ''),
//       orElse: () => kMockPolicies.first,
//     );
//     return ViewPolicyPage(
//       policy: policy,
//       onBack: () => _handleNavigate(RouteName.policies),
//     );

import 'package:flutter/material.dart';
import 'package:qportal_webapp/widgets/policy_shared_widget.dart';
import 'package:qportal_webapp/models/ISSUER/schema_model.dart';
import 'package:qportal_webapp/models/VERIFIER/policy_model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class ViewPolicyPage extends StatefulWidget {
  final PolicyRecord policy;
  final VoidCallback onBack;

  const ViewPolicyPage({super.key, required this.policy, required this.onBack});

  @override
  State<ViewPolicyPage> createState() => _ViewPolicyPageState();
}

class _ViewPolicyPageState extends State<ViewPolicyPage> {
  // ── edit mode ────────────────────────────────────────────────────────────
  bool _editMode = false;

  // ── policy name field ────────────────────────────────────────────────────
  late TextEditingController _nameCtrl;
  late String _savedName;

  // ── rules state ──────────────────────────────────────────────────────────
  late PolicyRulesState _rules;
  late PolicyRulesState _savedRules; // snapshot for Cancel

  // ── applies to ───────────────────────────────────────────────────────────
  late String _appliesTo;
  late List<String> _specificSchemas;
  late String _savedAppliesTo;
  late List<String> _savedSpecificSchemas;

  // ── schema names from existing mock data ─────────────────────────────────
  final List<String> _schemaNames = SchemaMockData.schemas
      .map((s) => s.name)
      .toList();

  @override
  void initState() {
    super.initState();
    _savedName = widget.policy.policyName;
    _nameCtrl = TextEditingController(text: _savedName);
    _rules = const PolicyRulesState(notExpiredEnabled: true);
    _savedRules = const PolicyRulesState(notExpiredEnabled: true);
    _appliesTo = widget.policy.appliesTo == 'All Credentials'
        ? 'All'
        : widget.policy.appliesTo.split(' ').first;
    _savedAppliesTo = _appliesTo;
    _specificSchemas = [];
    _savedSpecificSchemas = [];
  }

  // ── edit / save / cancel ─────────────────────────────────────────────────

  void _onEdit() {
    _savedName = _nameCtrl.text;
    _savedRules = _rules.copyWith();
    _savedAppliesTo = _appliesTo;
    _savedSpecificSchemas = List.from(_specificSchemas);
    setState(() => _editMode = true);
  }

  void _onSave() {
    setState(() => _editMode = false);
    // In production: persist changes.
  }

  void _onCancel() {
    setState(() {
      _editMode = false;
      _nameCtrl.text = _savedName;
      _rules = _savedRules.copyWith();
      _appliesTo = _savedAppliesTo;
      _specificSchemas = List.from(_savedSpecificSchemas);
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ────────────────────────────────────────────────────────
          Text(
            'Policy Details',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // ── Main container ───────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.hardEdge,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPolicyNameSection(),
                    const SizedBox(height: 24),
                    _buildRulesSection(),
                    const SizedBox(height: 24),
                    _buildAppliesToSection(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Action bar ───────────────────────────────────────────────────
          _buildActionBar(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  POLICY NAME
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPolicyNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Policy Name'),
        const SizedBox(height: 8),
        _inputField(
          controller: _nameCtrl,
          readOnly: !_editMode,
          hintText: 'Enter policy name',
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  RULES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRulesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Rules'),
        const SizedBox(height: 8),
        Text(
          'All enabled rules must pass for the policy to pass.',
          style: AppTextStyles.bodyTiny.copyWith(
            fontSize: 11,
            color: AppColors.textDim,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E0E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildRule1(),
              _divider(),
              _buildRule2(),
              _divider(),
              _buildRule3(),
              _divider(),
              _buildRule4(),
              _divider(),
              _buildRule5(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Rule 1: Credential must not be expired ────────────────────────────────

  Widget _buildRule1() {
    return _ruleRow(
      PolicyRuleRow(
        label: 'Credential must not be expired',
        sublabel: 'Rejects credentials with a status of Expired.',
        enabled: _rules.notExpiredEnabled,
        onToggle: (v) =>
            setState(() => _rules = _rules.copyWith(notExpiredEnabled: v)),
      ),
    );
  }

  // ── Rule 2: Issued after ──────────────────────────────────────────────────

  Widget _buildRule2() {
    return _ruleRow(
      PolicyRuleRow(
        label: 'Issued after',
        sublabel: 'Credential must have been issued on or after this date.',
        enabled: _rules.issuedAfterEnabled,
        onToggle: (v) =>
            setState(() => _rules = _rules.copyWith(issuedAfterEnabled: v)),
        child: PolicyDatePickerField(
          value: _rules.issuedAfterDate,
          enabled: _editMode && _rules.issuedAfterEnabled,
          hintText: 'Select date',
          onPicked: (d) =>
              setState(() => _rules = _rules.copyWith(issuedAfterDate: d)),
        ),
      ),
    );
  }

  // ── Rule 3: Issued before ─────────────────────────────────────────────────

  Widget _buildRule3() {
    return _ruleRow(
      PolicyRuleRow(
        label: 'Issued before',
        sublabel: 'Credential must have been issued on or before this date.',
        enabled: _rules.issuedBeforeEnabled,
        onToggle: (v) =>
            setState(() => _rules = _rules.copyWith(issuedBeforeEnabled: v)),
        child: PolicyDatePickerField(
          value: _rules.issuedBeforeDate,
          enabled: _editMode && _rules.issuedBeforeEnabled,
          hintText: 'Select date',
          onPicked: (d) =>
              setState(() => _rules = _rules.copyWith(issuedBeforeDate: d)),
        ),
      ),
    );
  }

  // ── Rule 4: Issuer type ───────────────────────────────────────────────────

  Widget _buildRule4() {
    return _ruleRow(
      PolicyRuleRow(
        label: 'Issuer type must be',
        sublabel:
            'Credential must have been issued by this type of organisation.',
        enabled: _rules.issuerTypeEnabled,
        onToggle: (v) =>
            setState(() => _rules = _rules.copyWith(issuerTypeEnabled: v)),
        child: PolicyDropdownField<String>(
          value: _rules.issuerType,
          enabled: _editMode && _rules.issuerTypeEnabled,
          hintText: 'Select issuer type',
          items: kPolicyIssuerTypes,
          itemLabel: (s) => s,
          onChanged: (v) =>
              setState(() => _rules = _rules.copyWith(issuerType: v)),
        ),
      ),
    );
  }

  // ── Rule 5: Credential type ───────────────────────────────────────────────

  Widget _buildRule5() {
    return _ruleRow(
      PolicyRuleRow(
        label: 'Credential type must be',
        sublabel: 'Credential must match one of the available schema types.',
        enabled: _rules.credTypeEnabled,
        onToggle: (v) =>
            setState(() => _rules = _rules.copyWith(credTypeEnabled: v)),
        child: PolicyDropdownField<String>(
          value: _rules.credType,
          enabled: _editMode && _rules.credTypeEnabled,
          hintText: 'Select schema',
          items: _schemaNames,
          itemLabel: (s) => s,
          onChanged: (v) =>
              setState(() => _rules = _rules.copyWith(credType: v)),
        ),
      ),
    );
  }

  // Wraps a rule row with disabled interaction + dimmed opacity in view mode.
  Widget _ruleRow(Widget row) {
    if (_editMode) return row;
    return IgnorePointer(
      child: Opacity(opacity: 0.55, child: row),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  APPLIES TO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAppliesToSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Applies To'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E0E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Applies To dropdown
              _fieldLabel('Applies To'),
              const SizedBox(height: 8),
              PolicyDropdownField<String>(
                value: _appliesTo,
                enabled: _editMode,
                hintText: 'Select category',
                items: kPolicyAppliesToOptions,
                itemLabel: (s) => s,
                onChanged: (v) {
                  if (v != null) setState(() => _appliesTo = v);
                },
              ),
              const SizedBox(height: 20),

              // Specific Schemas multi-select
              _fieldLabel('Specific Schemas Only'),
              const SizedBox(height: 4),
              Text(
                'Leave empty to apply to all schemas in the selected category.',
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 11,
                  color: AppColors.textDim,
                ),
              ),
              const SizedBox(height: 8),
              PolicyMultiSelectField(
                selected: _specificSchemas,
                options: _schemaNames,
                enabled: _editMode,
                hintText: 'Select specific schemas…',
                onChanged: (v) => setState(() => _specificSchemas = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ACTION BAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Back / Cancel
        AppButton(
          icon: _editMode ? Icons.close_rounded : Icons.arrow_back_rounded,
          label: _editMode ? 'Cancel' : 'Back',
          showBorder: true,
          borderColor: _editMode ? AppColors.revoked : AppColors.border,
          hoverColor: AppColors.surfaceHover,
          onTap: _editMode ? _onCancel : widget.onBack,
          textColor: _editMode ? AppColors.revoked : AppColors.white,
        ),
        const SizedBox(width: 10),

        // Edit / Save
        AppButton(
          icon: _editMode ? Icons.check_rounded : Icons.edit_outlined,
          label: _editMode ? 'Save' : 'Edit',
          backgroundColor: _editMode
              ? AppColors.verifyingAccent
              : Colors.transparent,
          hoverColor: _editMode
              ? AppColors.verifyingAccent.withOpacity(0.82)
              : AppColors.surfaceHover,
          showBorder: !_editMode,
          borderColor: _editMode
              ? Colors.transparent
              : AppColors.verifyingAccent.withOpacity(0.5),
          textColor: _editMode ? AppColors.white : AppColors.verifyingLight,
          iconColor: _editMode ? AppColors.white : AppColors.verifyingLight,
          onTap: _editMode ? _onSave : _onEdit,
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SMALL HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _sectionLabel(String text) => Text(
    text,
    style: AppTextStyles.navLabelActive.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.text,
    ),
  );

  Widget _fieldLabel(String text) => Text(
    text.toUpperCase(),
    style: AppTextStyles.bodyTiny.copyWith(
      fontSize: 9,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
      color: AppColors.textDim,
    ),
  );

  Widget _divider() => Container(height: 1, color: AppColors.border);

  Widget _inputField({
    required TextEditingController controller,
    required bool readOnly,
    String hintText = '',
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: readOnly ? const Color(0xFF0E0E0E) : AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: readOnly
              ? AppColors.border
              : AppColors.verifyingAccent.withOpacity(0.55),
          width: readOnly ? 1 : 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        style: AppTextStyles.bodyTiny.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: readOnly ? AppColors.textMuted : AppColors.text,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: AppTextStyles.bodyTiny.copyWith(
            fontSize: 12,
            color: AppColors.textDim,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }
}

