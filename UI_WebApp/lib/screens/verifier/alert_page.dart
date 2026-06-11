// screens/verifier/alerts_page.dart

import 'package:flutter/material.dart';
import 'package:qportal_webapp/services/api_service.dart';
import 'package:qportal_webapp/components/searchBar.dart';
import 'package:qportal_webapp/components/connection_error.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';

// ─── ALERT SEVERITY (drives icon + accent colour) ────────────────────────────

enum AlertSeverity { revoked, expired, suspended, tampered, renewed, reissued }

extension AlertSeverityX on AlertSeverity {
  Color get color {
    switch (this) {
      case AlertSeverity.revoked:
        return AppColors.revoked;
      case AlertSeverity.expired:
        return AppColors.expired;
      case AlertSeverity.suspended:
        return AppColors.suspended;
      case AlertSeverity.tampered:
        return const Color(0xFFF97316);
      case AlertSeverity.renewed:
        return AppColors.valid;
      case AlertSeverity.reissued:
        return const Color(0xFF60A5FA);
    }
  }

  IconData get icon {
    switch (this) {
      case AlertSeverity.revoked:
        return Icons.block_rounded;
      case AlertSeverity.expired:
        return Icons.schedule_rounded;
      case AlertSeverity.suspended:
        return Icons.pause_circle_outline_rounded;
      case AlertSeverity.tampered:
        return Icons.warning_amber_rounded;
      case AlertSeverity.renewed:
        return Icons.autorenew_rounded;
      case AlertSeverity.reissued:
        return Icons.refresh_rounded;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class AlertsPage extends StatefulWidget {
  final VoidCallback onBack;

  const AlertsPage({super.key, required this.onBack});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  // Live State
  List<LiveAlertRecord> _allAlerts = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Search
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final alerts = await ApiService.getSubscriptionAlerts();
      if (mounted) {
        setState(() {
          _allAlerts = alerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Connection Error: Unable to reach the server to fetch alerts.';
        });
      }
    }
  }

  Future<void> _acknowledge(String id) async {
    try {
      final success = await ApiService.acknowledgeAlert(id);
      if (success && mounted) {
        setState(() {
          // Flip acknowledged locally to avoid a full re-fetch
          final idx = _allAlerts.indexWhere((a) => a.id == id);
          if (idx != -1) {
            _allAlerts[idx].acknowledged = true;
          }
        });
      } else if (!success && mounted) {
        _showErrorSnackbar('Failed to acknowledge alert. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Connection Error: Unable to reach the server.');
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.revoked,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── derived lists ─────────────────────────────────────────────────────────

  List<LiveAlertRecord> _applySearch(List<LiveAlertRecord> src) {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return src;
    return src.where((a) {
      return a.holderName.toLowerCase().contains(q) ||
          a.credentialName.toLowerCase().contains(q) ||
          a.description.toLowerCase().contains(q);
    }).toList();
  }

  List<LiveAlertRecord> get _activeAlerts =>
      _applySearch(_allAlerts.where((a) => !a.acknowledged).toList());

  List<LiveAlertRecord> get _archivedAlerts =>
      _applySearch(_allAlerts.where((a) => a.acknowledged).toList());

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ────────────────────────────────────────────────────────
          Text(
            'Alerts',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // ── Alerts container ─────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: [
                  _buildToolbar(),
                  Container(height: 1, color: AppColors.border),
                  Expanded(child: _buildAlertList()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Action bar ───────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppButton(
                icon: Icons.arrow_back_rounded,
                label: 'Back',
                showBorder: true,
                borderColor: AppColors.border,
                hoverColor: AppColors.surfaceHover,
                onTap: widget.onBack,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TOOLBAR ──────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    final activeCount = _allAlerts.where((a) => !a.acknowledged).length;

    return Container(
      color: const Color(0xFF161616),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          // Active count chip
          if (activeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.revoked.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.revoked.withOpacity(0.28)),
              ),
              child: Text(
                '$activeCount unread',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.revoked,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.verifyingAccent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.verifyingAccent.withOpacity(0.25),
                ),
              ),
              child: const Text(
                'All acknowledged',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.verifyingLight,
                ),
              ),
            ),

          const Spacer(),

          // Filter
          _ToolbarIconBtn(
            icon: Icons.filter_list_rounded,
            tooltip: 'Filter',
            onTap: () {},
          ),
          const SizedBox(width: 8),

          // Search
          QSearchBar(
            controller: _searchCtrl,
            query: _query,
            onChanged: (v) => setState(() => _query = v),
            onClear: () {
              _searchCtrl.clear();
              setState(() => _query = '');
            },
            barWidth: 260,
            searchLabel: 'Search by holder, credential…',
            activeColor: AppColors.verifyingAccent,
          ),
        ],
      ),
    );
  }

  // ─── ALERT LIST ───────────────────────────────────────────────────────────

  Widget _buildAlertList() {
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 80.0),
        child: ConnectionErrorWidget(onRetry: _fetchAlerts),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.verifyingAccent),
      );
    }

    final active = _activeAlerts;
    final archived = _archivedAlerts;

    if (active.isEmpty && archived.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _query.isEmpty
                  ? Icons.notifications_none_rounded
                  : Icons.search_off_rounded,
              size: 36,
              color: AppColors.textDim,
            ),
            const SizedBox(height: 12),
            Text(
              _query.isEmpty
                  ? 'No alerts at this time.'
                  : 'No alerts match "$_query".',
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
        if (active.isNotEmpty) ...[
          _SectionHeader(
            label: 'ACTIVE ALERTS',
            count: active.length,
            countColor: AppColors.revoked,
          ),
          ...active.map(
            (a) => _AlertItem(
              alert: a,
              acknowledged: false,
              onAcknowledge: () => _acknowledge(a.id),
            ),
          ),
        ],

        if (archived.isNotEmpty) ...[
          Container(height: 1, color: AppColors.border),
          _SectionHeader(
            label: 'ARCHIVED',
            count: archived.length,
            countColor: AppColors.textDim,
          ),
          ...archived.map(
            (a) =>
                _AlertItem(alert: a, acknowledged: true, onAcknowledge: () {}),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
                  _AcknowledgeButton(
                    acknowledged: acked,
                    accent: AppColors.verifyingAccent,
                    onTap: widget.onAcknowledge,
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

// ─── ACKNOWLEDGE BUTTON ───────────────────────────────────────────────────────

class _AcknowledgeButton extends StatefulWidget {
  final bool acknowledged;
  final Color accent;
  final VoidCallback onTap;

  const _AcknowledgeButton({
    required this.acknowledged,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_AcknowledgeButton> createState() => _AcknowledgeButtonState();
}

class _AcknowledgeButtonState extends State<_AcknowledgeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final acked = widget.acknowledged;

    // Acknowledged: greyed out, no interaction.
    // Pending: coloured outline that fills on hover.
    final Color border = acked
        ? AppColors.border
        : widget.accent.withOpacity(0.45);

    final Color bg = acked
        ? Colors.transparent
        : (_hovered ? widget.accent.withOpacity(0.12) : Colors.transparent);

    final Color fg = acked ? AppColors.textDim : widget.accent;

    return MouseRegion(
      cursor: acked ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: acked ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (acked)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_rounded, size: 12, color: fg),
                ),
              Text(
                acked ? 'Acknowledged' : 'Acknowledge',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── TOOLBAR ICON BUTTON ──────────────────────────────────────────────────────

class _ToolbarIconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ToolbarIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  @override
  State<_ToolbarIconBtn> createState() => _ToolbarIconBtnState();
}

class _ToolbarIconBtnState extends State<_ToolbarIconBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _h ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _h ? AppColors.border : Colors.transparent,
            ),
          ),
          child: Icon(widget.icon, size: 17, color: AppColors.textMuted),
        ),
      ),
    ),
  );
}
