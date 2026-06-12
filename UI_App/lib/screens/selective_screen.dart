import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/Headers/QPageTitle.dart';
import 'package:qwallet_mobileapp/model/credential_model.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';
import 'package:qwallet_mobileapp/services/app_api_service.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';

enum ShareMode { otp, qr }

class SelectiveShareScreen extends StatefulWidget {
  final CredentialModel doc;
  final ShareMode mode;

  const SelectiveShareScreen({
    super.key,
    required this.doc,
    required this.mode,
  });

  @override
  State<SelectiveShareScreen> createState() => _SelectiveShareScreenState();
}

class _SelectiveShareScreenState extends State<SelectiveShareScreen> {
  bool _isLoading = false;
  late List<Map<String, dynamic>> _fields;

  static const int _expiryDuration = 60; // 5 minutes

  @override
  void initState() {
    super.initState();
    _fields = [
      {
        'key': 'credentialType',
        'label': 'Document Type',
        'crucial': true,
        'hidden': false,
      },
      {
        'key': 'credentialID',
        'label': 'Credential ID',
        'crucial': true,
        'hidden': false,
      },
      {
        'key': 'status',
        'label': 'Verification Status',
        'crucial': true,
        'hidden': false,
      },
      {
        'key': 'issuedBy',
        'label': 'Issuing Authority',
        'crucial': true,
        'hidden': false,
      },
      {
        'key': 'holderEID',
        'label': 'National ID',
        'crucial': true,
        'hidden': false,
      },
      {
        'key': 'holderName',
        'label': 'Issued To',
        'crucial': false,
        'hidden': false,
      },
      {
        'key': 'issuedAt',
        'label': 'Date of Issue',
        'crucial': false,
        'hidden': false,
      },
      if (widget.doc.expiryDate != null)
        {
          'key': 'expiryDate',
          'label': 'Expiry Date',
          'crucial': false,
          'hidden': false,
        },
    ];
  }

  Future<void> _generateAndProceed() async {
    setState(() => _isLoading = true);

    final hiddenKeys = _fields
        .where((f) => f['hidden'] == true && f['crucial'] == false)
        .map((f) => f['key'] as String)
        .toList();

    try {
      if (widget.mode == ShareMode.qr) {
        // ─── QR CODE MODE ──────────────────────────────────────────────
        final result = await ApiService.generatePresentation(
          widget.doc.credentialID,
          hiddenKeys,
          _expiryDuration,
        );

        setState(() => _isLoading = false);

        if (result != null) {
          Get.offNamed(
            Routes.PRESENT,
            arguments: {
              'doc': widget.doc,
              'presentationID': result['presentationID'],
              'expiresAt': result['expiresAt'],
              'hiddenFields': hiddenKeys,
            },
          );
        } else {
          Get.snackbar(
            'Network Error',
            'Failed to generate secure presentation.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
          );
        }
      } else {
        // ─── OTP MODE ──────────────────────────────────────────────────
        final result = await ApiService.generateVerificationOTP(
          widget.doc.credentialID,
          hiddenKeys,
          _expiryDuration,
        );

        setState(() => _isLoading = false);

        if (result != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => _OtpDialog(
              initialOtp: result['otp'],
              expiresAt: result['expiresAt'],
              onRefresh: () async {
                try {
                  return await ApiService.generateVerificationOTP(
                    widget.doc.credentialID,
                    hiddenKeys,
                    _expiryDuration,
                  );
                } catch (_) {
                  return null;
                }
              },
              onDone: () {
                Get.back(); // Close Dialog
                Get.back(); // Go back to details view
              },
            ),
          );
        } else {
          Get.snackbar(
            'Error',
            'Failed to generate OTP.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      // Get.snackbar('Network Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
      Get.snackbar(
        'Network Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: qRed,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isQr = widget.mode == ShareMode.qr;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          // ─── OLD UI HEADER ──────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF000000),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 16,
              24,
              28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    QPageTitle(
                      mainTitle: 'Choose what to share',
                      subTitle: isQr ? "Share via QR" : "Share via OTP",
                      mainFontSize: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF22C55E),
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Toggled-off fields will be masked before '
                          'generating the ${isQr ? 'QR Code' : 'OTP'}. '
                          'Sensitive data stays on your device.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── FIELD TOGGLES ──────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              children: [
                const _ShareSectionLabel('Include in shared document'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEBEBEB)),
                  ),
                  child: Column(
                    children: _fields.asMap().entries.map((e) {
                      final index = e.key;
                      final field = e.value;
                      final isLast = index == _fields.length - 1;

                      final isCrucial = field['crucial'] == true;
                      final isVisible = !(field['hidden'] == true);

                      return Container(
                        decoration: BoxDecoration(
                          border: !isLast
                              ? const Border(
                                  bottom: BorderSide(color: Color(0xFFF0F0F0)),
                                )
                              : null,
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0,
                          ),
                          title: Text(
                            field['label'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isVisible
                                  ? const Color(0xFF111111)
                                  : const Color(0xFFAAAAAA),
                            ),
                          ),
                          subtitle: Text(
                            isCrucial
                                ? 'Required'
                                : (isVisible ? 'Visible' : 'Hidden'),
                            style: TextStyle(
                              fontSize: 11,
                              color: isCrucial
                                  ? const Color(0xFFAAAAAA)
                                  : (isVisible
                                        ? const Color(0xFF22C55E)
                                        : const Color.fromARGB(
                                            255,
                                            216,
                                            22,
                                            22,
                                          )),
                            ),
                          ),
                          value: isVisible,
                          activeThumbColor: isCrucial
                              ? const Color(0xFFBDBDBD)
                              : const Color(0xFF22C55E),
                          activeTrackColor: isCrucial
                              ? const Color(0xFFEEEEEE)
                              : null,
                          inactiveThumbColor: isCrucial
                              ? null
                              : Colors.red.shade900,
                          inactiveTrackColor: Colors.red.shade300,
                          onChanged: isCrucial
                              ? null
                              : (v) => setState(
                                  () => _fields[index]['hidden'] = !v,
                                ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ─── CONFIRM BUTTON ─────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.of(context).padding.bottom + 20,
            ),
            child: GestureDetector(
              onTap: _isLoading ? null : _generateAndProceed,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: _isLoading
                    ? const Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isQr ? Icons.qr_code : Icons.password,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 9),
                          Text(
                            isQr ? 'Generate QR Code' : 'Generate 6-Digit OTP',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareSectionLabel extends StatelessWidget {
  final String text;
  const _ShareSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFFAAAAAA),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ISOLATED OTP DIALOG (With Live Logic & Old UI)
// ─────────────────────────────────────────────────────────────────────────────

class _OtpDialog extends StatefulWidget {
  final String initialOtp;
  final String? expiresAt;
  final Future<Map<String, dynamic>?> Function() onRefresh;
  final VoidCallback onDone;

  const _OtpDialog({
    required this.initialOtp,
    this.expiresAt,
    required this.onRefresh,
    required this.onDone,
  });

  @override
  State<_OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<_OtpDialog> {
  int _totalSeconds = 60; 
  late int _secondsLeft;
  Timer? _timer;
  bool _expired = false;
  bool _isRefreshing = false;
  late String _currentOtp;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.initialOtp;
    if (widget.expiresAt != null) {
      _expiresAt = DateTime.tryParse(widget.expiresAt!);
    }
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _expired = false;
      if (_expiresAt != null) {
        final diff = _expiresAt!.difference(DateTime.now().toUtc()).inSeconds;
        _totalSeconds = diff > 0 ? diff : _SelectiveShareScreenState._expiryDuration;
      }
      _secondsLeft = _totalSeconds;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
        setState(() => _expired = true);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    final result = await widget.onRefresh();
    setState(() => _isRefreshing = false);

    if (result != null) {
      setState(() {
        _currentOtp = result['otp'];
        if (result['expiresAt'] != null) {
          _expiresAt = DateTime.tryParse(result['expiresAt']);
        }
      });
      _startTimer();
    } else {
      Get.snackbar(
        'Error',
        'Failed to refresh OTP. Check your connection.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress => _secondsLeft / _totalSeconds;

  @override
  Widget build(BuildContext context) {
    // Format OTP elegantly (e.g., "123456" -> "123 456")
    String displayOtp = _currentOtp;
    if (displayOtp.length == 6) {
      displayOtp = '${displayOtp.substring(0, 3)} ${displayOtp.substring(3)}';
    }

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'One-Time Password',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Color(0xFF111111),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _expired
                ? 'This code has expired. Please refresh to generate a new secure OTP.'
                : 'Share this 6-digit code with the verifier. It will expire in 5 minutes.',
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // OTP Display Box
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _expired
                  ? const Color(0xFFEEEEEE)
                  : const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _expired
                    ? const Color(0xFFDDDDDD)
                    : const Color(0xFFEBEBEB),
              ),
            ),
            alignment: Alignment.center,
            child: _isRefreshing
                ? const CircularProgressIndicator(color: Colors.black)
                : Text(
                    _expired ? '--- ---' : displayOtp,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: _expired
                          ? const Color(0xFFAAAAAA)
                          : const Color(0xFF111111),
                    ),
                  ),
          ),
          const SizedBox(height: 20),

          _TimerCard(
            timeLabel: _timeLabel,
            progress: _progress,
            expired: _expired,
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: (_expired && !_isRefreshing) ? _handleRefresh : null,
              child: Text(
                'Refresh',
                style: TextStyle(
                  color: _expired
                      ? const Color(0xFF111111)
                      : const Color(0xFFCCCCCC),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: widget.onDone,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimerCard extends StatelessWidget {
  final String timeLabel;
  final double progress;
  final bool expired;

  const _TimerCard({
    required this.timeLabel,
    required this.progress,
    required this.expired,
  });

  @override
  Widget build(BuildContext context) {
    final color = expired
        ? const Color(0xFFEF4444)
        : progress > 0.4
        ? const Color(0xFF22C55E)
        : progress > 0.15
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    expired ? Icons.timer_off_outlined : Icons.timer_outlined,
                    color: color,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    expired ? 'OTP Expired' : 'OTP expires in',
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                expired ? '00:00' : timeLabel,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: expired ? 0 : progress,
              minHeight: 5,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
