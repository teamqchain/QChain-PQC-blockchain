import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/toast.dart';
import 'package:qportal_webapp/models/VERIFIER/alert_model.dart';
import 'package:qportal_webapp/services/subscription_api.dart';
import 'package:qportal_webapp/tables/subAlert_table.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';

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

  OverlayEntry? _toastEntry;

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
      final alerts = await SubscriptionApi.getSubscriptionAlerts();
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
      final success = await SubscriptionApi.acknowledgeAlert(id);
      if (success && mounted) {
        setState(() {
          // Flip acknowledged locally to avoid a full re-fetch
          final idx = _allAlerts.indexWhere((a) => a.id == id);
          if (idx != -1) {
            _allAlerts[idx].acknowledged = true;
          }
        });
      } else if (!success && mounted) {
        showToast('Error 400: Failed to acknowledge alert. Please try again.', Icons.error_outline, true);
      }
    } catch (e) {
      if (mounted) {
        showToast('Connection Error: Unable to reach the server.', Icons.error_outline, true);
      }
    }
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
            child: AlertsTable(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              onRetry: _fetchAlerts,
              activeAlerts: _activeAlerts,
              archivedAlerts: _archivedAlerts,
              search: _query,
              searchCtrl: _searchCtrl,
              onSearchChanged: (v) => setState(() => _query = v),
              onClearSearch: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
              onAcknowledge: _acknowledge,
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

  void showToast(String message, IconData reqIcons, bool isError) {
    _toastEntry?.remove();
    _toastEntry = OverlayEntry(
      builder: (_) => Toast(
        message: message,
        toastIcons: reqIcons,
        onDone: () {
          _toastEntry?.remove();
          _toastEntry = null;
        },
        bgColor: isError ? AppColors.revoked : AppColors.adminMid,
        iconColor: AppColors.text,
      ),
    );
    Overlay.of(context).insert(_toastEntry!);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}


