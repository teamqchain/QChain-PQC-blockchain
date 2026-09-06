import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Onboarding design tokens (dark variant).
///
/// The onboarding flow runs on a pure-black canvas — distinct from the app's
/// light main theme. These keep every onboarding screen visually consistent
/// without polluting the global [colors.dart] palette.
const Color obBg = Color(0xFF000000);
const Color obPanel = Color(0xFF0F0F0F);
const Color obPanelAlt = Color(0xFF161616);
const Color obBorder = Color(0xFF232323);
const Color obBorderStrong = Color(0xFF333333);
const Color obText = Color(0xFFFFFFFF);
const Color obTextSub = Color(0xFF8A8A8A);
const Color obTextDim = Color(0xFF555555);
const Color obAccent = Color(0xFFFFFFFF);
const Color obGood = Color(0xFF22C55E);

/// Shared scaffolding for every onboarding step.
///
///   ┌──────────────────────────────────────────┐
///   │  ◄ (back)            step 1/3      Skip › │  ← top bar
///   │                                          │
///   │             [ scrollable hero ]          │
///   │                                          │
///   │           ● — —                          │  ← dots
///   │      [   Continue   ]                    │  ← CTA
///   └──────────────────────────────────────────┘
///
/// Pure-black background, white CTA, dark panels. Uses SafeArea + a maxWidth
/// gutter so it reads correctly on phones, large Android devices, and iPhone
/// Pro Max alike. Works on both Android and iOS (Material tap targets).
class QOnboardScaffold extends StatelessWidget {
  final int step; // 1-based step index (1..3)
  final VoidCallback? onBack; // null → no back button (first screen)
  final VoidCallback onSkip; // skip to shell
  final VoidCallback onCta; // primary action
  final String ctaLabel;
  final bool ctaEnabled;
  final Widget child; // hero content

  const QOnboardScaffold({
    required this.step,
    required this.onSkip,
    required this.onCta,
    required this.ctaLabel,
    required this.child,
    this.onBack,
    this.ctaEnabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Light status-bar icons (white) on the black background.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top + 8;
    final bottomPad = mq.padding.bottom + 16;

    return Scaffold(
      backgroundColor: obBg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Top bar ─────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20, topPad, 20, 0),
              child: _OnboardTopBar(step: step, onBack: onBack, onSkip: onSkip),
            ),

            // ── Hero content (scrollable, fills remaining space) ────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: child,
                  ),
                ),
              ),
            ),

            // ── Dots + CTA pinned to the bottom ─────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    _OnboardDots(active: step),
                    const SizedBox(height: 20),
                    _OnboardCta(
                      label: ctaLabel,
                      onTap: ctaEnabled ? onCta : null,
                      enabled: ctaEnabled,
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

// ─── Top bar ───────────────────────────────────────────────────────────────

class _OnboardTopBar extends StatelessWidget {
  final int step;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  const _OnboardTopBar({
    required this.step,
    required this.onBack,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        onBack != null
            ? _CircleButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack!)
            : const SizedBox(width: 40, height: 40),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: obTextSub,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Skip',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ─── Dots (dark variant, local to onboarding) ──────────────────────────────

class _OnboardDots extends StatelessWidget {
  final int active;
  const _OnboardDots({required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i + 1 == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? obAccent : obBorderStrong,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─── Circular icon button (back / close) ───────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: obPanelAlt,
            border: Border.all(color: obBorder),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: obText),
        ),
      ),
    );
  }
}

// ─── Primary CTA ───────────────────────────────────────────────────────────

class _OnboardCta extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  const _OnboardCta({required this.label, required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: enabled ? obAccent : obBorderStrong,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 54,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: enabled ? obBg : obTextDim,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
