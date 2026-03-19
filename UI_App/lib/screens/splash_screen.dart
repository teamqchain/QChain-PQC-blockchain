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
        systemOverlayStyle: SystemUiOverlayStyle.dark, //<--Here!!!
        toolbarHeight: -0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── Logo area ────────────────────────────────────────────────────
            // TODO: Replace with Image.asset('assets/images/qchain_logo.png')
            // The logo is white on dark — invert the PNG for dark mode
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    width: 160,
                    height: 160,
                    
                  ),
                ),
                // Middle ring
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    width: 120,
                    height: 120,
                    // decoration: BoxDecoration(
                    //   shape: BoxShape.circle,
                    //   border: Border.all(
                    //     color: kTeal.withOpacity(_pulse.value * 0.4),
                    //     width: 2,
                    //   ),
                    // ),
                  ),
                ),
                // Core
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    // gradient: kGradient,
                    // boxShadow: [
                    //   BoxShadow(color: kTeal.withOpacity(0.5), blurRadius: 40),
                    // ],
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

            // const SizedBox(height: 5),/
            const Text(
              'QWallet',
              style: TextStyle(
                fontSize: 36,
                // fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: -1,
                fontFamily: 'formula'
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'SECURITY REDIFINED',
              style: TextStyle(fontSize: 12, color: qText, letterSpacing: 2, fontFamily: 'formula'),
            ),

            const Spacer(flex: 2),

            // ── Button ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: GestureDetector(
                onTap: () => Get.toNamed(Routes.ONBOARD1),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: qPrimary,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      color: qBg,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
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
    );
  }
}
