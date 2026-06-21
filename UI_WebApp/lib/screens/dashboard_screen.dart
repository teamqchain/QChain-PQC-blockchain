import 'package:flutter/material.dart';
import 'package:qportal_webapp/services/admin_api.dart';
import 'package:qportal_webapp/widgets/dashboard_varients.dart';
import 'package:qportal_webapp/components/varientToggler.dart';
import 'package:qportal_webapp/components/connection_error.dart';
import 'package:qportal_webapp/models/dashboard_Model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/skeletonLoading_widget.dart';
import 'package:qportal_webapp/widgets/statChips.dart';
import 'package:qportal_webapp/view/responsive_layout.dart'; // Added for the skeleton to match the layout exactly

class DashboardScreen extends StatefulWidget {
  final DashboardVariant variant;
  final ValueChanged<DashboardVariant> onVariantChanged;

  const DashboardScreen({
    super.key,
    required this.variant,
    required this.onVariantChanged,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final data = await AdminApi.getDashboardStats();
      if (mounted) {
        setState(() {
          _stats = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppColors.bg, child: _buildBody()),
        VariantToggler(
          current: widget.variant,
          onChanged: widget.onVariantChanged,
        ),
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
          if (_hasError)
            _buildErrorState()
          else if (_isLoading)
            _buildSkeletonLoading()
          else ...[
            StatChipsRow(variant: widget.variant, stats: _stats),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeIn,
              switchOutCurve: Curves.easeOut,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: KeyedSubtree(
                key: ValueKey(widget.variant),
                child: _buildVariantContent(),
              ),
            ),
          ],
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

  Widget _buildErrorState() {
    return ConnectionErrorWidget(
      onRetry: () {
        setState(() {
          _isLoading = true;
          _hasError = false;
        });
        _loadStats();
      },
    );
  }

  Widget _buildVariantContent() {
    switch (widget.variant) {
      case DashboardVariant.issuerOnly:
        return VariantIssuerContent(stats: _stats);
      case DashboardVariant.verifierOnly:
        return VariantVerifierContent(stats: _stats);
      case DashboardVariant.ITadmin:
        return VariantITAdminContent(stats: _stats);
    }
  }

  Widget _buildSkeletonLoading() {
    // Return a specific skeleton based on the variant structure
    if (widget.variant == DashboardVariant.ITadmin) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              4,
              (i) => const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SkeletonStatChip(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const ResponsiveColumns(
            left: SkeletonListCard(rows: 4),
            right: SkeletonListCard(rows: 4),
          ),
        ],
      );
    }

    // Issuer and Verifier layouts share this exact structural skeleton
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stat chips skeleton row (Uses Wrap to match the actual layout) ──
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(3, (i) => const SkeletonStatChip()),
        ),
        const SizedBox(height: 20),

        // ── Quick actions section ────────────────────────────────────────
        const SkeletonQuickActionsCard(),
        const SizedBox(height: 16),

        // ── Responsive two-column layout ─────────────────────────────────
        const ResponsiveColumns(
          left: SkeletonListCard(rows: 4),
          right: Column(
            children: [
              SkeletonListCard(rows: 2),
              SizedBox(height: 14),
              SkeletonChartCard(),
            ],
          ),
        ),
      ],
    );
  }
}

