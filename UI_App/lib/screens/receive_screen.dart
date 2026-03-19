import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/constants/colors.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';
import 'package:qwallet_mobileapp/widgets/QOutlineBtn.dart';
import 'package:qwallet_mobileapp/widgets/QPrimaryBtn.dart';
import 'package:qwallet_mobileapp/widgets/shared_widgets.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  int _step = 0;

  static const _steps = [
    'Fetching credential...',
    'Verifying blockchain record...',
    'Checking issuer signature...',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: qBgSurface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: const Text(
                      '←',
                      style: TextStyle(color: qSub, fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'New Credential Received',
                    style: TextStyle(color: qText, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Credential preview
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: qCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: qBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: qCardAlt,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: qBorder),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '🎓',
                              style: TextStyle(fontSize: 26),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Bachelor of Computer Science',
                                  style: TextStyle(
                                    color: qText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'University of Sharjah',
                                  style: TextStyle(color: qSub, fontSize: 12),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Issued to: Ali Maqqavi · Jun 2024',
                                  style: TextStyle(color: qMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Verification steps
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: qCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: qBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verifying on blockchain...',
                            style: TextStyle(
                              color: qMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),

                          for (int i = 0; i < _steps.length; i++) ...[
                            Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _step > i
                                        ? qPrimary.withOpacity(0.1)
                                        : qCardAlt,
                                    border: Border.all(
                                      color: _step > i ? qPrimary : qBorder,
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _step > i ? '✓' : '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _step > i ? qPrimary : qMuted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _steps[i],
                                  style: TextStyle(
                                    color: _step > i ? qText : qMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            if (i < _steps.length - 1)
                              const SizedBox(height: 14),
                          ],

                          if (_step >= 3) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: qValidBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: qPrimary.withOpacity(0.2),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  '✓  Credential verified and authentic',
                                  style: TextStyle(
                                    color: qText,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
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

            // ── Actions ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  _step < 3
                      ? QPrimaryBtn(
                          'Simulate Verification Step',
                          onTap: () =>
                              setState(() => _step = (_step + 1).clamp(0, 3)),
                        )
                      : QPrimaryBtn(
                          'Add to Wallet',
                          // TODO: Save to secure local storage
                          // onTap: () => Get.offAllNamed(Routes.HOME),
                        ),
                  const SizedBox(height: 10),
                  const QOutlineBtn('Decline'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
