import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';
import 'package:qwallet_mobileapp/widgets/QOnboardScaffold.dart';

/// Onboarding step 1 — "Own your credentials".
///
/// Pure-black canvas, stacked credential cards as the hero (white primary card
/// in front, dark tilted mini-cards behind), real Material icons, no emoji.
class Onboard1Screen extends StatelessWidget {
  const Onboard1Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return QOnboardScaffold(
      step: 1,
      onSkip: () => Get.offAllNamed(Routes.SHELL),
      ctaLabel: 'Continue',
      onCta: () => Get.toNamed(Routes.ONBOARD2),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 28),
          Center(child: _CredentialHero()),
          SizedBox(height: 44),
          _Headline('Own your\ncredentials'),
          SizedBox(height: 14),
          _Body(
            'Store your degree, passport, and certificates in one secure place. '
            'Only you control them — no company, no server, no middleman.',
          ),
          SizedBox(height: 32),
          _Bullet(
            icon: Icons.verified_user_outlined,
            text: 'You hold the keys. Always.',
          ),
          _Bullet(
            icon: Icons.cloud_off_outlined,
            text: 'Nothing leaves your device unless you share it.',
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Hero: stacked credential cards ────────────────────────────────────────

class _CredentialHero extends StatelessWidget {
  const _CredentialHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back card (rotated left) — dark panel
          Transform.translate(
            offset: const Offset(-46, 26),
            child: Transform.rotate(
              angle: -0.18,
              child: const _MiniCard(
                icon: Icons.menu_book_rounded,
                label: 'Degree',
                color: qOceanTeal,
              ),
            ),
          ),
          // Mid card (rotated right) — dark panel
          Transform.translate(
            offset: const Offset(44, 36),
            child: Transform.rotate(
              angle: 0.16,
              child: const _MiniCard(
                icon: Icons.flight_takeoff_rounded,
                label: 'Passport',
                color: qAzureBlue,
              ),
            ),
          ),
          // Front card (straight, elevated) — white, glowing
          Transform.translate(
            offset: const Offset(0, -10),
            child: _PrimaryCard(),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniCard({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 96,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: obPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: obBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 22, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 17),
          ),
          Text(
            label,
            style: const TextStyle(
              color: obText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 196,
      height: 130,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: obAccent,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x33FFFFFF), blurRadius: 36, spreadRadius: 2),
          BoxShadow(color: Color(0x1A000000), blurRadius: 28, offset: Offset(0, 14)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_rounded, color: obBg, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Digital ID',
                      style: TextStyle(
                        color: obBg,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Verified on-chain',
                      style: TextStyle(color: obTextDim, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.shield_rounded, color: obBg, size: 18),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'QWallet',
                style: TextStyle(
                  color: obBg,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(Icons.qr_code_2_rounded, color: obBg, size: 16),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Text atoms ────────────────────────────────────────────────────────────

class _Headline extends StatelessWidget {
  final String text;
  const _Headline(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: obText,
        fontSize: 32,
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
    return Text(text, style: const TextStyle(color: obTextSub, fontSize: 15, height: 1.55));
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Bullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: obPanelAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 15, color: obText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: obText,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
