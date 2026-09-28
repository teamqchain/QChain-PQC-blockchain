import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';
import 'package:qwallet_mobileapp/utils/haptics.dart';

/// iOS-style floating banner (activity, subscriptions, etc.).
///
/// [title] is the bold primary action line (e.g. "New credential issued").
/// [subtitle] is optional supporting detail under it.
class IosActivityBanner extends StatefulWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;
  final Duration autoDismissAfter;

  const IosActivityBanner({
    super.key,
    required this.title,
    this.subtitle,
    required this.onDismiss,
    this.onTap,
    this.autoDismissAfter = const Duration(seconds: 4),
  });

  @override
  State<IosActivityBanner> createState() => _IosActivityBannerState();
}

class _IosActivityBannerState extends State<IosActivityBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _autoTimer;
  double _dragDy = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    QHaptics.success();
    _autoTimer = Timer(widget.autoDismissAfter, _dismiss);
  }

  Future<void> _dismiss() async {
    _autoTimer?.cancel();
    if (!mounted) return;
    await _ctrl.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: topPad + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: () {
              widget.onTap?.call();
              _dismiss();
            },
            onVerticalDragUpdate: (d) {
              if (d.delta.dy < 0) setState(() => _dragDy += d.delta.dy);
            },
            onVerticalDragEnd: (d) {
              if (_dragDy < -24 || (d.primaryVelocity ?? 0) < -200) {
                _dismiss();
              } else {
                setState(() => _dragDy = 0);
              }
            },
            child: Transform.translate(
              offset: Offset(0, _dragDy.clamp(-80, 0)),
              child: _BannerCard(
                title: widget.title,
                subtitle: widget.subtitle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _BannerCard({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xF2F2F2F7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/QWallet_logo_uae.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 40,
                    height: 40,
                    color: qPrimary,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1C1C1E),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'now',
                          style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (hasSubtitle) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF3A3A3C),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
