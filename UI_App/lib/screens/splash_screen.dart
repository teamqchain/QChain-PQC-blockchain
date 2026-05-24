import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:qwallet_mobileapp/constants/colors.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

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
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: qBgSurface,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        toolbarHeight: 0, // Removed the negative sign here
      ),
      body: SafeArea(
        // 1. We wrap the Column in a SizedBox to force it to full width
        child: SizedBox(
          width: double.infinity,
          child: Column(
            // 2. This guarantees everything inside stays centered horizontally
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // ── Logo area ────────────────────────────────────────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(width: 160, height: 160),
                  ),
                  // Middle ring
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(width: 120, height: 120),
                  ),
                  // Core
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/images/QChain_logo.png',
                      width: 400,
                      fit: BoxFit.contain,
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
                'security redefined',
                style: TextStyle(
                  fontSize: 8,
                  color: qText,
                  letterSpacing: 2,
                  fontFamily: 'formula',
                ),
              ),

              const Spacer(flex: 2),

              // ── Button ───────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ConstrainedBox(
                  // Capping the width so it looks good on wide screens
                  constraints: const BoxConstraints(maxWidth: 350),
                  child: SizedBox(
                    // Stretching the button to fill the constraint
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Get.toNamed(Routes.ONBOARD1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: qPrimary,
                        foregroundColor: qBg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
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
              const Text(
                'Powered by QChain',
                style: TextStyle(color: qDimmed, fontSize: 11),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
