import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';
import 'package:qwallet_mobileapp/widgets/QOnboardScaffold.dart';

/// Onboarding step 3 — key generation / wallet ready.
///
/// Hero is a hexagonal crystal lattice that assembles node-by-node (a metaphor
/// for CRYSTALS-Dilithium). Outer ring only — centre is reserved for a solid
/// badge (progress → green check) so the tick never collides with lattice dots.
/// Pure-black canvas, no emoji, no rotating key.
class Onboard3Screen extends StatefulWidget {
  const Onboard3Screen({super.key});

  @override
  State<Onboard3Screen> createState() => _Onboard3ScreenState();
}

class _Onboard3ScreenState extends State<Onboard3Screen>
    with TickerProviderStateMixin {
  late AnimationController _latticeCtrl; // drives the assembly animation
  late AnimationController _doneCtrl; // drives the green-lightup + check
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _latticeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _doneCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _latticeCtrl.stop();
        _doneCtrl.forward();
        setState(() => _done = true);
      }
    });
  }

  @override
  void dispose() {
    _latticeCtrl.dispose();
    _doneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QOnboardScaffold(
      step: 3,
      onBack: () => Get.back(),
      onSkip: () => Get.offAllNamed(Routes.SHELL),
      ctaLabel: _done ? 'Open my wallet' : 'Generating…',
      ctaEnabled: _done,
      onCta: () => Get.offAllNamed(Routes.SHELL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: _Lattice(
                latticeCtrl: _latticeCtrl,
                doneCtrl: _doneCtrl,
                done: _done,
              ),
            ),
          ),
          const SizedBox(height: 36),
          // Fixed-height text block to prevent layout jump during the switch.
          SizedBox(
            height: 150,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topLeft,
                children: [...previous, if (current != null) current],
              ),
              child: _done
                  ? const _TextBlock(
                      key: ValueKey('done'),
                      heading: 'Your wallet\nis ready',
                      body: 'Your quantum-resistant keypair is ready.\n'
                          'All credentials are encrypted on-device.',
                    )
                  : const _TextBlock(
                      key: ValueKey('loading'),
                      heading: 'Creating your\nsecure identity',
                      body: 'Generating your quantum-resistant keypair.\n'
                          'This stays on your device — no one else has it.',
                    ),
            ),
          ),
          const SizedBox(height: 20),
          const _NistBadge(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Crystal lattice ───────────────────────────────────────────────────────
//
// A hexagonal lattice of 7 nodes (centre + 6 around it) connected by edges.
// During generation each node pops in sequence with a white glow; on completion
// the whole structure flashes green and a check icon appears at the centre.

class _Lattice extends StatelessWidget {
  final AnimationController latticeCtrl;
  final AnimationController doneCtrl;
  final bool done;
  const _Lattice({
    required this.latticeCtrl,
    required this.doneCtrl,
    required this.done,
  });

  // 6 outer nodes on a hex ring (no centre node — that slot is reserved for
  // the solid check badge so they never collide).
  static const _nodes = <Offset>[
    Offset(0.50, 0.10), // top
    Offset(0.85, 0.30), // top-right
    Offset(0.85, 0.70), // bottom-right
    Offset(0.50, 0.90), // bottom
    Offset(0.15, 0.70), // bottom-left
    Offset(0.15, 0.30), // top-left
  ];

  // Ring edges only (no spokes into centre — leaves the middle clean).
  static const _edges = <(int, int)>[
    (0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 0),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([latticeCtrl, doneCtrl]),
      builder: (_, __) {
        final reveal = done ? 1.0 : latticeCtrl.value;
        final doneProgress = doneCtrl.value;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Lattice (outer ring only — centre is empty by design).
            CustomPaint(
              size: const Size(200, 200),
              painter: _LatticePainter(
                nodes: _nodes,
                edges: _edges,
                reveal: reveal,
                doneProgress: doneProgress,
              ),
            ),
            // Solid centre badge — dims during assembly, lights green on done.
            // Opaque fill means the check is never covered by lattice nodes.
            _CentreBadge(doneProgress: doneProgress),
          ],
        );
      },
    );
  }
}

class _CentreBadge extends StatelessWidget {
  final double doneProgress;
  const _CentreBadge({required this.doneProgress});

  @override
  Widget build(BuildContext context) {
    final isDone = doneProgress > 0.01;
    final borderColor = Color.lerp(
      obBorderStrong,
      obGood,
      doneProgress,
    )!;
    final fillColor = Color.lerp(
      obPanel,
      const Color(0xFF0A1A10),
      doneProgress,
    )!;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: isDone
            ? [
                BoxShadow(
                  color: obGood.withValues(alpha: 0.35 * doneProgress),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: isDone
            ? Icon(
                Icons.check_rounded,
                key: const ValueKey('check'),
                size: 30,
                color: Color.lerp(
                  obGood,
                  Colors.white,
                  doneProgress.clamp(0.0, 1.0),
                ),
              )
            : const SizedBox(
                key: ValueKey('spin'),
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: obTextDim,
                ),
              ),
      ),
    );
  }
}

class _LatticePainter extends CustomPainter {
  final List<Offset> nodes;
  final List<(int, int)> edges;
  final double reveal;
  final double doneProgress;

  const _LatticePainter({
    required this.nodes,
    required this.edges,
    required this.reveal,
    required this.doneProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nodeRadius = size.width * 0.028;
    final nodeCount = nodes.length;
    double nodeProgress(int i) => ((reveal * nodeCount) - i).clamp(0.0, 1.0);

    bool edgeVisible(int a, int b) =>
        nodeProgress(a) > 0.5 && nodeProgress(b) > 0.5;

    final baseColor = const Color(0xFF2A2A2A);
    final activeColor = Color.lerp(Colors.white, obGood, doneProgress)!;
    final edgeColor = Color.lerp(baseColor, activeColor, doneProgress)!;

    // ── Outer ring edges ─────────────────────────────────────────────
    for (final (a, b) in edges) {
      if (!edgeVisible(a, b)) continue;
      final pa = Offset(nodes[a].dx * size.width, nodes[a].dy * size.height);
      final pb = Offset(nodes[b].dx * size.width, nodes[b].dy * size.height);
      canvas.drawLine(
        pa,
        pb,
        Paint()
          ..color = edgeColor
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Outer nodes only (centre is empty) ───────────────────────────
    for (int i = 0; i < nodes.length; i++) {
      final p = nodeProgress(i);
      if (p <= 0) continue;

      final center = Offset(nodes[i].dx * size.width, nodes[i].dy * size.height);
      final r = nodeRadius * (0.4 + 0.6 * p);

      canvas.drawCircle(
        center,
        r * 2.0,
        Paint()
          ..color = activeColor.withValues(alpha: 0.12 + 0.28 * p)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        center,
        r,
        Paint()..color = activeColor.withValues(alpha: 0.55 + 0.45 * p),
      );
    }

    // Soft outer ring on completion — does not cover the centre badge.
    if (doneProgress > 0) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width * 0.48,
        Paint()
          ..color = obGood.withValues(alpha: 0.18 * doneProgress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_LatticePainter old) =>
      old.reveal != reveal || old.doneProgress != doneProgress;
}

// ─── Text block ────────────────────────────────────────────────────────────

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
            color: obText,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(body, style: const TextStyle(color: obTextSub, fontSize: 15, height: 1.6)),
      ],
    );
  }
}

// ─── NIST badge ────────────────────────────────────────────────────────────

class _NistBadge extends StatelessWidget {
  const _NistBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: obPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: obBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.shield_outlined, color: obTextDim, size: 14),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'CRYSTALS-Dilithium (ML-DSA) · NIST FIPS 204',
              style: TextStyle(
                color: obTextSub,
                fontSize: 11,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
