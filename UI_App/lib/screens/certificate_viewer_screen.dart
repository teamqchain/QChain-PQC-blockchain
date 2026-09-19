import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qchain_shared/certificate_template.dart';
import 'package:qchain_shared/certificate_viewer.dart';
import 'package:qwallet_mobileapp/Headers/QPageTitle.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';

/// Full-screen certificate for QWallet — same fixed-A4 sheet as QPortal.
class CertificateViewerScreen extends StatefulWidget {
  final CertificateData data;

  const CertificateViewerScreen({super.key, required this.data});

  @override
  State<CertificateViewerScreen> createState() =>
      _CertificateViewerScreenState();
}

class _CertificateViewerScreenState extends State<CertificateViewerScreen>
    with SingleTickerProviderStateMixin {
  static const double _doubleTapZoom = 2.5;

  final TransformationController _transform = TransformationController();
  late final AnimationController _zoomAnim;
  Animation<Matrix4>? _matrixAnim;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _zoomAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() {
        final anim = _matrixAnim;
        if (anim != null) _transform.value = anim.value;
      });
  }

  @override
  void dispose() {
    _zoomAnim.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final details = _doubleTapDetails;
    if (details == null) return;

    final currentScale = _transform.value.getMaxScaleOnAxis();
    final Matrix4 end;

    if (currentScale > 1.05) {
      // Zoomed in → reset to fit.
      end = Matrix4.identity();
    } else {
      // Zoom into the double-tap point on the certificate.
      final pos = details.localPosition;
      final x = -pos.dx * (_doubleTapZoom - 1);
      final y = -pos.dy * (_doubleTapZoom - 1);
      end = Matrix4.identity()
        ..translateByDouble(x, y, 0, 1)
        ..scaleByDouble(_doubleTapZoom, _doubleTapZoom, 1, 1);
    }

    _matrixAnim = Matrix4Tween(begin: _transform.value, end: end).animate(
      CurvedAnimation(parent: _zoomAnim, curve: Curves.easeOutCubic),
    );
    _zoomAnim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: qBgSurface,
      body: Column(
        children: [
          // ── Black hero header ──────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: qPrimary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, 28),
            child: Column(
              children: [
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
                          Icons.close_rounded,
                          color: qBg,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: QPageTitle(
                        mainTitle: 'Certificate',
                        subTitle: 'Document preview',
                        mainFontSize: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: qRedBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: qRed.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: qRed),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'View only · not presentable',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: qRed,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 0.5,
              maxScale: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                // Double-tap only on the certificate sheet itself.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTapDown: _handleDoubleTapDown,
                  onDoubleTap: _handleDoubleTap,
                  child: CertificateSheet(
                    data: widget.data,
                    showWatermark: true,
                    maxWidth: null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

