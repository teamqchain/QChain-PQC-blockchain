import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/label.dart';
import 'package:qportal_webapp/models/ISSUER/credentials_model.dart';
import 'package:qportal_webapp/screens/issuer/suspend_revoke_page.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/utils/currentUser.dart';
// ═════════════════════════════════════════════════════════════════════════════
//  REVOKE DIALOG  (3-step: details+reason → password → confirmation)
// ═════════════════════════════════════════════════════════════════════════════



const _kRevokeReasons = <String>[
  'Academic misconduct',
  'Disciplinary action',
  'Credential error — reissue required',
  'Holder request',
  'Fraudulent information provided',
  'Duplicate credential',
  'Other',
];

class RevokeDialog extends StatefulWidget {
  final List<CredentialRecord> credentials;
  final VoidCallback onConfirmed;

  const RevokeDialog({required this.credentials, required this.onConfirmed});

  @override
  State<RevokeDialog> createState() => _RevokeDialogState();
}

class _RevokeDialogState extends State<RevokeDialog>
    with SingleTickerProviderStateMixin {
  int _step = 1;

  // Step 1
  String? _reason;
  final _notesCtrl = TextEditingController();
  bool _acked = false;

  // Step 2
  final _pwCtrl = TextEditingController();
  bool _pwErr = false;

  bool get _step1Ready => _reason != null && _acked;

  void _toStep2() => setState(() => _step = 2);

  void _submitPw() {
    if (_pwCtrl.text.trim().isEmpty) {
      setState(() => _pwErr = true);
      return;
    }
    widget.onConfirmed();
    setState(() {
      _pwErr = false;
      _step = 3;
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DialogFrame(
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: switch (_step) {
          1 => _Step1Revoke(
            credentials: widget.credentials,
            reason: _reason,
            notesCtrl: _notesCtrl,
            acked: _acked,
            reasons: _kRevokeReasons,
            accentColor: AppColors.revoked,
            proceedLabel: 'Revoke',
            onReasonChanged: (v) => setState(() => _reason = v),
            onAckedChanged: (v) => setState(() => _acked = v),
            canProceed: _step1Ready,
            onCancel: () => Navigator.pop(context),
            onProceed: _toStep2,
          ),
          2 => Step2Password(
            accentColor: AppColors.revoked,
            proceedLabel: 'Revoke',
            pwCtrl: _pwCtrl,
            pwErr: _pwErr,
            onBack: () => setState(() {
              _step = 1;
              _pwErr = false;
            }),
            onSubmit: _submitPw,
          ),
          _ => Step3Done(
            credentials: widget.credentials,
            performedBy: kCurrentUser,
            actionPast: 'revoked',
            accentColor: AppColors.revoked,
            onReturn: () => Navigator.pop(context),
          ),
        },
      ),
    ),
  );
}

// ─── STEP 1 — REVOKE ──────────────────────────────────────────────────────────

class _Step1Revoke extends StatelessWidget {
  final List<CredentialRecord> credentials;
  final String? reason;
  final TextEditingController notesCtrl;
  final bool acked;
  final List<String> reasons;
  final Color accentColor;
  final String proceedLabel;
  final void Function(String?) onReasonChanged;
  final void Function(bool) onAckedChanged;
  final bool canProceed;
  final VoidCallback onCancel;
  final VoidCallback onProceed;

  const _Step1Revoke({
    required this.credentials,
    required this.reason,
    required this.notesCtrl,
    required this.acked,
    required this.reasons,
    required this.accentColor,
    required this.proceedLabel,
    required this.onReasonChanged,
    required this.onAckedChanged,
    required this.canProceed,
    required this.onCancel,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DlgHeader(
        icon: Icons.block_rounded,
        title: credentials.length == 1
            ? '$proceedLabel Credential'
            : '$proceedLabel ${credentials.length} Credentials',
        subtitle: 'Review the summary and provide a reason before proceeding.',
        accentColor: accentColor,
      ),
      const SizedBox(height: 20),

      CredSummary(credentials: credentials),
      const SizedBox(height: 20),

      Label(text: 'Reason for $proceedLabel', required: true),
      const SizedBox(height: 6),
      Dropdown(
        value: reason,
        items: reasons,
        hint: 'Select a reason…',
        accentColor: accentColor,
        onChanged: onReasonChanged,
      ),
      const SizedBox(height: 14),

      Label(text: 'Additional Notes'),
      const SizedBox(height: 6),
      TextArea(
        controller: notesCtrl,
        hint: 'Optional — add any relevant context here…',
      ),
      const SizedBox(height: 18),

      AckRow(
        checked: acked,
        text:
            'I understand this action will affect the holder\'s'
            ' credential and cannot be undone without re-issuance.',
        color: accentColor,
        onChanged: onAckedChanged,
      ),
      const SizedBox(height: 24),

      DlgFooter(
        cancelLabel: 'Cancel',
        proceedLabel: proceedLabel,
        proceedColor: accentColor,
        canProceed: canProceed,
        onCancel: onCancel,
        onProceed: onProceed,
      ),
    ],
  );
}
