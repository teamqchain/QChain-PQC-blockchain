import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/toast.dart';
import 'package:qportal_webapp/services/issuer_api.dart';
import 'package:qportal_webapp/services/subscription_api.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';

class AddNewSubscriptionDialog extends StatefulWidget {
  final BuildContext overlayContext;
  final VoidCallback? onSubscriptionRequested;

  const AddNewSubscriptionDialog({
    super.key,
    required this.overlayContext,
    this.onSubscriptionRequested,
  });

  @override
  State<AddNewSubscriptionDialog> createState() =>
      _AddNewSubscriptionDialogState();
}

class _AddNewSubscriptionDialogState extends State<AddNewSubscriptionDialog> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  String? _errorText;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  Future<void> _onSubscribe() async {
    final id = _ctrl.text.trim();

    if (id.isEmpty) {
      setState(() => _errorText = 'Please enter a Credential ID.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final cred = await IssuerApi.getCredentialDetail(id);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (cred == null) {
        setState(() {
          _errorText =
              'Credential "$id" was not found. Check the ID and try again.';
        });
        return;
      }

      showDialog(
        context: context,
        builder: (_) => _ConfirmDialog(
          credentialID: cred.id,
          credentialName: cred.credentialType,
          holderName: cred.holderName,
          overlayContext: widget.overlayContext,
          onSent: () {
            widget.onSubscriptionRequested?.call();
            if (mounted) Navigator.pop(context);
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText =
            'Connection Error: Unable to reach the server. Please check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 40,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.verifyingAccent.withOpacity(0.14),
                      border: Border.all(
                        color: AppColors.verifyingAccent.withOpacity(0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: AppColors.verifyingAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add New Subscription',
                    style: AppTextStyles.navLabelActive.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CREDENTIAL ID',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: AppColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHover,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: _errorText != null
                            ? AppColors.revoked.withOpacity(0.6)
                            : _focus.hasFocus
                            ? AppColors.verifyingAccent
                            : AppColors.border,
                        width: _focus.hasFocus ? 1.5 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      enabled: !_isLoading,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'e.g. CRED-0001',
                        hintStyle: AppTextStyles.bodyTiny.copyWith(
                          fontSize: 12,
                          color: AppColors.textDim,
                        ),
                      ),
                      onChanged: (_) {
                        if (_errorText != null) {
                          setState(() => _errorText = null);
                        }
                      },
                      onSubmitted: (_) => _onSubscribe(),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 160),
                    alignment: Alignment.topLeft,
                    child: _errorText != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  // Change icon depending on if it's a network error or missing credential
                                  _errorText!.startsWith('Connection Error')
                                      ? Icons.wifi_off_rounded
                                      : Icons.error_outline_rounded,
                                  size: 13,
                                  color: AppColors.revoked.withOpacity(0.8),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _errorText!,
                                    style: AppTextStyles.bodyTiny.copyWith(
                                      fontSize: 11,
                                      color: AppColors.revoked.withOpacity(
                                        0.85,
                                      ),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancel',
                      showBorder: true,
                      borderColor: AppColors.border,
                      hoverColor: AppColors.surfaceHover,
                      enabled: !_isLoading,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      icon: _isLoading
                          ? null
                          : Icons.notifications_active_outlined,
                      label: _isLoading ? 'Searching...' : 'Subscribe',
                      backgroundColor: AppColors.verifyingAccent,
                      hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
                      enabled: !_isLoading,
                      onTap: _onSubscribe,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }
}

class _ConfirmDialog extends StatefulWidget {
  final String credentialID;
  final String credentialName;
  final String holderName;
  final BuildContext overlayContext;
  final VoidCallback onSent;

  const _ConfirmDialog({
    required this.credentialID,
    required this.credentialName,
    required this.holderName,
    required this.overlayContext,
    required this.onSent,
  });

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _isSending = false;
  String? _errorText;

  Future<void> _onSend() async {
    setState(() {
      _isSending = true;
      _errorText = null;
    });

    try {
      final success = await SubscriptionApi.requestSubscription(widget.credentialID);
      setState(() => _isSending = false);

      if (success) {
        if (mounted) Navigator.pop(context);
        widget.onSent();
        _showToast(widget.overlayContext);
      } else {
        setState(
          () => _errorText = 'Error 400: Unable to send request. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorText = 'Connection Error: Unable to reach the server.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 40,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.verifyingAccent.withOpacity(0.14),
                      border: Border.all(
                        color: AppColors.verifyingAccent.withOpacity(0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      size: 16,
                      color: AppColors.verifyingAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Confirm',
                    style: AppTextStyles.navLabelActive.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.7,
                      ),
                      children: [
                        const TextSpan(text: 'Subscription request for '),
                        TextSpan(
                          text: widget.credentialName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.verifyingLight,
                            letterSpacing: 0.3
                          ),
                        ),
                        const TextSpan(text: ' of '),
                        TextSpan(
                          text: widget.holderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                            letterSpacing: 0.3
                          ),
                        ),
                        const TextSpan(text: ' will be sent.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.verifyingAccent.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: AppColors.verifyingAccent.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: AppColors.verifyingAccent.withOpacity(0.8),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'The holder will receive a request to accept the subscription. '
                            'The subscription becomes Active once the holder accepts.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _errorText!,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.revoked.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  AppButton(
                    label: 'Cancel',
                    showBorder: true,
                    borderColor: AppColors.border,
                    hoverColor: AppColors.surfaceHover,
                    enabled: !_isSending,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      icon: _isSending ? null : Icons.send_rounded,
                      label: _isSending ? 'Sending...' : 'Send',
                      backgroundColor: AppColors.verifyingAccent,
                      hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
                      enabled: !_isSending,
                      onTap: _onSend,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showToast(BuildContext context) {
  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (_) => Toast(
      message: "Request Sent",
      toastIcons: Icons.check_circle_outline_rounded,
      onDone: () {
        entry?.remove();
        entry = null;
      },
      bgColor: AppColors.valid,
      iconColor: AppColors.text,
    ),
  );
  Overlay.of(context).insert(entry!);
}
