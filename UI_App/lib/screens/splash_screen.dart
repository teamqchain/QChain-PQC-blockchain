import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:qwallet_mobileapp/theme/colors.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';
import 'package:qwallet_mobileapp/utils/app_config.dart';
import 'package:qwallet_mobileapp/utils/connectivity_monitor.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  StreamSubscription<bool>? _netSub;
  /// null = still probing (no banner); false = offline (red); true = online.
  bool? _online;
  /// After reconnect, briefly show green before hiding.
  bool _showBackOnline = false;
  Timer? _hideGreenTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween(
      begin: 0.15,
      end: 0.6,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _netSub = ConnectivityMonitor.instance.watch().listen(_onNetStatus);
  }

  void _onNetStatus(bool online) {
    if (!mounted) return;
    final wasOffline = _online == false;
    setState(() {
      _online = online;
      if (online && wasOffline) {
        // Just came back — flash green then dismiss.
        _showBackOnline = true;
        _hideGreenTimer?.cancel();
        _hideGreenTimer = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() => _showBackOnline = false);
        });
      } else if (!online) {
        _showBackOnline = false;
        _hideGreenTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _hideGreenTimer?.cancel();
    _netSub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showOffline = _online == false;
    final showGreen = _online == true && _showBackOnline;

    return Scaffold(
      backgroundColor: qBg,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        toolbarHeight: 0,
      ),
      body: SafeArea(
        child: Center(
          // Keeps the splash content centered on fold / wide screens.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Offline / back-online banner (top of splash).
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: showOffline
                        ? _NetBanner(
                            color: qBg,
                            bg: qRed,
                            icon: Icons.wifi_off_rounded,
                            text: 'No internet — you are offline',
                          )
                        : showGreen
                            ? _NetBanner(
                                color: qBg,
                                bg: qValid,
                                icon: Icons.wifi_rounded,
                                text: 'Back online',
                              )
                            : const SizedBox.shrink(),
                  ),

                  const Spacer(flex: 2),

                  // ── Logo area ────────────────────────────────────────────────
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) =>
                            const SizedBox(width: 160, height: 160),
                      ),
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) =>
                            const SizedBox(width: 120, height: 120),
                      ),
                      // Logo only (D4) — not title, not Get Started, not full screen.
                      // STORE GATE — remove onDoubleTap (or wrap in kDebugMode)
                      // before any App Store / production build (with Alice).
                      GestureDetector(
                        onDoubleTap: () {
                          HapticFeedback.lightImpact();
                          Get.toNamed(Routes.DEV_RUNTIME_CONFIG);
                        },
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          alignment: Alignment.center,
                          child: Image.asset(
                            'assets/images/wallet_icon_transparet.png',
                            width: 150,
                            height: 150,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Text(
                    'QWallet',
                    style: TextStyle(
                      fontSize: 36,
                      color: Colors.black,
                      letterSpacing: -1,
                      fontFamily: 'formula',
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'QChain assets',
                    style: TextStyle(
                      fontSize: 8,
                      color: qText,
                      letterSpacing: 1,
                      fontFamily: 'formula',
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── Button ───────────────────────────────────────────────────
                  // Offline → disabled. Still probing (_online == null) stays
                  // enabled so a slow first probe doesn't lock the button.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: showOffline
                              ? null
                              : () {
                                  // Controllers (and their API fetches) start only
                                  // after Onboard 3 finishes key check/registration.
                                  Get.toNamed(Routes.ONBOARD1);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: qPrimary,
                            foregroundColor: qBg,
                            disabledBackgroundColor: qBorder,
                            disabledForegroundColor: qSub,
                            elevation: 0,
                            minimumSize: const Size(0, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            showOffline ? 'No internet' : 'Get Started',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  RichText(
                    text: const TextSpan(
                      children: <TextSpan>[
                        TextSpan(
                          text: 'Powered by ',
                          style: TextStyle(
                            color: qDimmed,
                            fontSize: 11,
                            fontFamily: 'SFPro',
                          ),
                        ),
                        TextSpan(
                          text: 'QChain',
                          style: TextStyle(
                            color: qDimmed,
                            fontSize: 11,
                            fontFamily: 'formula',
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Manual IPA/build label — bump kAppBuildNumber in app_config.dart
                  Text(
                    'Build $kAppBuildNumber',
                    style: const TextStyle(
                      color: qDimmed,
                      fontSize: 10,
                      fontFamily: 'SFPro',
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NetBanner extends StatelessWidget {
  const _NetBanner({
    required this.color,
    required this.bg,
    required this.icon,
    required this.text,
  });

  final Color color;
  final Color bg;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
