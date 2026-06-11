// screens/issuer/crypto_settings_page.dart
//
// Crypto Settings — manage PQC algorithm and view the organisation public key.
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   import 'package:qportal_webapp/screens/issuer/crypto_settings_page.dart';
//
//   // Add route constant:
//   static const issuerCrypto = '/issue/settings/crypto';
//
//   // In IssuerSettingsPage:
//   IssuerSettingsPage(
//     onCryptoSettings: () => _handleNavigate(RouteName.issuerCrypto),
//     ...
//   );
//
//   // In _buildPage():
//   case RouteName.issuerCrypto:
//     return CryptoSettingsPage(
//       onBack: () => _handleNavigate(RouteName.issuingSettings),
//     );

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';

// ─── MOCK DATA ────────────────────────────────────────────────────────────────

enum _Algorithm { dilithium, falcon }

extension _AlgorithmX on _Algorithm {
  String get label {
    switch (this) {
      case _Algorithm.dilithium:
        return 'Dilithium';
      case _Algorithm.falcon:
        return 'Falcon';
    }
  }
}

const _kPublicKey =
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA3pQF2v8zK1mXq9N7tLpY'
    'uV6cRd4wJhT8oXnBfE2sKmA9gYvHqPzLc5Rt0WjUiDxMeN3bVlF7OkTsZ2aQpCX'
    'nRyUj6mBwDh1eK4vLs8PtI3oGfXVqZA5dMuN0hWc9bJsYpRKvEzF2lXiTqMnOaP'
    'uB7CwDk6eH3mJvRtL1yQsZ5nXiToMaFpBcUeWqKd4jNvOhRs2XbL9YgZpFcMuKt'
    'vD8eA3nJsYpRKv1zF2lXiTqMnOaPuB7CwDk6eH3mJvRtL1yQsZ5nXiTqMaFpBcU'
    'eWqKd4jNvOhRs2XbL9YgZpFcMuKtvD8eA3nJsYpRKv1zF2lXiTqMnOaPuB7CwDk'
    '6eH3mJvRtL1yQsZ5nXiTqMaFpBcUeWqKd4jNvOhRs2XbL9YgZpFcMuKtvD8eA3n'
    'JsYpRKv1zF2lXiTqMnOaPuB7CwDk6eH3mJvRtL1yQsZ5AQIDAQAB';

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class CryptoSettingsPage extends StatefulWidget {
  final VoidCallback onBack;

  const CryptoSettingsPage({super.key, required this.onBack});

  @override
  State<CryptoSettingsPage> createState() => _CryptoSettingsPageState();
}

class _CryptoSettingsPageState extends State<CryptoSettingsPage> {
  _Algorithm _current = _Algorithm.dilithium;
  _Algorithm _selected = _Algorithm.dilithium;
  bool _changing = false;
  bool _copied = false;

  // ── copy ──────────────────────────────────────────────────────────────────

  Future<void> _copyKey() async {
    await Clipboard.setData(const ClipboardData(text: _kPublicKey));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  // ── change / save ─────────────────────────────────────────────────────────

  void _startChange() => setState(() {
    _selected = _current;
    _changing = true;
  });

  void _requestSave() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SaveDialog(
        onConfirm: () => setState(() {
          _current = _selected;
          _changing = false;
        }),
        onCancel: () => setState(() => _changing = false),
      ),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title
          Text(
            'Crypto Settings',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // Container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.hardEdge,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Current Algorithm ────────────────────────────────
                    _SectionLabel('Current Algorithm'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _AlgorithmDropdown(
                            value: _selected,
                            enabled: _changing,
                            onChanged: (v) {
                              if (v != null) setState(() => _selected = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        _changing
                            ? AppButton(
                                label: 'Save',
                                backgroundColor: AppColors.verifyingAccent,
                                hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
                                icon: Icons.save_outlined,
                                onTap: _requestSave,
                              )
                            : AppButton(
                                label: 'Change',
                                backgroundColor: AppColors.adminAccent,
                                hoverColor: AppColors.adminAccent.withOpacity(0.82),
                                icon: Icons.swap_horiz_rounded,
                                onTap: _startChange,
                              ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ── Organisation Public Key ───────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: _SectionLabel('Organisation Public Key'),
                        ),
                        _CopyBtn(copied: _copied, onTap: _copyKey),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _PublicKeyField(publicKey: _kPublicKey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Back button
          Row(
            children: [
              AppButton(
                label: 'Back',
                icon: Icons.arrow_back_rounded,
                onTap: widget.onBack,
                showBorder: true,
                borderColor: AppColors.border,
                hoverColor: AppColors.surfaceHover,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ALGORITHM DROPDOWN
// ═════════════════════════════════════════════════════════════════════════════

class _AlgorithmDropdown extends StatelessWidget {
  final _Algorithm value;
  final bool enabled;
  final void Function(_Algorithm?) onChanged;

  const _AlgorithmDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? AppColors.surfaceHover : AppColors.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: enabled
              ? AppColors.adminAccent.withOpacity(0.55)
              : AppColors.border.withOpacity(0.5),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_Algorithm>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E1E1E),
          iconEnabledColor: AppColors.textDim,
          iconDisabledColor: AppColors.textDim.withOpacity(0.4),
          style: TextStyle(
            fontSize: 13,
            color: enabled ? AppColors.text : AppColors.textMuted,
          ),
          items: enabled
              ? _Algorithm.values
                    .map(
                      (a) => DropdownMenuItem(value: a, child: Text(a.label)),
                    )
                    .toList()
              : [DropdownMenuItem(value: value, child: Text(value.label))],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PUBLIC KEY FIELD
// ═════════════════════════════════════════════════════════════════════════════

class _PublicKeyField extends StatelessWidget {
  final String publicKey;
  const _PublicKeyField({required this.publicKey});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: SelectableText(
        publicKey,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.adminLight,
          height: 1.7,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  COPY BUTTON
// ═════════════════════════════════════════════════════════════════════════════

class _CopyBtn extends StatefulWidget {
  final bool copied;
  final VoidCallback onTap;
  const _CopyBtn({required this.copied, required this.onTap});

  @override
  State<_CopyBtn> createState() => _CopyBtnState();
}

class _CopyBtnState extends State<_CopyBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final Color c = widget.copied
        ? AppColors.verifyingAccent
        : AppColors.adminAccent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _h ? c.withOpacity(0.14) : c.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.copied ? Icons.check_rounded : Icons.copy_outlined,
                size: 13,
                color: c,
              ),
              const SizedBox(width: 6),
              Text(
                widget.copied ? 'Copied' : 'Copy',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SAVE CONFIRMATION DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _SaveDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  const _SaveDialog({required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 48,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.suspended.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: AppColors.suspended,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    'Change Cryptographic Algorithm',
                    style: AppTextStyles.navLabelActive.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Message
            Text(
              'Changing the cryptographic algorithm will affect future credential issuance. '
              'Previously issued credentials will remain valid and unaffected.',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'Cancel',
                  onTap: () {
                    Navigator.pop(context);
                    onCancel();
                  },
                  backgroundColor: Colors.red,
                  showBorder: true,
                  borderColor: Colors.redAccent,
                  hoverColor: AppColors.surfaceHover,
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Confirm Save',
                  backgroundColor: AppColors.verifyingAccent,
                  hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
                  onTap: () {
                    Navigator.pop(context);
                    onConfirm();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SECTION LABEL ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTextStyles.bodyTiny.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: AppColors.textMuted,
    ),
  );
}
