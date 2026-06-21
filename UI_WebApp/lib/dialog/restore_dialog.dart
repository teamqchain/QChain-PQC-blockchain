import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/ISSUER/credentials_model.dart';
import 'package:qportal_webapp/screens/issuer/suspend_revoke_page.dart';
import 'package:qportal_webapp/theme/appColours.dart' show AppColors;
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/utils/currentUser.dart';
// ═════════════════════════════════════════════════════════════════════════════
//  RESTORE DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class RestoreDialog extends StatefulWidget {
  final List<CredentialRecord> credentials;
  final VoidCallback onConfirmed;

  const RestoreDialog({required this.credentials, required this.onConfirmed});

  @override
  State<RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<RestoreDialog> {
  int _step = 1;
  bool _acked = false;

  final _pwCtrl = TextEditingController();
  bool _pwErr = false;

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
          1 => _Step1Restore(
            credentials: widget.credentials,
            acked: _acked,
            onAckedChanged: (v) => setState(() => _acked = v),
            canProceed: _acked,
            onCancel: () => Navigator.pop(context),
            onProceed: () => setState(() => _step = 2),
          ),
          2 => Step2Password(
            accentColor: AppColors.verifyingAccent,
            proceedLabel: 'Restore',
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
            actionPast: 'restored',
            accentColor: AppColors.verifyingAccent,
            onReturn: () => Navigator.pop(context),
          ),
        },
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  STEP WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ─── STEP 1 — RESTORE ─────────────────────────────────────────────────────────

class _Step1Restore extends StatelessWidget {
  final List<CredentialRecord> credentials;
  final bool acked;
  final void Function(bool) onAckedChanged;
  final bool canProceed;
  final VoidCallback onCancel;
  final VoidCallback onProceed;

  const _Step1Restore({
    required this.credentials,
    required this.acked,
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
        icon: Icons.restore_rounded,
        title: credentials.length == 1
            ? 'Restore Credential'
            : 'Restore ${credentials.length} Credentials',
        subtitle: 'This will reinstate the credential to VALID status.',
        accentColor: AppColors.verifyingAccent,
      ),
      const SizedBox(height: 20),

      CredSummary(credentials: credentials),
      const SizedBox(height: 18),

      // Info banner
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.verifyingAccent.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.verifyingAccent.withOpacity(0.22),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline,
              size: 14,
              color: AppColors.verifyingAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Restoring this credential will set its status back to VALID'
                ' and make it verifiable by third parties again.'
                ' All blockchain and IPFS records remain unchanged.',
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),

      AckRow(
        checked: acked,
        text:
            'I confirm that this credential should be reinstated to'
            ' VALID status and made accessible to the holder.',
        color: AppColors.verifyingAccent,
        onChanged: onAckedChanged,
      ),
      const SizedBox(height: 24),

      DlgFooter(
        cancelLabel: 'Cancel',
        proceedLabel: 'Restore',
        proceedColor: AppColors.verifyingAccent,
        canProceed: canProceed,
        onCancel: onCancel,
        onProceed: onProceed,
      ),
    ],
  );
}
