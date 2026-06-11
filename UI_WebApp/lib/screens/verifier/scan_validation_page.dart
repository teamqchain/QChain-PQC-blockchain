// screens/verifier/scan_to_validate_page.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/services/api_service.dart';
import 'package:qportal_webapp/models/verifiying_models.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  SCAN STATE
// ═════════════════════════════════════════════════════════════════════════════

enum _ScanState { scanning, processing, failed }

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class ScanToValidatePage extends StatefulWidget {
  final VoidCallback onBack;
  // UPDATED: Now accepts the actual verification result from the API
  final Function(VerificationResult)? onScanSuccess;

  const ScanToValidatePage({
    super.key,
    required this.onBack,
    this.onScanSuccess,
  });

  @override
  State<ScanToValidatePage> createState() => _ScanToValidatePageState();
}

class _ScanToValidatePageState extends State<ScanToValidatePage>
    with SingleTickerProviderStateMixin {
  _ScanState _state = _ScanState.scanning;
  String _errorMessage = 'Scanning failed. Try again.'; // Dynamic error message

  late final MobileScannerController _cameraController;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(
      begin: 0.1,
      end: 0.75,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  void _resetToScanning() {
    setState(() {
      _state = _ScanState.scanning;
      _errorMessage = 'Scanning failed. Try again.';
    });
    _cameraController.start();
  }

  // ─── LIVE API QR DETECTION LOGIC ───────────────────────────────────────────

  void _handleDetect(BarcodeCapture capture) async {
    if (_state != _ScanState.scanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String code = barcodes.first.rawValue!;

      // 1. Pause the camera immediately
      _cameraController.stop();

      // 2. Show the loading spinner
      setState(() => _state = _ScanState.processing);

      try {
        // 3. Hit the backend
        final result = await ApiService.resolveSession(code);

        // 4. Pass the result up to the shell
        if (mounted) {
          widget.onScanSuccess?.call(result);
        }
      } catch (e) {
        debugPrint("QR Resolution Error: $e");
        if (mounted) {
          setState(() {
            _state = _ScanState.failed;
            // Clean up the error message for the UI
            _errorMessage = e.toString().replaceAll('Exception: ', '');
          });
        }
      }
    }
  }

  // ── For development / demo only — simulates API outcomes ─────────────────
  void _simulateFail() {
    _cameraController.stop();
    setState(() {
      _state = _ScanState.failed;
      _errorMessage = 'Simulated failure triggered.';
    });
  }

  void _simulateSuccess() {
    _cameraController.stop();
    // Simulate passing a valid credential to bypass the API for local Mac testing
    widget.onScanSuccess?.call(VerifyingMockData.valid());
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan to Validate',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
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
                  child: _buildStateContent(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                  onTap: _resetToScanning,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStateContent() {
    switch (_state) {
      case _ScanState.scanning:
        return _buildScanning();
      case _ScanState.processing:
        return _buildProcessing();
      case _ScanState.failed:
        return _buildFailed();
    }
  }

  Widget _buildScanning() {
    return KeyedSubtree(
      key: const ValueKey('scanning'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DottedScanArea(
            pulseAnim: _pulseAnim,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MobileScanner(
                controller: _cameraController,
                onDetect: _handleDetect,
                errorBuilder: (context, error) {
                  return Center(
                    child: Icon(
                      Icons.videocam_off,
                      color: AppColors.textDim.withOpacity(0.5),
                      size: 40,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Align QR code within the frame',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 12,
              color: AppColors.textDim,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _cameraController.switchCamera(),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cameraswitch_rounded,
                    size: 16,
                    color: AppColors.verifyingAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Switch Camera',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 12,
                      color: AppColors.verifyingAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSimulateButtons(),
        ],
      ),
    );
  }

  Widget _buildProcessing() {
    return KeyedSubtree(
      key: const ValueKey('processing'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.verifyingAccent),
          const SizedBox(height: 24),
          Text(
            'Resolving session securely...',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 13,
              color: AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailed() {
    return KeyedSubtree(
      key: const ValueKey('failed'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DottedScanArea(
            failed: true,
            pulseAnim: _pulseAnim,
            child: Center(
              child: Icon(
                Icons.qr_code_2_rounded,
                size: 64,
                color: AppColors.revoked.withOpacity(0.45),
              ),
            ),
          ),
          const SizedBox(height: 28),
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
                _errorMessage, // Display the exact error from the backend
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.revoked,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimulateButtons() {
    return Row(
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
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DOTTED SCAN AREA
// ═════════════════════════════════════════════════════════════════════════════

class _DottedScanArea extends StatelessWidget {
  final bool failed;
  final Animation<double> pulseAnim;
  final Widget child;

  const _DottedScanArea({
    this.failed = false,
    required this.pulseAnim,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = failed ? AppColors.revoked : AppColors.verifyingAccent;

    return CustomPaint(
      painter: _DottedBorderPainter(color: accent, failed: failed),
      child: SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Padding(padding: const EdgeInsets.all(4.0), child: child),
            ),
            if (!failed)
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, child) =>
                    Opacity(opacity: pulseAnim.value, child: child),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.verifyingAccent.withOpacity(0.5),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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

    const double dot = 8;
    const double gap = 8;
    const double r = 14.0;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(r));

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
