import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qchain_shared/certificate_template.dart';

/// Fixed A4 landscape certificate sheet.
///
/// Designed at a constant pixel size, then [FittedBox] scales the *entire*
/// sheet down for smaller screens — fonts/logo/spacing never rearrange.
class CertificateSheet extends StatelessWidget {
  final CertificateData data;
  final bool showWatermark;
  final double? maxWidth;

  /// Design canvas (landscape A4 at 96 dpi ≈ 1123 × 794).
  static const designWidth = 1123.0;
  static const designHeight = 794.0;
  static const aspect = designWidth / designHeight;

  static const bgColor = Color(0xFFF0EFED);
  static const frameBorder = Color(0xFFD5D2CC);
  static const bukraFamily = 'packages/qchain_shared/29LT Bukra';
  static const timesFamily = 'packages/qchain_shared/Times New Roman';

  /// Package-scoped asset paths (shared package owns bg/logo/fonts).
  static const bgAsset = 'packages/qchain_shared/assets/images/certificate_bg.svg';
  static const logoAsset =
      'packages/qchain_shared/assets/images/unilogo_short.png';

  const CertificateSheet({
    super.key,
    required this.data,
    this.showWatermark = true,
    this.maxWidth = designWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Largest box that still fits the parent, keeps A4 aspect, and
        // never exceeds the design canvas (or optional maxWidth cap).
        final availW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : designWidth;
        final availH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : designHeight;

        // null maxWidth = no hard cap (fill parent). Otherwise never
        // exceed the given cap (default: designWidth = real A4).
        final capW = maxWidth ?? availW;
        var w = availW < capW ? availW : capW;
        var h = w / aspect;
        if (h > availH) {
          h = availH;
          w = h * aspect;
        }
        // Guard against zero/negative when parent is collapsing.
        if (w <= 0 || h <= 0) return const SizedBox.shrink();

        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: frameBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.40),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                // Fixed design canvas scaled uniformly into the A4 box.
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: designWidth,
                    height: designHeight,
                    child: _CertificateCanvas(
                      data: data,
                      showWatermark: showWatermark,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Always paints at [CertificateSheet.designWidth] × [designHeight].
class _CertificateCanvas extends StatelessWidget {
  final CertificateData data;
  final bool showWatermark;

  const _CertificateCanvas({
    required this.data,
    required this.showWatermark,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: CertificateSheet.bgColor),
        Positioned.fill(
          child: SvgPicture.asset(
            CertificateSheet.bgAsset,
            fit: BoxFit.fill,
            placeholderBuilder: (_) =>
                const ColoredBox(color: CertificateSheet.bgColor),
          ),
        ),
        Positioned.fill(
          child: Column(
            children: [
              const _Header(),
              Expanded(child: _Body(data: data)),
              _Footer(data: data),
            ],
          ),
        ),
        if (showWatermark) const _Watermark(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  static const _labelStyle = TextStyle(
    fontFamily: CertificateSheet.bukraFamily,
    fontFamilyFallback: ['SFPro', 'Arial'],
    fontWeight: FontWeight.w500,
    fontSize: 27,
    height: 1.2,
    color: Color(0xFF111111),
  );

  @override
  Widget build(BuildContext context) {
    // Fixed design metrics (A4 landscape @ designWidth). Never rescale per screen.
    return Padding(
      padding: const EdgeInsets.fromLTRB(62, 40, 62, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Text(
              'United Arab Emirates',
              textAlign: TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _labelStyle,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: _Logo(height: 104),
          ),
          const Expanded(
            child: Text(
              'الإمارات العربية المتحدة',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _labelStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final double height;
  const _Logo({required this.height});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      CertificateSheet.logoAsset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(
        Icons.account_balance,
        size: height * 0.7,
        color: const Color(0xFF1F3A2E),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final CertificateData data;
  const _Body({required this.data});

  static const _ink = Color(0xFF111111);
  static const _family = CertificateSheet.timesFamily;

  static TextStyle _plain(double size, {FontStyle style = FontStyle.normal}) =>
      TextStyle(
        fontFamily: _family,
        fontFamilyFallback: const ['Times', 'serif', 'Georgia'],
        fontSize: size,
        height: 1.4,
        color: _ink,
        fontWeight: FontWeight.w400,
        fontStyle: style,
      );

  static TextStyle _emphasis(double size) => TextStyle(
        fontFamily: _family,
        fontFamilyFallback: const ['Times', 'serif', 'Georgia'],
        fontSize: size,
        height: 1.35,
        color: _ink,
        fontWeight: FontWeight.w700,
      );

  @override
  Widget build(BuildContext context) {
    // Fixed A4 body metrics — never clamp/recompute per device width.
    const sidePad = 120.0;
    const bodySize = 27.0;
    const nameSize = 40.0;
    const degreeSize = 31.0;
    const gap = 13.0;

    Widget line(String text, {TextStyle? style}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: style ?? _plain(bodySize),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(sidePad, 16, sidePad, 0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            line(
              'The University of Sharjah hereby certifies that',
              style: _plain(bodySize, style: FontStyle.italic),
            ),
            const SizedBox(height: gap),
            line('${data.holderName},', style: _emphasis(nameSize)),
            const SizedBox(height: gap * 0.65),
            line('with Student ID ${data.studentId},'),
            const SizedBox(height: gap),
            line(
              'has successfully fulfilled all requirements for the degree of',
            ),
            const SizedBox(height: gap * 0.8),
            line(data.degree, style: _emphasis(degreeSize)),
            const SizedBox(height: gap * 0.8),
            line('under the ${data.college},'),
            const SizedBox(height: gap * 0.5),
            line('with ${data.grade} standing,'),
            const SizedBox(height: gap * 0.5),
            line('in the ${data.graduationYear}'),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final CertificateData data;
  const _Footer({required this.data});

  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF444444);
  static const _family = CertificateSheet.timesFamily;

  @override
  Widget build(BuildContext context) {
    // Fixed A4 footer metrics. Right note = design 40px × SVG scale ≈ 10.6.
    const sidePad = 38.0;
    const bottomPad = 28.0;
    const topPad = 8.0;
    const issuedSize = 20.0;
    const noteSize = 16.0;
    const rightSize = 11.0;

    const rightStyle = TextStyle(
      fontFamily: _family,
      fontFamilyFallback: ['Times', 'serif', 'Georgia'],
      fontSize: rightSize,
      fontWeight: FontWeight.w400,
      height: 1.35,
      color: _muted,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(sidePad, topPad, sidePad, bottomPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Issued on: ${data.issueDate}',
                  style: const TextStyle(
                    fontFamily: _family,
                    fontFamilyFallback: ['Times', 'serif', 'Georgia'],
                    fontSize: issuedSize,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Any deletion or alteration to this document will render it invalid.',
                  style: TextStyle(
                    fontFamily: _family,
                    fontFamilyFallback: ['Times', 'serif', 'Georgia'],
                    fontSize: noteSize,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 45),
          const Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.only(right: 0.0, bottom: 45),
              child: Text(
                'This document doest not require a signature, as it '
                'has been digitally signed and authenticated using',
                textAlign: TextAlign.right,
                style: rightStyle,
              ),
            ),
          ),
          
        ],
      ),
    );
  }
}

class _Watermark extends StatelessWidget {
  const _Watermark();

  @override
  Widget build(BuildContext context) {
    // Positioned MUST be a direct Stack child — wrap IgnorePointer inside it.
    return const Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _WatermarkPainter()),
      ),
    );
  }
}

/// Tiles "NOT PRESENTABLE" across the entire sheet on a rotated grid so the
/// watermark repeats everywhere instead of appearing once in the centre.
class _WatermarkPainter extends CustomPainter {
  const _WatermarkPainter();

  static const _text = 'NOT PRESENTABLE';
  static const _fontSize = 18.0;
  static const _angle = -0.5; // radians (~ -28°)
  static const _alpha = 0.07;

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: _text,
        style: const TextStyle(
          fontSize: _fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: Color.fromRGBO(0, 0, 0, _alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final stepX = tp.width + 90;
    final stepY = tp.height + 130;
    // Expand the grid so rotation doesn't leave uncovered corners.
    final extra = (tp.width + tp.height) * 1.5;
    final startX = -extra;
    final endX = size.width + extra;
    final startY = -extra;
    final endY = size.height + extra;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(_angle);
    canvas.translate(-size.width / 2, -size.height / 2);

    for (var y = startY; y < endY; y += stepY) {
      // Offset every other row for a staggered brick pattern.
      final rowOffset = (((y - startY) / stepY).round() % 2) * (stepX / 2);
      for (var x = startX + rowOffset; x < endX; x += stepX) {
        tp.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WatermarkPainter oldDelegate) => false;
}
