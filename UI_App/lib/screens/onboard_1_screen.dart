import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';

class Onboard1Screen extends StatelessWidget {
  const Onboard1Screen({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    alignment: Alignment.center,
                    child: const Text('⛓', style: TextStyle(fontSize: 16)),
                  ),
                  GestureDetector(
                    onTap: () => Get.offAllNamed(Routes.SHELL),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF333333)),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Emoji card
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFF2A2A2A),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.04),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text('📱', style: TextStyle(fontSize: 50)),
                ),
              ),

              const SizedBox(height: 48),

              const Text(
                'Own your\ncredentials',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -1.5,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Store your degree, passport, and certificates in one secure place. Only you control them.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),

              const Spacer(),

              // ── Dots centered ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _Dot(active: true),
                  SizedBox(width: 6),
                  _Dot(active: false),
                  SizedBox(width: 6),
                  _Dot(active: false),
                ],
              ),

              const SizedBox(height: 24),

              _OnboardBtn(
                label: 'Next',
                onTap: () => Get.toNamed(Routes.ONBOARD2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: active ? 20 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? Colors.white : const Color(0xFF333333),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _OnboardBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OnboardBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF000000),
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }
}
