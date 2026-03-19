import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/components/overlays.dart';
import 'package:qwallet_mobileapp/model/IdentityDoc.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';

class CardDetailOverlay extends StatefulWidget {
  final IdentityDoc doc;
  final VoidCallback onClose;

  const CardDetailOverlay({required this.doc, required this.onClose});

  @override
  State<CardDetailOverlay> createState() => _CardDetailOverlayState();
}

class _CardDetailOverlayState extends State<CardDetailOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _slideY;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideY = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _ctrl.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;

    return FadeTransition(
      opacity: _fade,
      child: Stack(
        children: [
          // ── Blurred backdrop ────────────────────────────────────────
          GestureDetector(
            onTap: _close,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: Colors.black.withOpacity(0.55)),
            ),
          ),

          // ── Card panel slides up from centre ─────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _slideY,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _slideY.value),
                child: child,
              ),
              child: GestureDetector(
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Container(
                    decoration: BoxDecoration(
                      color: doc.cardColor,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: doc.cardColor.withOpacity(0.4),
                          blurRadius: 90,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // Large watermark
                        Positioned(
                          right: -20,
                          bottom: -20,
                          child: Opacity(
                            opacity: 0.06,
                            child: Text(
                              doc.emoji,
                              style: const TextStyle(fontSize: 180),
                            ),
                          ),
                        ),
                        // Logo shine
                        Positioned(
                          top: -20,
                          right: -100,
                          child: Container(
                            width: 300,
                            height: 300,
                            child: Image.asset(
                              'assets/images/QChain_logo.png',
                              opacity:
                                  const AlwaysStoppedAnimation<double>(0.04),
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top: icon + close
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withOpacity(0.12),
                                      borderRadius:
                                          BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white
                                            .withOpacity(0.15),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      doc.emoji,
                                      style:
                                          const TextStyle(fontSize: 30),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _close,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white
                                              .withOpacity(0.2),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 22),

                              Text(
                                doc.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                doc.subtitle,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),

                              const SizedBox(height: 24),

                              Divider(
                                color: Colors.white.withOpacity(0.1),
                                height: 1,
                              ),

                              const SizedBox(height: 24),

                              OverlayField(
                                label: 'DOCUMENT NUMBER',
                                value: doc.number,
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: OverlayField(
                                      label: 'ISSUED',
                                      value: doc.issued,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: OverlayField(
                                      label: 'EXPIRES',
                                      value: doc.expires,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // Verified badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E)
                                      .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF22C55E)
                                        .withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF22C55E),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '✓  Verified on blockchain',
                                      style: TextStyle(
                                        color: Color(0xFF22C55E),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 22),

                              // Action buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OverlayBtn(
                                      icon: Icons.qr_code_2,
                                      label: 'Present',
                                      onTap: () {
                                        Get.toNamed(
                                          Routes.PRESENT,
                                          arguments: doc,
                                        );
                                        _close();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OverlayBtn(
                                      icon: Icons.info_outline_rounded,
                                      label: 'Details',
                                      onTap: () {
                                        Get.toNamed(
                                          Routes.DETAIL,
                                          arguments: doc,
                                        );
                                        _close();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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