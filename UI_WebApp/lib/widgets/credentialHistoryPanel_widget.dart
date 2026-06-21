import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/models/ISSUER/credentials_model.dart';
import 'package:qportal_webapp/widgets/credentialTimeline_widget.dart';
// Note: Ensure you import _TimelineNode if you move this to a different file.

class CredentialHistoryPanel extends StatelessWidget {
  final CredentialRecord credential;
  final VoidCallback onClose;

  const CredentialHistoryPanel({
    super.key,
    required this.credential,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final entries = credential.auditTrail;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Container(
            color: const Color(0xFF161616),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: AppColors.issuingAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Credential History',
                        style: AppTextStyles.navLabelActive.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        credential.id,
                        style: AppTextStyles.bodyTiny.copyWith(
                          fontSize: 10,
                          color: AppColors.textDim,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose, // Uses the passed callback to close
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: AppColors.textDim,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.border),

          // Timeline scroll area
          Expanded(
            child: entries.isEmpty
                ? _buildEmptyHistory()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                    child: Column(
                      children: List.generate(
                        entries.length,
                        (i) => TimelineNode(
                          entry: entries[i],
                          isLast: i == entries.length - 1,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_rounded,
            size: 32,
            color: AppColors.textDim.withOpacity(0.4),
          ),
          const SizedBox(height: 10),
          Text(
            'No history events yet',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 12,
              color: AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}