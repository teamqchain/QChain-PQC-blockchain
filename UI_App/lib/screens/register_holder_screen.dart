import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/Headers/QPageTitle.dart';
import 'package:qwallet_mobileapp/services/app_api_service.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';

/// Dev-only: register a new holder via POST {base}/registerHolder.
/// Pushed from Dev Config. On success pops with a result map so Dev Config
/// can select the new EID without a full list reload race.
///
/// Args (Get.arguments): optional `baseUrl` string — pending URL from Dev
/// Config before Save (exact paste, D3).
class RegisterHolderScreen extends StatefulWidget {
  const RegisterHolderScreen({super.key});

  @override
  State<RegisterHolderScreen> createState() => _RegisterHolderScreenState();
}

class _RegisterHolderScreenState extends State<RegisterHolderScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _eidCtrl = TextEditingController();
  final _holderNumCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _submitting = false;
  String? _error;

  String? get _baseOverride {
    final args = Get.arguments;
    if (args is Map && args['baseUrl'] is String) {
      final v = (args['baseUrl'] as String).trim();
      return v.isEmpty ? null : v;
    }
    if (args is String && args.trim().isNotEmpty) return args.trim();
    return null;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _eidCtrl.dispose();
    _holderNumCtrl.dispose();
    super.dispose();
  }

  /// Digits only from the EID field (ignores dashes the formatter inserts).
  String get _eidDigits => _eidCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

  /// 784-1998-1234567-3
  String get _formattedEid {
    final d = _eidDigits;
    if (d.length != 15) return _eidCtrl.text.trim();
    return '${d.substring(0, 3)}-${d.substring(3, 7)}-'
        '${d.substring(7, 14)}-${d.substring(14)}';
  }

  /// User types 4 digits → H-0003
  String get _holderID {
    final n = _holderNumCtrl.text.trim();
    return 'H-$n';
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final result = await ApiService.registerHolder(
        holderID: _holderID,
        emiratesID: _formattedEid,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        baseUrlOverride: _baseOverride,
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      // Pop result for Dev Config to select + refresh.
      Get.back(
        result: {
          'holderID': (result['holderID'] ?? _holderID).toString(),
          'emiratesID': _formattedEid,
          'fullName':
              '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim(),
          'firstName': _firstNameCtrl.text.trim(),
          'lastName': _lastNameCtrl.text.trim(),
          'isWalletActivated': false,
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is ConnectionException ? e.message : 'Registration failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: qBgSurface,
      body: Column(
        children: [
          _buildHero(topPad),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _sectionLabel('IDENTITY'),
                  const SizedBox(height: 10),
                  _card(
                    children: [
                      _label('First name'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: _firstNameCtrl,
                        hint: 'Fatima',
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      _label('Last name'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: _lastNameCtrl,
                        hint: 'Al Zaabi',
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _sectionLabel('IDS'),
                  const SizedBox(height: 10),
                  _card(
                    children: [
                      _label('Emirates ID'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: _eidCtrl,
                        hint: '784-1998-1234567-3',
                        keyboardType: TextInputType.number,
                        inputFormatters: [_EmiratesIdFormatter()],
                        validator: (v) {
                          if (_eidDigits.length != 15) {
                            return 'Must be 3-4-7-1 digits (15 total)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _label('Holder ID number'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: _holderNumCtrl,
                        hint: '0003',
                        keyboardType: TextInputType.number,
                        prefixText: 'H-  ',
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter 4 digits';
                          }
                          if (v.trim().length != 4) {
                            return 'Exactly 4 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sent as H-####  ·  EID as NNN-NNNN-NNNNNNN-N',
                        style: TextStyle(color: qSub, fontSize: 11),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: qRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: qPrimary,
                        foregroundColor: qBg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create holder',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Calls POST /registerHolder on the pending backend URL.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: qDimmed, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(double topPad) {
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
      child: Row(
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
            child: QPageTitle(
              mainTitle: 'Register Holder',
              subTitle: 'Dev only · POST /registerHolder',
              mainFontSize: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: qPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(color: qSub, fontSize: 12),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? prefixText,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      autocorrect: false,
      style: const TextStyle(
        color: qPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: qSub, fontSize: 13),
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          color: qPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: qBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: qBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: qPrimary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: qRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: qRed),
        ),
      ),
    );
  }
}

/// Formats digits as NNN-NNNN-NNNNNNN-N while typing.
class _EmiratesIdFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final clipped = digits.length > 15 ? digits.substring(0, 15) : digits;

    final buf = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i == 3 || i == 7 || i == 14) buf.write('-');
      buf.write(clipped[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
