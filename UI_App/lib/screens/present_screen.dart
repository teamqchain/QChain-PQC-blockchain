import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/model/IdentityDoc.dart';
import 'package:qwallet_mobileapp/screens/document_detail_screen.dart';
import 'package:qwallet_mobileapp/screens/selective_screen.dart';

class PresentScreen extends StatefulWidget {
  const PresentScreen({super.key});

  @override
  State<PresentScreen> createState() => _PresentScreenState();
}

class _PresentScreenState extends State<PresentScreen> {
  late final IdentityDoc doc;

  static const _totalSeconds = 10;  //1 * 60; // 5 minutes
  late int _secondsLeft;
  Timer? _timer;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    doc = Get.arguments as IdentityDoc;
    _secondsLeft = _totalSeconds;
    _startTimer();
  }

  void _startTimer() {
    _expired = false;
    _secondsLeft = _totalSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
        setState(() => _expired = true);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _refresh() => setState(() => _startTimer());

  String get _timeLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress => _secondsLeft / _totalSeconds;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          _PresentHeroBox(doc: doc, expired: _expired),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                children: [
                  _TimerCard(
                    timeLabel: _timeLabel,
                    progress: _progress,
                    expired: _expired,
                  ),
                  const SizedBox(height: 16),
                  _PresentActionBtn(
                    icon: Icons.refresh_rounded,
                    label: 'Refresh QR Code',
                    bgColor: _expired
                        ? const Color(0xFF111111)
                        : const Color(0xFFCCCCCC),
                    fgColor: Colors.white,
                    onTap: _expired ? _refresh : null,
                  ),
                  const SizedBox(height: 12),
                  _PresentActionBtn(
                    icon: Icons.link,
                    label: 'Share Link Instead',
                    bgColor: Colors.white,
                    fgColor: const Color(0xFF111111),
                    border: const Color(0xFFDDDDDD),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SelectiveShareScreen(
                            doc: doc,
                            mode: ShareMode.link,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  _InfoNote(expired: _expired),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO BOX
// ─────────────────────────────────────────────────────────────────────────────

class _PresentHeroBox extends StatelessWidget {
  final IdentityDoc doc;
  final bool expired;

  const _PresentHeroBox({required this.doc, required this.expired});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, 32),
      child: Column(
        children: [
          // Back + title row
          Row(
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A1A1A),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Present Document',
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doc.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Icon(doc.icon, size: 18),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── QR Code Box ──
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: expired
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: expired
                    ? const Color(0xFF333333)
                    : Colors.white.withOpacity(0.15),
                width: 2,
              ),
              boxShadow: expired
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.08),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
            ),
            child: expired
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_off_outlined,
                        color: Colors.white.withOpacity(0.3),
                        size: 48,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'QR Expired',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap Refresh to regenerate',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      // Corner brackets for visual framing
                      const _QrCorners(),
                      // QR icon placeholder
                      Icon(
                        Icons.qr_code_2,
                        size: 160,
                        color: const Color(0xFF111111).withOpacity(0.88),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 20),

          // Issuer + doc name label below QR
          Text(
            doc.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            doc.subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Decorative corner brackets drawn around the QR area
class _QrCorners extends StatelessWidget {
  const _QrCorners();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: CustomPaint(
        size: const Size(double.infinity, double.infinity),
        painter: _CornerPainter(),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111111).withOpacity(0.15)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const len = 18.0;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(Offset(0, len), Offset(0, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(len, 0), paint);
    // Top-right
    canvas.drawLine(Offset(w - len, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, h - len), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    // Bottom-right
    canvas.drawLine(Offset(w - len, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h - len), Offset(w, h), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TimerCard extends StatelessWidget {
  final String timeLabel;
  final double progress;
  final bool expired;

  const _TimerCard({
    required this.timeLabel,
    required this.progress,
    required this.expired,
  });

  @override
  Widget build(BuildContext context) {
    final color = expired
        ? const Color(0xFFEF4444)
        : progress > 0.4
        ? const Color(0xFF22C55E)
        : progress > 0.15
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEBEBEB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    expired ? Icons.timer_off_outlined : Icons.timer_outlined,
                    color: color,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    expired ? 'QR Code Expired' : 'QR Code expires in',
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                expired ? '00:00' : timeLabel,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: expired ? 0 : progress,
              minHeight: 5,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _PresentActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color fgColor;
  final Color? border;
  final VoidCallback? onTap;

  const _PresentActionBtn({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.fgColor,
    required this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: border != null ? Border.all(color: border!) : null,
            boxShadow: bgColor == const Color(0xFF111111)
                ? const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fgColor, size: 18),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  color: fgColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO NOTE
// ─────────────────────────────────────────────────────────────────────────────

class _InfoNote extends StatelessWidget {
  final bool expired;
  const _InfoNote({required this.expired});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFAAAAAA), size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              expired
                  ? 'This QR code has expired for security reasons. Tap Refresh to generate a new one-time code.'
                  : 'Show this QR code to a verifier. It is single-use and expires after 5 minutes for your security.',
              style: const TextStyle(
                color: Color(0xFFAAAAAA),
                fontSize: 11,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
