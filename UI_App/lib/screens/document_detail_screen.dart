import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/constants/colors.dart';
import 'package:qwallet_mobileapp/model/IdentityDoc.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';
import 'package:qwallet_mobileapp/screens/selective_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DOCUMENT DETAIL SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({super.key});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late final IdentityDoc doc;

  @override
  void initState() {
    super.initState();
    // Arguments are guaranteed to be set by the time initState runs
    doc = Get.arguments as IdentityDoc;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          _DocHeroBox(doc: doc),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ValidBar(
                    onQrTap: () => Get.toNamed(Routes.PRESENT, arguments: doc),
                  ),
                  const SizedBox(height: 24),
                  _DetailsSection(doc: doc),
                  const SizedBox(height: 28),
                  _BottomActions(doc: doc),
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

class _DocHeroBox extends StatelessWidget {
  final IdentityDoc doc;
  const _DocHeroBox({required this.doc});

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
      padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      'Document',
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

          const SizedBox(height: 20),

          // ── Original Document Preview Card ──
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: doc.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: doc.cardColor.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Dot-grid texture
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: CustomPaint(painter: _GridPainter()),
                  ),
                ),
                // Shine orb
                Positioned(
                  top: -40,
                  left: -20,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withOpacity(0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Watermark emoji
                Positioned(
                  right: -15,
                  bottom: -15,
                  child: Opacity(
                    opacity: 0.07,
                    child: Icon(
                      doc.icon,
                      size: 120,
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ISSUED BY',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                doc.subtitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.18),
                              ),
                            ),
                            child: Icon(
                              doc.icon,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        doc.title.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Ahmed Salih',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'ISSUED ${doc.issued}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'EXPIRES ${doc.expires}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // "ORIGINAL DOCUMENT" chip
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ORIGINAL DOCUMENT',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;
    const spacing = 18.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// VALID BAR
// ─────────────────────────────────────────────────────────────────────────────

class _ValidBar extends StatefulWidget {
  final VoidCallback onQrTap;
  const _ValidBar({required this.onQrTap});

  @override
  State<_ValidBar> createState() => _ValidBarState();
}

class _ValidBarState extends State<_ValidBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _fade = Tween(begin: 0.3, end: 1.0).animate(_blink);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF22C55E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: green.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          FadeTransition(
            opacity: _fade,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: green,
                boxShadow: [
                  BoxShadow(color: green, blurRadius: 6, spreadRadius: 1),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'VALID',
            style: TextStyle(
              color: green,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onQrTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: green.withOpacity(0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_2, color: green, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Present',
                    style: TextStyle(
                      color: green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
// DETAILS SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _DetailsSection extends StatelessWidget {
  final IdentityDoc doc;
  const _DetailsSection({required this.doc});

  @override
  Widget build(BuildContext context) {
    final fields = <_DetailRow>[
      _DetailRow(label: 'Document Type', value: doc.title),
      _DetailRow(
        label: 'Credential ID',
        value: '${doc.number.replaceAll(' ', '')}',
      ),
      const _DetailRow(label: 'Issued To', value: 'Ahmed Salih'),
      const _DetailRow(label: 'National ID', value: '784-2004-7654321-1'),
      _DetailRow(label: 'Issuing Authority', value: doc.subtitle),
      const _DetailRow(
        label: 'Country of Issue',
        value: 'United Arab Emirates',
      ),
      _DetailRow(label: 'Date of Issue', value: doc.issued),
      _DetailRow(label: 'Expiry Date', value: doc.expires, highlight: true),
      const _DetailRow(
        label: 'Digital Signature',
        value: 'ML-DSA',
      ),
      // const _DetailRow(
      //   label: 'Blockchain Anchor',
      //   value: 'QChain · Block #48821',
      // ),
      // const _DetailRow(label: 'DID', value: 'did:fabric:0x3f...8a2c'),
      // const _DetailRow(label: 'Schema Version', value: 'W3C VC 2.0'),
      const _DetailRow(
        label: 'Verification Status',
        value: 'Valid',
        statusColor: Color(0xFF22C55E),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Document Details',
          style: TextStyle(
            color: Color(0xFF111111),
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),
        Container(
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
            children: fields.asMap().entries.map((e) {
              return _DetailTile(
                row: e.value,
                isLast: e.key == fields.length - 1,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DetailRow {
  final String label;
  final String value;
  final bool highlight;
  final Color? statusColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.statusColor,
  });
}

class _DetailTile extends StatelessWidget {
  final _DetailRow row;
  final bool isLast;
  const _DetailTile({required this.row, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: !isLast
            ? const Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              row.label,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: row.statusColor != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: row.statusColor!.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        row.value,
                        style: TextStyle(
                          color: row.statusColor!,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                : Text(
                    row.value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: row.highlight
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF111111),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM ACTIONS
// ─────────────────────────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final IdentityDoc doc;
  const _BottomActions({required this.doc});

  void _goToSelectiveShare(BuildContext context, ShareMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SelectiveShareScreen(doc: doc, mode: mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            icon: Icons.link,
            label: 'Share Link',
            bgColor: const Color(0xFF111111),
            fgColor: Colors.white,
            onTap: () => _goToSelectiveShare(context, ShareMode.link),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionBtn(
            icon: Icons.download_outlined,
            label: 'Export',
            bgColor: Colors.white,
            fgColor: const Color(0xFF111111),
            border: const Color(0xFFDDDDDD),
            onTap: () => _goToSelectiveShare(context, ShareMode.export),
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color fgColor;
  final Color? border;
  final VoidCallback onTap;

  const _ActionBtn({
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
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
            const SizedBox(width: 8),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SELECTIVE SHARE SCREEN
// ─────────────────────────────────────────────────────────────────────────────

