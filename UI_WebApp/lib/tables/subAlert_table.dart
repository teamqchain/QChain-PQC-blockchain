import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/components/connection_error.dart';
import 'package:qportal_webapp/models/VERIFIER/alert_model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/buildToolBar_widget.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  ALERTS TABLE / LIST
// ═════════════════════════════════════════════════════════════════════════════

class AlertsTable extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final List<LiveAlertRecord> activeAlerts;
  final List<LiveAlertRecord> archivedAlerts;
  final String search;
  final TextEditingController searchCtrl;
  final void Function(String) onSearchChanged;
  final VoidCallback onClearSearch;
  final void Function(String id) onAcknowledge;

  const AlertsTable({
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.activeAlerts,
    required this.archivedAlerts,
    required this.search,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final activeCount = activeAlerts.length;
    final hasActive = activeCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          BuildToolBar(
            selected: const {}, // No selection boxes in alerts
            totalFiltered: activeCount, // Chip shows active unread count
            searchCtrl: searchCtrl,
            search: search,
            onSearchChanged: onSearchChanged,
            onClearSearch: onClearSearch,
            searchLabel: 'Search by holder, credential…',
            trueMessage: '', // Unused here
            falseMessage: hasActive ? 'unread' : 'All acknowledged',
            falsePluralMessage: hasActive ? 'unread' : 'All acknowledged',
            searchColor: AppColors.verifyingAccent,
            backgroundColor: hasActive
                ? AppColors.revoked.withOpacity(0.10)
                : AppColors.verifyingAccent.withOpacity(0.10),
            borderColor: hasActive
                ? AppColors.revoked.withOpacity(0.28)
                : AppColors.verifyingAccent.withOpacity(0.25),
            textColor: hasActive ? AppColors.revoked : AppColors.verifyingLight,
          ),
          Container(height: 1, color: AppColors.border),
          Expanded(child: _buildAlertList()),
        ],
      ),
    );
  }

  Widget _buildAlertList() {
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 80.0),
        child: ConnectionErrorWidget(onRetry: onRetry),
      );
    }

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.verifyingAccent),
      );
    }

    if (activeAlerts.isEmpty && archivedAlerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              search.isEmpty
                  ? Icons.notifications_none_rounded
                  : Icons.search_off_rounded,
              size: 36,
              color: AppColors.textDim,
            ),
            const SizedBox(height: 12),
            Text(
              search.isEmpty
                  ? 'No alerts at this time.'
                  : 'No alerts match "$search".',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 13,
                color: AppColors.textDim,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (activeAlerts.isNotEmpty) ...[
          _SectionHeader(
            label: 'ACTIVE ALERTS',
            count: activeAlerts.length,
            countColor: AppColors.revoked,
          ),
          ...activeAlerts.map(
            (a) => _AlertItem(
              alert: a,
              acknowledged: false,
              onAcknowledge: () => onAcknowledge(a.id),
            ),
          ),
        ],

        if (archivedAlerts.isNotEmpty) ...[
          if (activeAlerts.isNotEmpty)
            Container(height: 1, color: AppColors.border),
          _SectionHeader(
            label: 'ARCHIVED',
            count: archivedAlerts.length,
            countColor: AppColors.textDim,
          ),
          ...archivedAlerts.map(
            (a) =>
                _AlertItem(alert: a, acknowledged: true, onAcknowledge: () {}),
          ),
        ],
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SECTION HEADER
// ═════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color countColor;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.countColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF141414),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.textDim,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: countColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: countColor.withOpacity(0.3)),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: countColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ALERT ITEM
// ═════════════════════════════════════════════════════════════════════════════

class _AlertItem extends StatefulWidget {
  final LiveAlertRecord alert;
  final bool acknowledged;
  final VoidCallback onAcknowledge;

  const _AlertItem({
    required this.alert,
    required this.acknowledged,
    required this.onAcknowledge,
  });

  @override
  State<_AlertItem> createState() => _AlertItemState();
}

class _AlertItemState extends State<_AlertItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final acked = widget.acknowledged;
    final accent = a.severity.color;

    // Greyed-out opacity for archived items
    final double opacity = acked ? 0.45 : 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            color: !acked && _hovered
                ? AppColors.surfaceHover
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Opacity(
              opacity: opacity,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Severity icon circle ──────────────────────────────
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withOpacity(0.13),
                      border: Border.all(color: accent.withOpacity(0.35)),
                    ),
                    child: Icon(a.severity.icon, size: 16, color: accent),
                  ),
                  const SizedBox(width: 14),

                  // ── Main content ──────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.credentialID,
                          style: AppTextStyles.bodyTiny.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // Main line: Holder Name · Credential Name
                        Row(
                          children: [
                            Text(
                              a.holderName,
                              style: AppTextStyles.bodyTiny.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 7),
                              child: Text(
                                '·',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textDim,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                a.credentialName,
                                style: AppTextStyles.bodyTiny.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // Detail line: description + date/time
                        Text(
                          a.description,
                          style: AppTextStyles.bodyTiny.copyWith(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 11,
                              color: AppColors.textDim,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              a.dateTime,
                              style: AppTextStyles.bodyTiny.copyWith(
                                fontSize: 10,
                                color: AppColors.textDim,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // ── Acknowledge button ────────────────────────────────
                  AppButton(
                    label: acked ? 'Acknowledged' : 'Acknowledge',
                    icon: acked ? Icons.check_rounded : null,
                    enabled: !acked,
                    onTap: widget.onAcknowledge,
                    backgroundColor: Colors.transparent,
                    hoverColor: AppColors.verifyingAccent.withOpacity(0.12),
                    disabledBackgroundColor: Colors.transparent,
                    showBorder: true,
                    borderColor: AppColors.verifyingAccent.withOpacity(0.45),
                    disabledBorderColor: AppColors.border,
                    textColor: AppColors.verifyingAccent,
                    disabledTextColor: AppColors.textDim,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    iconSize: 12,
                    iconSpacing: 6,
                    horizontalPadding: 14,
                    verticalPadding: 7,
                    height: 35, // Adjusted to match the original compact size
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(height: 1, color: AppColors.border),
      ],
    );
  }
}
