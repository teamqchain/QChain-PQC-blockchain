import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/IT_ADMIN/audit_model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TIMELINE NODE
// ═════════════════════════════════════════════════════════════════════════════

class TimelineNode extends StatefulWidget {
  final AuditEntry entry;
  final bool isLast;

  const TimelineNode({required this.entry, required this.isLast});

  @override
  State<TimelineNode> createState() => _TimelineNodeState();
}

class _TimelineNodeState extends State<TimelineNode> {
  bool _reasonVisible = false;

  bool get _isClickable {
    final a = widget.entry.action.toLowerCase();
    return (a.contains('revok') || a.contains('suspend')) &&
        widget.entry.note != null;
  }

  Color get _accentColor {
    final a = widget.entry.action.toLowerCase();
    if (a.contains('revok')) return AppColors.revoked;
    if (a.contains('suspend')) return AppColors.suspended;
    return AppColors.issuingAccent;
  }

  IconData get _nodeIcon {
    final a = widget.entry.action.toLowerCase();
    if (a.contains('revok')) return Icons.cancel_outlined;
    if (a.contains('suspend')) return Icons.pause_circle_outline_rounded;
    if (a.contains('restore')) return Icons.play_circle_outline_rounded;
    if (a.contains('reissued')) return Icons.refresh_rounded;
    return Icons.verified_outlined;
  }

  String get _performedVerb {
    final a = widget.entry.action.toLowerCase();
    if (a.contains('revok')) return 'Revoked';
    if (a.contains('suspend')) return 'Suspended';
    if (a.contains('restore')) return 'Restored';
    if (a.contains('reissued')) return 'Reissued';
    return 'Issued';
  }

  @override
  Widget build(BuildContext context) {
    final color = _accentColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Spine column ──────────────────────────────────────────────
        SizedBox(
          width: 42,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.13),
                  border: Border.all(
                    color: color.withOpacity(0.45),
                    width: 1.5,
                  ),
                ),
                child: Icon(_nodeIcon, size: 16, color: color),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // ── Content ───────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.isLast ? 0 : 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date
                Text(
                  widget.entry.date,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 10,
                    color: AppColors.textDim,
                  ),
                ),
                const SizedBox(height: 3),

                // Action title
                Text(
                  'Credential ${widget.entry.action}',
                  style: AppTextStyles.navLabelActive.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),

                // Performed by
                Text(
                  '$_performedVerb by: ${widget.entry.performedBy}',
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),

                // Clickable reason (only revoke / suspend)
                if (_isClickable) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _reasonVisible = !_reasonVisible),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _reasonVisible ? 'Hide reason' : 'Show reason',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 3),
                          AnimatedRotation(
                            turns: _reasonVisible ? 0.5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: _reasonVisible
                        ? Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: color.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 13,
                                  color: color.withOpacity(0.65),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'REASON',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: color.withOpacity(0.6),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.entry.note!,
                                        style: AppTextStyles.bodyTiny.copyWith(
                                          fontSize: 11,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
