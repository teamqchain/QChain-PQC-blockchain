import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/dashboard_varients.dart';
import 'package:qportal_webapp/components/varientToggler.dart';
import 'package:qportal_webapp/models/dashboard_Model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/statChips.dart';

// DashboardScreen no longer owns the Scaffold — AppShell does.
// It receives variant + onVariantChanged from AppShell so the sidebar
// colour can react when the variant switches.

class DashboardScreen extends StatelessWidget {
  final DashboardVariant variant;
  final ValueChanged<DashboardVariant> onVariantChanged;

  const DashboardScreen({
    super.key,
    required this.variant,
    required this.onVariantChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: AppColors.bg, child: _buildBody()),

        // Demo toggler — remove before production
        VariantToggler(current: variant, onChanged: onVariantChanged),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageTitle(),
          const SizedBox(height: 20),
          StatChipsRow(variant: variant),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(
              key: ValueKey(variant),
              child: _buildVariantContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dashboard', style: AppTextStyles.pageTitle),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildVariantContent() {
    switch (variant) {
      case DashboardVariant.issuerOnly:
        return const VariantIssuerContent();
      case DashboardVariant.verifierOnly:
        return const VariantVerifierContent();
      case DashboardVariant.ITadmin:
        return const VariantITAdminContent();
    }
  }
}
