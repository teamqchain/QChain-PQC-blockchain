import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/Headers/QPageTitle.dart';
import 'package:qwallet_mobileapp/model/credential_model.dart';
import 'package:qwallet_mobileapp/screens/selective_screen.dart';
import 'package:qwallet_mobileapp/services/wallet_controller.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DOCUMENT DETAIL SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DocWrapper {
  final dynamic raw;
  final bool isCred;

  DocWrapper(this.raw) : isCred = raw is CredentialModel;

  String get credentialType {
    if (isCred) return raw.credentialType;
    try {
      return raw.title ?? 'Document';
    } catch (_) {
      return 'Document';
    }
  }

  String get credentialID {
    if (isCred) return raw.credentialID;
    try {
      return raw.id ?? 'DOC-UNKNOWN';
    } catch (_) {
      return 'DOC-UNKNOWN';
    }
  }

  String get holderName {
    if (isCred) return raw.holderName;
    return 'Holder';
  }

  String get holderEID {
    if (isCred) return raw.holderEID;
    return 'Unknown';
  }

  String get issuedBy {
    if (isCred) return raw.issuedBy;
    try {
      return raw.subtitle ?? 'Unknown Issuer';
    } catch (_) {
      return 'Unknown Issuer';
    }
  }

  String get formattedIssueDate {
    if (isCred) return raw.formattedIssueDate;
    return 'Recent';
  }

  String get formattedExpiryDate {
    if (isCred) return raw.formattedExpiryDate;
    return 'N/A';
  }

  DateTime? get expiryDate {
    if (isCred) {
      final exp = raw.expiryDate;
      if (exp is DateTime) return exp;
      if (exp is String) {
        try {
          return DateTime.parse(exp);
        } catch (_) {
          return null;
        }
      }
      return null;
    }
    return null;
  }

  String get status {
    if (isCred) return raw.status;
    return 'active';
  }

  String get displayStatus {
    if (isCred) return raw.displayStatus;
    return 'Active';
  }

  Color get cardColor {
    if (isCred) return raw.cardColor;
    try {
      return raw.color ?? const Color(0xFF1D4ED8);
    } catch (_) {
      return const Color(0xFF1D4ED8);
    }
  }

  IconData get icon {
    if (isCred) return raw.icon;
    try {
      return raw.icon ?? Icons.article;
    } catch (_) {
      return Icons.article;
    }
  }

  Map<String, dynamic> get attributes {
    if (isCred) {
      try {
        return raw.attributes ?? {};
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  String? get txHash {
    if (isCred) {
      try {
        return raw.txHash;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? get cid {
    if (isCred) {
      try {
        return raw.cid;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({super.key});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late final DocWrapper doc;

  @override
  void initState() {
    super.initState();
    doc = DocWrapper(Get.arguments);
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
                  _ValidBar(doc: doc),
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
  final DocWrapper doc;
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
                // child: Column(
                //   crossAxisAlignment: CrossAxisAlignment.start,
                //   children: [
                //     const Text(
                //       'Document',
                //       style: TextStyle(
                //         color: Color(0xFF888888),
                //         fontSize: 13,
                //         letterSpacing: 0.2,
                //       ),
                //     ),
                //     const SizedBox(height: 2),
                //     Text(
                //       doc.credentialType,
                //       style: const TextStyle(
                //         color: Colors.white,
                //         fontSize: 20,
                //         fontWeight: FontWeight.w800,
                //         letterSpacing: -0.4,
                //       ),
                //       overflow: TextOverflow.ellipsis,
                //     ),
                //   ],
                // ),
                child: QPageTitle(
                  mainTitle: doc.credentialType,
                  subTitle: 'Document',
                  mainFontSize: 22,
                ),
              ),
              // Container(                                         //Catergory Icon on top right of hero box
              //   padding: const EdgeInsets.symmetric(
              //     horizontal: 10,
              //     vertical: 5,
              //   ),
              //   decoration: BoxDecoration(
              //     color: const Color(0xFF1A1A1A),
              //     borderRadius: BorderRadius.circular(10),
              //     border: Border.all(color: const Color(0xFF333333)),
              //   ),
              //   child: Icon(doc.icon, size: 18, color: Colors.white),
              // ),
            ],
          ),
          const SizedBox(height: 20),
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
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: CustomPaint(painter: _GridPainter()),
                  ),
                ),
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
                Positioned(
                  right: -15,
                  bottom: -15,
                  child: Opacity(
                    opacity: 0.07,
                    child: Icon(doc.icon, size: 120, color: Colors.white),
                  ),
                ),
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
                                doc.issuedBy,
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
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        doc.credentialType.toUpperCase(),
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
                          Text(
                            doc.holderName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'ISSUED ${doc.formattedIssueDate.toUpperCase()}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'EXPIRES ${doc.formattedExpiryDate.toUpperCase()}',
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
  final DocWrapper doc;
  const _ValidBar({required this.doc});

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
    final isActive = widget.doc.status.toLowerCase() == 'active';
    final Color statusColor = isActive ? const Color(0xFF22C55E) : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          FadeTransition(
            opacity: _fade,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                boxShadow: [
                  BoxShadow(color: statusColor, blurRadius: 6, spreadRadius: 1),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            widget.doc.displayStatus.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
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
  final DocWrapper doc;
  const _DetailsSection({required this.doc});

  @override
  Widget build(BuildContext context) {
    final fields = <_DetailRow>[
      _DetailRow(label: 'Credential ID', value: doc.credentialID),
      _DetailRow(label: 'Credential Type', value: doc.credentialType),
      _DetailRow(label: 'Issued To', value: doc.holderName),
      _DetailRow(label: 'National ID', value: doc.holderEID),
      _DetailRow(label: 'Issuing Authority', value: doc.issuedBy),
      const _DetailRow(
        label: 'Country of Issue',
        value: 'United Arab Emirates',
      ),
      _DetailRow(label: 'Date of Issue', value: doc.formattedIssueDate),
      _DetailRow(
        label: 'Expiry Date',
        value: doc.formattedExpiryDate,
        highlight: doc.expiryDate != null,
      ),
      _DetailRow(
        label: 'Current Status',
        value: doc.displayStatus,
        statusColor: doc.status.toLowerCase() == 'active'
            ? const Color(0xFF22C55E)
            : Colors.red,
      ),
    ];

    doc.attributes.forEach((key, value) {
      final formattedKey = key.replaceAll(RegExp(r'(?<!^)(?=[A-Z])'), ' ');
      final finalKey =
          formattedKey[0].toUpperCase() + formattedKey.substring(1);

      fields.insert(
        fields.length - 1,
        _DetailRow(label: finalKey, value: value.toString()),
      );
    });

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
// BOTTOM ACTIONS (PRESENT & OTP)
// ─────────────────────────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final DocWrapper doc;
  const _BottomActions({required this.doc});

  void _handleGenerateOTP(BuildContext context) async {
    final WalletController controller = Get.find<WalletController>();

    Get.dialog(
      const Center(child: CircularProgressIndicator(color: Colors.white)),
      barrierDismissible: false,
    );

    try {
      final result = await controller.requestOTP(doc.credentialID);

      Get.back(); // Close loading dialog

      if (result != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _OtpDialog(
            initialOtp: result['otp'],
            expiresAt: result['expiresAt'],
            onRefresh: () async {
               try {
                 final res = await controller.requestOTP(doc.credentialID);
                 return res != null ? {'otp': res['otp'], 'expiresAt': res['expiresAt']} : null;
               } catch (_) {
                 return null;
               }
            },
            onDone: () {
              Get.back(); // Close the dialog only
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
    } catch (e) {
      Get.back(); // Close loading dialog
      Get.snackbar(
        'Network Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // if (doc.status.toLowerCase() != 'active') {
    //   return const SizedBox.shrink(); // Hide if revoked/suspended/expired
    // }

    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            icon: Icons.qr_code_scanner,
            label: 'Present',
            bgColor: Colors.white,
            fgColor: const Color(0xFF111111),
            border: const Color(0xFFEBEBEB),
            // onTap: () {
            //   Get.toNamed('/present', arguments: doc.raw);
            // },
            onTap: () {
              Get.to(
                () => SelectiveShareScreen(doc: doc.raw, mode: ShareMode.qr),
              );
              // _close();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionBtn(
            icon: Icons.pin_outlined,
            label: 'Generate OTP',
            bgColor: const Color(0xFF111111),
            fgColor: Colors.white,
            // onTap: () => _handleGenerateOTP(context),
            onTap: () {
              // Navigator.of(context).push(
              //   MaterialPageRoute(
              //     builder: (_) =>
              //         SelectiveShareScreen(doc: doc.raw, mode: ShareMode.otp),
              //   ),
              // );
              Get.to(
                () => SelectiveShareScreen(doc: doc.raw, mode: ShareMode.otp),
              );
            },
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
  int _totalSeconds = 300;
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
        _totalSeconds = diff > 0 ? diff : 300;
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
