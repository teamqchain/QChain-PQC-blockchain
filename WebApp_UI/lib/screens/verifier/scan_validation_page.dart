// screens/verifier/scan_to_validate_page.dart
//
// Scan to Validate — verifier scans a QR code via a connected hardware scanner.
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   import 'package:qportal_webapp/screens/verifier/scan_to_validate_page.dart';
//
//   case RouteName.scanQR:
//     return ScanToValidatePage(
//       onBack: () => _handleNavigate(RouteName.dashboard),
//     );

import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/app_button.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  SCAN STATE
// ═════════════════════════════════════════════════════════════════════════════

enum _ScanState {
  idle, // waiting for scanner input
  failed, // scan was attempted but failed
}

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class ScanToValidatePage extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback? onScanSuccess;

  const ScanToValidatePage({super.key, required this.onBack, this.onScanSuccess});

  @override
  State<ScanToValidatePage> createState() => _ScanToValidatePageState();
}

class _ScanToValidatePageState extends State<ScanToValidatePage>
    with SingleTickerProviderStateMixin {
  _ScanState _state = _ScanState.idle;

  // Pulse animation for the idle scanning indicator
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.1,
      end: 0.75,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  void _resetToIdle() => setState(() => _state = _ScanState.idle);

  // ── For development / demo only — simulates a failed scan ─────────────────
  void _simulateFail() => setState(() => _state = _ScanState.failed);

  // ── For development / demo only — simulates a successful scan ─────────────
  void _simulateSuccess() => widget.onScanSuccess?.call();

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title
          Text(
            'Scan to Validate',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // Main container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _state == _ScanState.failed
                      ? _buildFailed()
                      : _buildIdle(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              AppButton(
                label: 'Back',
                icon: Icons.arrow_back_rounded,
                onTap: widget.onBack,
                showBorder: true,
                borderColor: AppColors.border,
              ),
              if (_state == _ScanState.failed) ...[
                const SizedBox(width: 10),
                AppButton(
                  label: 'Try Again',
                  backgroundColor: AppColors.verifyingAccent,
                  icon: Icons.refresh_rounded,
                  onTap: _resetToIdle,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─── IDLE STATE ────────────────────────────────────────────────────────────

  Widget _buildIdle() {
    return KeyedSubtree(
      key: const ValueKey('idle'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dotted scan area
          _DottedScanArea(pulseAnim: _pulseAnim),
          const SizedBox(height: 28),

          // Status text
          Text(
            'Waiting for hardware scanner…',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 12,
              color: AppColors.textDim,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Connect your QR scanner device and scan a credential QR code.',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 11,
              color: AppColors.textDim.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),

          // Dev-only: simulate buttons (small, dimmed)
          const SizedBox(height: 32),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _simulateSuccess,
                  child: Text(
                    'Simulate successful scan',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 10,
                      color: AppColors.verifyingAccent.withOpacity(0.4),
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.verifyingAccent.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _simulateFail,
                  child: Text(
                    'Simulate scan failure',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 10,
                      color: AppColors.textDim.withOpacity(0.4),
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textDim.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── FAILED STATE ──────────────────────────────────────────────────────────

  Widget _buildFailed() {
    return KeyedSubtree(
      key: const ValueKey('failed'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dotted area — error variant
          _DottedScanArea(failed: true, pulseAnim: _pulseAnim),
          const SizedBox(height: 28),

          // Error message
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 16,
                color: AppColors.revoked,
              ),
              const SizedBox(width: 8),
              Text(
                'Scanning failed. Try again.',
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.revoked,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Make sure the QR code is clearly visible and the scanner is connected.',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 11,
              color: AppColors.textDim,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DOTTED SCAN AREA
// ═════════════════════════════════════════════════════════════════════════════

class _DottedScanArea extends StatelessWidget {
  final bool failed;
  final Animation<double> pulseAnim;

  const _DottedScanArea({this.failed = false, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    final Color accent = failed ? AppColors.revoked : AppColors.verifyingAccent;

    return CustomPaint(
      painter: _DottedBorderPainter(color: accent, failed: failed),
      child: SizedBox(
        width: 260,
        height: 260,
        child: Center(
          child: failed
              ? _buildFailedContent(accent)
              : _buildIdleContent(accent),
        ),
      ),
    );
  }

  Widget _buildIdleContent(Color accent) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, child) => Opacity(opacity: pulseAnim.value, child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.qr_code_scanner_rounded,
            size: 64,
            color: AppColors.verifyingAccent,
          ),
          const SizedBox(height: 14),
          Text(
            'Scan to Validate',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.verifyingAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedContent(Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.qr_code_2_rounded,
          size: 64,
          color: accent.withOpacity(0.45),
        ),
        const SizedBox(height: 14),
        Text(
          'Scan to Validate',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: accent.withOpacity(0.55),
          ),
        ),
      ],
    );
  }
}

// ─── DOTTED BORDER PAINTER ────────────────────────────────────────────────────

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  final bool failed;

  const _DottedBorderPainter({required this.color, required this.failed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(failed ? 0.55 : 0.7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double dot = 8; // near-zero dash → perfect circle
    const double gap = 8;
    const double r = 14.0; // corner radius

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(r));

    // Draw full dotted rounded-rect outline
    _drawDashedRRect(canvas, paint, rrect, dot, gap);
  }

  void _drawDashedRRect(
    Canvas canvas,
    Paint paint,
    RRect rrect,
    double dash,
    double gap,
  ) {
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      bool drawing = true;
      while (distance < metric.length) {
        final len = drawing ? dash : gap;
        if (drawing) {
          canvas.drawPath(
            metric.extractPath(
              distance,
              (distance + len).clamp(0, metric.length),
            ),
            paint,
          );
        }
        distance += len;
        drawing = !drawing;
      }
    }
  }

  @override
  bool shouldRepaint(_DottedBorderPainter old) =>
      old.color != color || old.failed != failed;
}
