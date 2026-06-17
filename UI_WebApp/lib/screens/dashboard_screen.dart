import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/dashboard_varients.dart';
import 'package:qportal_webapp/components/varientToggler.dart';
import 'package:qportal_webapp/components/connection_error.dart';
import 'package:qportal_webapp/models/dashboard_Model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/statChips.dart';
import 'package:qportal_webapp/services/api_service.dart';
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
      final data = await ApiService.getDashboardStats();
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
                  child: _SkeletonStatChip(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const ResponsiveColumns(
            left: _SkeletonListCard(rows: 4),
            right: _SkeletonListCard(rows: 4),
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
          children: List.generate(3, (i) => const _SkeletonStatChip()),
        ),
        const SizedBox(height: 20),

        // ── Quick actions section ────────────────────────────────────────
        const _SkeletonQuickActionsCard(),
        const SizedBox(height: 16),

        // ── Responsive two-column layout ─────────────────────────────────
        const ResponsiveColumns(
          left: _SkeletonListCard(rows: 4),
          right: Column(
            children: [
              _SkeletonListCard(rows: 2),
              SizedBox(height: 14),
              _SkeletonChartCard(),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SKELETON LOADING COMPONENTS
// ═════════════════════════════════════════════════════════════════════════════

class _SkeletonStatChip extends StatefulWidget {
  const _SkeletonStatChip();

  @override
  State<_SkeletonStatChip> createState() => _SkeletonStatChipState();
}

class _SkeletonStatChipState extends State<_SkeletonStatChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_controller),
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 90,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonListCard extends StatefulWidget {
  final int rows;
  const _SkeletonListCard({required this.rows});

  @override
  State<_SkeletonListCard> createState() => _SkeletonListCardState();
}

class _SkeletonListCardState extends State<_SkeletonListCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_controller),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header skeleton
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.border.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 160,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.border.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Content skeleton - list rows
            ...List.generate(
              widget.rows,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.border.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 120,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.border.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Container(
                      width: 48,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.border.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonChartCard extends StatefulWidget {
  const _SkeletonChartCard();

  @override
  State<_SkeletonChartCard> createState() => _SkeletonChartCardState();
}

class _SkeletonChartCardState extends State<_SkeletonChartCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heights = [30.0, 50.0, 20.0, 70.0];

    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_controller),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.border.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 200,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.border.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Bar chart skeleton
            SizedBox(
              height: 90,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                  4,
                  (i) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        height: heights[i],
                        decoration: BoxDecoration(
                          color: AppColors.border.withOpacity(0.3),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonQuickActionsCard extends StatefulWidget {
  const _SkeletonQuickActionsCard();

  @override
  State<_SkeletonQuickActionsCard> createState() =>
      _SkeletonQuickActionsCardState();
}

class _SkeletonQuickActionsCardState extends State<_SkeletonQuickActionsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_controller),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: 100,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),

            // Quick action buttons skeleton in a Wrap
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(
                3,
                (i) => Container(
                  width: 180,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.border.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
