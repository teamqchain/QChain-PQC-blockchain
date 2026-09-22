import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:qwallet_mobileapp/theme/colors.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';
import 'package:qwallet_mobileapp/controllers/wallet_controller.dart';
import 'package:qwallet_mobileapp/controllers/activity_controller.dart';
import 'package:qwallet_mobileapp/controllers/add_document_controller.dart';
import 'package:qwallet_mobileapp/controllers/manage_subscriptions_controller.dart';

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
                      Container(
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            if (!Get.isRegistered<WalletController>()) {
                              Get.put(WalletController(), permanent: true);
                            }
                            if (!Get.isRegistered<ActivityController>()) {
                              Get.put(ActivityController(), permanent: true);
                            }
                            if (!Get.isRegistered<AddDocumentController>()) {
                              Get.put(
                                AddDocumentController(),
                                permanent: true,
                              );
                            }
                            if (!Get.isRegistered<
                                ManageSubscriptionsController>()) {
                              Get.put(
                                ManageSubscriptionsController(),
                                permanent: true,
                              );
                            }
                            Get.toNamed(Routes.ONBOARD1);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: qPrimary,
                            foregroundColor: qBg,
                            elevation: 0,
                            minimumSize: const Size(0, 56),
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
                      ]
                    ), 
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
