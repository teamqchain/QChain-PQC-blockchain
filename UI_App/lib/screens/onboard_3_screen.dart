import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';

class Onboard3Screen extends StatefulWidget {
  const Onboard3Screen({super.key});

  @override
  State<Onboard3Screen> createState() => _Onboard3ScreenState();
}

class _Onboard3ScreenState extends State<Onboard3Screen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _ctrl.stop();
        setState(() => _done = true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),

              const Spacer(),

              // Spinner / Done — centred
              Center(
                child: SizedBox(
                  width: 130,
                  height: 130,
                  child: _done ? _DoneCircle() : _SpinnerCircle(ctrl: _ctrl),
                ),
              ),

              const SizedBox(height: 44),

              // ── Fixed-height text block to prevent layout jump ──
              SizedBox(
                height: 150,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  // crossFadeState keeps alignment stable
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topLeft,
                    children: [...previous, if (current != null) current],
                  ),
                  child: _done
                      ? _TextBlock(
                          key: const ValueKey('done'),
                          heading: 'Your wallet\nis ready',
                          body:
                              'Your quantum-resistant keypair is ready.\nAll credentials are encrypted on-device.',
                        )
                      : _TextBlock(
                          key: const ValueKey('loading'),
                          heading: 'Creating your\nsecure identity',
                          body:
                              'Generating your quantum-resistant keypair.\nThis stays on your device — no one else has it.',
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // NIST badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF222222)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF555555),
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CRYSTALS-Dilithium (ML-DSA) · NIST FIPS 204',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Dots centered ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _Dot(active: false),
                  SizedBox(width: 6),
                  _Dot(active: false),
                  SizedBox(width: 6),
                  _Dot(active: true),
                ],
              ),

              const SizedBox(height: 24),

              // ── Button greyed out until done ──
              GestureDetector(
                onTap: _done ? () => Get.offAllNamed(Routes.SHELL) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  decoration: BoxDecoration(
                    color: _done ? Colors.white : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      color: _done
                          ? const Color(0xFF000000)
                          : const Color(0xFF555555),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    child: const Text('Open My Wallet'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── TEXT BLOCK (fixed alignment) ────────────────────────────────────────────

class _TextBlock extends StatelessWidget {
  final String heading;
  final String body;

  const _TextBlock({super.key, required this.heading, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          heading,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

// ─── SPINNER ─────────────────────────────────────────────────────────────────

class _SpinnerCircle extends StatelessWidget {
  final AnimationController ctrl;
  const _SpinnerCircle({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, child) =>
          Transform.rotate(angle: ctrl.value * 2 * pi, child: child),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF111111),
          border: Border.all(color: const Color(0xFF222222), width: 1.5),
        ),
        child: CustomPaint(
          painter: _ArcPainter(),
          child: const Center(
            child: Text('🔑', style: TextStyle(fontSize: 44)),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawArc(
      Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
      -pi / 2,
      pi * 1.5,
      false,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── DONE CIRCLE ─────────────────────────────────────────────────────────────

class _DoneCircle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF111111),
        border: Border.all(
          color: const Color(0xFF22C55E).withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        '✓',
        style: TextStyle(
          fontSize: 52,
          color: Color(0xFF22C55E),
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}

// ─── SHARED ──────────────────────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: active ? 20 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? Colors.white : const Color(0xFF333333),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
