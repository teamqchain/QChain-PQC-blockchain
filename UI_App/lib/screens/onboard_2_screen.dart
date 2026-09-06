import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';
import 'package:qwallet_mobileapp/widgets/QOnboardScaffold.dart';

/// Onboarding step 2 — "How it works".
///
/// Numbered step cards: Receive → Store → Present.
/// Restored first-pass layout, adapted to the black onboarding theme.
class Onboard2Screen extends StatelessWidget {
  const Onboard2Screen({super.key});

  static const _steps = [
    (
      Icons.download_rounded,
      'Receive',
      'Get credentials issued directly by universities, governments and banks.',
    ),
    (
      Icons.lock_outline_rounded,
      'Store securely',
      'Encrypted on your device — no company or server has access.',
    ),
    (
      Icons.qr_code_2_rounded,
      'Present anywhere',
      'Show a one-time QR code for instant blockchain verification.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return QOnboardScaffold(
      step: 2,
      onBack: () => Get.back(),
      onSkip: () => Get.offAllNamed(Routes.SHELL),
      ctaLabel: 'Continue',
      onCta: () => Get.toNamed(Routes.ONBOARD3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          const SizedBox(height: 10),
          const _Headline('Three steps to\na verified identity'),
          const SizedBox(height: 8),
          const SizedBox(height: 28),
          for (var i = 0; i < _steps.length; i++)
            _StepCard(index: i + 1, data: _steps[i]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Step card ─────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final int index;
  final (IconData, String, String) data;
  const _StepCard({required this.index, required this.data});

  @override
  Widget build(BuildContext context) {
    final icon = data.$1;
    final title = data.$2;
    final body = data.$3;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: obPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: obBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Numbered badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: obAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.black, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: obText,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: const TextStyle(
                      color: obTextSub,
                      fontSize: 13,
                      height: 1.45,
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
}

// ─── Text atoms ────────────────────────────────────────────────────────────

class _SectionTag extends StatelessWidget {
  final String text;
  const _SectionTag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: obPanelAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: obBorder),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: obTextSub,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  final String text;
  const _Headline(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: obText,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.8,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: obTextSub, fontSize: 15, height: 1.5));
  }
}
