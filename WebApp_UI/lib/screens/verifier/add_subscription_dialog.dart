// widgets/verifier/add_new_subscription_dialog.dart
//
// Add New Subscription — two-step dialog flow:
//   Step 1: Enter Credential ID  →  Subscribe button
//   Step 2: Confirmation dialog  →  Send button
//   After Send: toast "Request sent." at the top of the screen
//
// ── Usage in subscription_page.dart ─────────────────────────────────────────
//   // Replace the onAddNewRequest: () {} stub with:
//   onAddNewRequest: () => showDialog(
//     context: context,
//     builder: (_) => AddNewSubscriptionDialog(
//       overlayContext: context, // page context for the toast overlay
//     ),
//   ),

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/app_button.dart';

// ─── CREDENTIAL LOOKUP ───────────────────────────────────────────────────────
//
// In production this would be a network call.
// Returns ({credentialName, holderName}) for a known Credential ID,
// or null when the ID is not found.

({String credentialName, String holderName})? _lookupCredential(String id) {
  final normalised = id.trim().toUpperCase();
  try {
    final record = IssuingMockData.credentials.firstWhere(
      (c) => c.id.toUpperCase() == normalised,
    );
    return (credentialName: record.credentialType, holderName: record.holderName);
  } on StateError {
    return null;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STEP 1 — ADD NEW SUBSCRIPTION DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class AddNewSubscriptionDialog extends StatefulWidget {
  /// The BuildContext of the page that opened this dialog.
  /// Used to insert the toast into the correct Overlay after both
  /// dialogs have been dismissed.
  final BuildContext overlayContext;

  const AddNewSubscriptionDialog({super.key, required this.overlayContext});

  @override
  State<AddNewSubscriptionDialog> createState() =>
      _AddNewSubscriptionDialogState();
}

class _AddNewSubscriptionDialogState extends State<AddNewSubscriptionDialog> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  // Becomes non-null once the user has submitted an ID that isn't found.
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // Auto-focus the text field when the dialog opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _onSubscribe() {
    final id = _ctrl.text.trim();

    if (id.isEmpty) {
      setState(() => _errorText = 'Please enter a Credential ID.');
      return;
    }

    final match = _lookupCredential(id);

    if (match == null) {
      setState(
        () => _errorText =
            'Credential "$id" was not found. Check the ID and try again.',
      );
      return;
    }

    setState(() => _errorText = null);

    // Push the confirmation dialog on top of this one.
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        credentialName: match.credentialName,
        holderName: match.holderName,
        overlayContext: widget.overlayContext,
        onSent: () {
          // Dismiss this (Step 1) dialog after both dialogs are gone.
          if (mounted) Navigator.pop(context);
        },
      ),
    );
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
            // ── Header ───────────────────────────────────────────────────
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

            // ── Body — Credential ID field ────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Field label
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

                  // Text field
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
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'e.g. QC-2025-009182',
                        hintStyle: AppTextStyles.bodyTiny.copyWith(
                          fontSize: 12,
                          color: AppColors.textDim,
                        ),
                      ),
                      onChanged: (_) {
                        // Clear the error as the user types.
                        if (_errorText != null) {
                          setState(() => _errorText = null);
                        }
                      },
                      onSubmitted: (_) => _onSubscribe(),
                    ),
                  ),

                  // Error text
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
                                  Icons.error_outline_rounded,
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

            // ── Buttons ───────────────────────────────────────────────────
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
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      icon: Icons.notifications_active_outlined,
                      label: 'Subscribe',
                      backgroundColor: AppColors.verifyingAccent,
                      hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
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

// ═════════════════════════════════════════════════════════════════════════════
//  STEP 2 — CONFIRMATION DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _ConfirmDialog extends StatelessWidget {
  final String credentialName;
  final String holderName;
  final BuildContext overlayContext;
  final VoidCallback onSent; // called after this dialog is popped

  const _ConfirmDialog({
    required this.credentialName,
    required this.holderName,
    required this.overlayContext,
    required this.onSent,
  });

  void _onSend(BuildContext context) {
    // Dismiss this confirmation dialog.
    Navigator.pop(context);
    // Dismiss the Step-1 dialog.
    onSent();
    // Show the toast using the page-level overlay.
    _showToast(overlayContext);
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
            // ── Header ───────────────────────────────────────────────────
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

            // ── Body ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Confirmation message with resolved names
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
                          text: credentialName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.verifyingLight,
                          ),
                        ),
                        const TextSpan(text: ' of '),
                        TextSpan(
                          text: holderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const TextSpan(text: ' will be sent.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info box
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
                              color: AppColors.textDim,
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

            // ── Buttons ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  AppButton(
                    label: 'Cancel',
                    showBorder: true,
                    borderColor: AppColors.border,
                    hoverColor: AppColors.surfaceHover,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      icon: Icons.send_rounded,
                      label: 'Send',
                      backgroundColor: AppColors.verifyingAccent,
                      hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
                      onTap: () => _onSend(context),
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

// ═════════════════════════════════════════════════════════════════════════════
//  TOAST
// ═════════════════════════════════════════════════════════════════════════════

void _showToast(BuildContext context) {
  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (_) => _RequestSentToast(
      onDismiss: () {
        entry?.remove();
        entry = null;
      },
    ),
  );
  Overlay.of(context).insert(entry!);
}

class _RequestSentToast extends StatefulWidget {
  final VoidCallback onDismiss;
  const _RequestSentToast({required this.onDismiss});

  @override
  State<_RequestSentToast> createState() => _RequestSentToastState();
}

class _RequestSentToastState extends State<_RequestSentToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        _ctrl.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  Widget build(BuildContext context) => Positioned(
    top: 24,
    left: 0,
    right: 0,
    child: Center(
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2A1A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.verifyingAccent.withOpacity(0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: AppColors.verifyingAccent,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Request sent.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.verifyingLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
