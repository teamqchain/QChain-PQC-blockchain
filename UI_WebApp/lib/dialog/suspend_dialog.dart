import 'package:flutter/material.dart' hide Radio;
import 'package:qportal_webapp/components/label.dart';
import 'package:qportal_webapp/models/ISSUER/credentials_model.dart';
import 'package:qportal_webapp/screens/issuer/suspend_revoke_page.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/utils/currentUser.dart';
import 'package:qportal_webapp/utils/dateFormatter.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  SUSPEND DIALOG
// ═════════════════════════════════════════════════════════════════════════════

// ─── SUSPEND REASON OPTIONS ───────────────────────────────────────────────────

const _kSuspendReasons = <String>[
  'Audit review in progress',
  'Disciplinary investigation',
  'Temporary hold — pending verification',
  'Holder request',
  'Other',
];

enum _SuspendMode { furtherNotice, specificDate }

class SuspendDialog extends StatefulWidget {
  final List<CredentialRecord> credentials;
  final void Function(String reason) onConfirmed;

  const SuspendDialog({required this.credentials, required this.onConfirmed});

  @override
  State<SuspendDialog> createState() => _SuspendDialogState();
}

class _SuspendDialogState extends State<SuspendDialog> {
  int _step = 1;

  // Step 1
  String? _reason;
  final _notesCtrl = TextEditingController();
  bool _acked = false;
  _SuspendMode _mode = _SuspendMode.furtherNotice;
  DateTime? _untilDate;

  // Step 2
  final _pwCtrl = TextEditingController();
  bool _pwErr = false;

  bool get _step1Ready =>
      _reason != null &&
      _acked &&
      (_mode == _SuspendMode.furtherNotice || _untilDate != null);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.suspended,
            onPrimary: Colors.black,
            surface: Color(0xFF1E1E1E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _untilDate = picked);
  }


  void _submitPw() {
    if (_pwCtrl.text.trim().isEmpty) {
      setState(() => _pwErr = true);
      return;
    }
    widget.onConfirmed(_reason!);
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
          1 => _Step1Suspend(
            credentials: widget.credentials,
            reason: _reason,
            notesCtrl: _notesCtrl,
            acked: _acked,
            mode: _mode,
            untilDate: _untilDate,
            dateLabel: _untilDate != null ? DateFormatter.formatIsoDate(_untilDate! as String) : null,
            reasons: _kSuspendReasons,
            onReasonChanged: (v) => setState(() => _reason = v),
            onAckedChanged: (v) => setState(() => _acked = v),
            onModeChanged: (v) => setState(() {
              _mode = v;
              _untilDate = null;
            }),
            onPickDate: _pickDate,
            canProceed: _step1Ready,
            onCancel: () => Navigator.pop(context),
            onProceed: () => setState(() => _step = 2),
          ),
          2 => Step2Password(
            accentColor: AppColors.suspended,
            proceedLabel: 'Suspend',
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
            actionPast: 'suspended',
            accentColor: AppColors.suspended,
            onReturn: () => Navigator.pop(context),
          ),
        },
      ),
    ),
  );
}

// ─── STEP 1 — SUSPEND ─────────────────────────────────────────────────────────

class _Step1Suspend extends StatelessWidget {
  final List<CredentialRecord> credentials;
  final String? reason;
  final TextEditingController notesCtrl;
  final bool acked;
  final _SuspendMode mode;
  final DateTime? untilDate;
  final String? dateLabel;
  final List<String> reasons;
  final void Function(String?) onReasonChanged;
  final void Function(bool) onAckedChanged;
  final void Function(_SuspendMode) onModeChanged;
  final VoidCallback onPickDate;
  final bool canProceed;
  final VoidCallback onCancel;
  final VoidCallback onProceed;

  const _Step1Suspend({
    required this.credentials,
    required this.reason,
    required this.notesCtrl,
    required this.acked,
    required this.mode,
    required this.untilDate,
    required this.dateLabel,
    required this.reasons,
    required this.onReasonChanged,
    required this.onAckedChanged,
    required this.onModeChanged,
    required this.onPickDate,
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
        icon: Icons.pause_circle_outline_rounded,
        title: credentials.length == 1
            ? 'Suspend Credential'
            : 'Suspend ${credentials.length} Credentials',
        subtitle: 'Review the summary and configure the suspension period.',
        accentColor: AppColors.suspended,
      ),
      const SizedBox(height: 20),

      CredSummary(credentials: credentials),
      const SizedBox(height: 20),

      // Suspension duration
      const Label(text: 'Suspension Duration'),
      const SizedBox(height: 10),
      Row(
        children: [
          Radio(
            label: 'Until further notice',
            selected: mode == _SuspendMode.furtherNotice,
            color: AppColors.suspended,
            onTap: () => onModeChanged(_SuspendMode.furtherNotice),
          ),
          const SizedBox(width: 20),
          Radio(
            label: 'Until a specific date',
            selected: mode == _SuspendMode.specificDate,
            color: AppColors.suspended,
            onTap: () => onModeChanged(_SuspendMode.specificDate),
          ),
        ],
      ),

      if (mode == _SuspendMode.specificDate) ...[
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onPickDate,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceHover,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: dateLabel != null
                      ? AppColors.suspended.withOpacity(0.55)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: dateLabel != null
                        ? AppColors.suspended
                        : AppColors.textDim,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    dateLabel ?? 'Pick a date…',
                    style: TextStyle(
                      fontSize: 12,
                      color: dateLabel != null
                          ? AppColors.text
                          : AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],

      const SizedBox(height: 14),

      const Label(text: 'Reason for Suspension ', required: true),
      const SizedBox(height: 6),
      Dropdown(
        value: reason,
        items: reasons,
        hint: 'Select a reason…',
        accentColor: AppColors.suspended,
        onChanged: onReasonChanged,
      ),
      const SizedBox(height: 14),

      const Label(text: 'Additional Notes'),
      const SizedBox(height: 6),
      TextArea(
        controller: notesCtrl,
        hint: 'Optional — add any relevant context here…',
      ),
      const SizedBox(height: 18),

      AckRow(
        checked: acked,
        text:
            'I understand this will temporarily restrict the holder\'s'
            ' access to this credential.',
        color: AppColors.suspended,
        onChanged: onAckedChanged,
      ),
      const SizedBox(height: 24),

      DlgFooter(
        cancelLabel: 'Cancel',
        proceedLabel: 'Suspend',
        proceedColor: AppColors.suspended,
        canProceed: canProceed,
        onCancel: onCancel,
        onProceed: onProceed,
      ),
    ],
  );
}
