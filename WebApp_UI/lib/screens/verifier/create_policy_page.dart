// screens/verifier/create_policy_page.dart
//
// Create New Policy — identical layout to ViewPolicyPage but always in edit
// mode with all fields empty.
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   case RouteName.createPolicy:
//     return CreatePolicyPage(
//       onCancel: () => _handleNavigate(RouteName.policies),
//       onCreate: () => _handleNavigate(RouteName.policies),
//     );
//
// ── Note on shared widgets ───────────────────────────────────────────────────
//   All inner building blocks (toggles, dropdowns, date pickers, multi-select)
//   live in policy_shared_widgets.dart. ViewPolicyPage should be updated to
//   import from there too, removing the duplicate private classes it defines.

import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/verifier/policy_shared_widget.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/app_button.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class CreatePolicyPage extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onCreate;

  const CreatePolicyPage({
    super.key,
    required this.onCancel,
    required this.onCreate,
  });

  @override
  State<CreatePolicyPage> createState() => _CreatePolicyPageState();
}

class _CreatePolicyPageState extends State<CreatePolicyPage> {
  // ── policy name ───────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _nameFocus = FocusNode();

  // ── rules — all start disabled / empty ───────────────────────────────────
  PolicyRulesState _rules = const PolicyRulesState();

  // ── applies to — starts with no selection ────────────────────────────────
  String? _appliesTo;
  List<String> _specificSchemas = [];

  // ── schema names from existing mock data ─────────────────────────────────
  final List<String> _schemaNames = IssuingMockData.schemas
      .map((s) => s.name)
      .toList();

  // ── validation ────────────────────────────────────────────────────────────

  bool get _canCreate => _nameCtrl.text.trim().isNotEmpty;

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
            'Create New Policy',
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
        _buildNameField(),
      ],
    );
  }

  Widget _buildNameField() {
    return AnimatedBuilder(
      animation: _nameFocus,
      builder: (_, __) {
        final focused = _nameFocus.hasFocus;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceHover,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: focused
                  ? AppColors.verifyingAccent.withOpacity(0.55)
                  : AppColors.border,
              width: focused ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: TextField(
            controller: _nameCtrl,
            focusNode: _nameFocus,
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Enter policy name',
              hintStyle: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                color: AppColors.textDim,
              ),
            ),
            onChanged: (_) => setState(() {}), // refresh _canCreate
          ),
        );
      },
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
              // Rule 1: not expired
              PolicyRuleRow(
                label: 'Credential must not be expired',
                sublabel: 'Rejects credentials with a status of Expired.',
                enabled: _rules.notExpiredEnabled,
                onToggle: (v) => setState(
                  () => _rules = _rules.copyWith(notExpiredEnabled: v),
                ),
              ),
              _divider(),

              // Rule 2: issued after
              PolicyRuleRow(
                label: 'Issued after',
                sublabel:
                    'Credential must have been issued on or after this date.',
                enabled: _rules.issuedAfterEnabled,
                onToggle: (v) => setState(
                  () => _rules = _rules.copyWith(issuedAfterEnabled: v),
                ),
                child: PolicyDatePickerField(
                  value: _rules.issuedAfterDate,
                  enabled: _rules.issuedAfterEnabled,
                  hintText: 'Select date',
                  onPicked: (d) => setState(
                    () => _rules = _rules.copyWith(issuedAfterDate: d),
                  ),
                ),
              ),
              _divider(),

              // Rule 3: issued before
              PolicyRuleRow(
                label: 'Issued before',
                sublabel:
                    'Credential must have been issued on or before this date.',
                enabled: _rules.issuedBeforeEnabled,
                onToggle: (v) => setState(
                  () => _rules = _rules.copyWith(issuedBeforeEnabled: v),
                ),
                child: PolicyDatePickerField(
                  value: _rules.issuedBeforeDate,
                  enabled: _rules.issuedBeforeEnabled,
                  hintText: 'Select date',
                  onPicked: (d) => setState(
                    () => _rules = _rules.copyWith(issuedBeforeDate: d),
                  ),
                ),
              ),
              _divider(),

              // Rule 4: issuer type
              PolicyRuleRow(
                label: 'Issuer type must be',
                sublabel:
                    'Credential must have been issued by this type of organisation.',
                enabled: _rules.issuerTypeEnabled,
                onToggle: (v) => setState(
                  () => _rules = _rules.copyWith(issuerTypeEnabled: v),
                ),
                child: PolicyDropdownField<String>(
                  value: _rules.issuerType,
                  enabled: _rules.issuerTypeEnabled,
                  hintText: 'Select issuer type',
                  items: kPolicyIssuerTypes,
                  itemLabel: (s) => s,
                  onChanged: (v) =>
                      setState(() => _rules = _rules.copyWith(issuerType: v)),
                ),
              ),
              _divider(),

              // Rule 5: credential type
              PolicyRuleRow(
                label: 'Credential type must be',
                sublabel:
                    'Credential must match one of the available schema types.',
                enabled: _rules.credTypeEnabled,
                onToggle: (v) => setState(
                  () => _rules = _rules.copyWith(credTypeEnabled: v),
                ),
                child: PolicyDropdownField<String>(
                  value: _rules.credType,
                  enabled: _rules.credTypeEnabled,
                  hintText: 'Select schema',
                  items: _schemaNames,
                  itemLabel: (s) => s,
                  onChanged: (v) =>
                      setState(() => _rules = _rules.copyWith(credType: v)),
                ),
              ),
            ],
          ),
        ),
      ],
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
              // Category dropdown
              _fieldLabel('Applies To'),
              const SizedBox(height: 8),
              PolicyDropdownField<String>(
                value: _appliesTo,
                enabled: true,
                hintText: 'Select category',
                items: kPolicyAppliesToOptions,
                itemLabel: (s) => s,
                onChanged: (v) => setState(() => _appliesTo = v),
              ),
              const SizedBox(height: 20),

              // Specific schemas multi-select
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
                enabled: true,
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
        // Cancel
        AppButton(
          icon: Icons.close_rounded,
          label: 'Cancel',
          showBorder: true,
          borderColor: AppColors.revoked,
          hoverColor: AppColors.surfaceHover,
          onTap: widget.onCancel,
          textColor: AppColors.revoked,
        ),
        const SizedBox(width: 10),

        // Save — saves as a draft (any state, no validation required)
        AppButton(
          icon: Icons.save_outlined,
          label: 'Save',
          showBorder: true,
          borderColor: AppColors.verifyingAccent,
          textColor: AppColors.verifyingLight,
          iconColor: AppColors.verifyingLight,
          hoverColor: AppColors.verifyingAccent.withOpacity(0.08),
          onTap: () {
            // In production: persist as Draft status.
            // Navigate back after saving.
            widget.onCancel();
          },
        ),
        const SizedBox(width: 10),

        // Create — requires policy name to be filled
        AppButton(
          icon: Icons.add_rounded,
          label: 'Create',
          backgroundColor: _canCreate
              ? AppColors.verifyingAccent
              : Colors.transparent,
          hoverColor: _canCreate
              ? AppColors.verifyingAccent.withOpacity(0.82)
              : Colors.transparent,
          showBorder: !_canCreate,
          borderColor: AppColors.border,
          disabledBorderColor: AppColors.border,
          textColor: _canCreate ? AppColors.white : AppColors.textDim,
          iconColor: _canCreate ? AppColors.white : AppColors.textDim,
          disabledBackgroundColor: AppColors.verifyingAccent.withOpacity(0.25),
          enabled: _canCreate,
          tooltip: _canCreate ? null : 'Enter a policy name before creating',
          onTap: widget.onCreate,
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }
}
