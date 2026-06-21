import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/dashboard_Model.dart';
import 'package:qportal_webapp/services/core_api.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/routes/webApp_shell.dart';
// TODO: Adjust this import path to match where your ApiService is located

// ─── NAV ITEM MODEL ───────────────────────────────────────────────────────────

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem(this.icon, this.label, this.route);
}

final _navIssuing = [
  _NavItem(Icons.insert_drive_file, 'Issue Credential', RouteName.issueSingle),
  _NavItem(Icons.library_books, 'Batch Issue', RouteName.issueBatch),
  _NavItem(Icons.schema, 'All Credentials', RouteName.allCredentials),
  _NavItem(Icons.cancel, 'Revoke / Suspend', RouteName.revokeSuspend),
  _NavItem(Icons.schema, 'Schemas', RouteName.schemas),
];

final _navVerifying = [
  _NavItem(Icons.qr_code_scanner, 'Scan QR Code', RouteName.scanQR),
  _NavItem(Icons.keyboard, 'Manual Verify', RouteName.manualVerify),
  _NavItem(Icons.group, 'Batch Verify', RouteName.batchVerify),
  _NavItem(
    Icons.history,
    'Verification History',
    RouteName.verificationHistory,
  ),
  _NavItem(Icons.payment, 'Subscriptions', RouteName.subscription),
  _NavItem(
    Icons.notifications_active,
    'Subscription Alerts',
    RouteName.alertHistory,
  ),
  _NavItem(Icons.policy, 'Policies', RouteName.policies),
];

final _navITAdmin = [
  _NavItem(Icons.person, 'Manage Profile', RouteName.manageProfile),
  _NavItem(Icons.group, 'Staff & Permissions', RouteName.staffAndPermissions),
  _NavItem(Icons.assignment_turned_in, 'Audit Log', RouteName.auditLog),
  _NavItem(Icons.security, 'Crypto Settings', RouteName.cryptoSettings),
  _NavItem(
    Icons.add_circle_outline,
    'Request Capabilities',
    RouteName.requestCapabilities,
  ),
];

// ─── ENUMS ────────────────────────────────────────────────────────────────────
enum ConnectionStatus { connecting, connected, disconnected }

// ─── SIDEBAR ──────────────────────────────────────────────────────────────────

class AppSidebar extends StatefulWidget {
  final DashboardVariant variant;
  final String activeRoute;
  final ValueChanged<String> onNavigate;

  const AppSidebar({
    super.key,
    required this.variant,
    required this.activeRoute,
    required this.onNavigate,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  bool get _showIssuing => widget.variant.canIssue;
  bool get _showVerifying => widget.variant.canVerify;
  bool get _showingITAdmin => widget.variant.canManage;

  bool _hovered = false;

  ConnectionStatus _connStatus = ConnectionStatus.connecting;
  Timer? _healthTimer;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _date {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dow = days[now.weekday - 1];
    return '$dow, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  void initState() {
    super.initState();
    _checkHealth(); // Initial check
    // Poll every 15 seconds
    _healthTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkHealth();
    });
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkHealth() async {
    final isHealthy = await ApiCore.checkHealth();
    if (mounted) {
      setState(() {
        _connStatus = isHealthy
            ? ConnectionStatus.connected
            : ConnectionStatus.disconnected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 220,
      color: AppColors.sidebarNeutral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogo(),
          _buildGreeting(),
          _buildDivider(),
          _buildDashboardLink(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showIssuing)
                    _buildSection(
                      'ISSUING',
                      _navIssuing,
                      AppColors.issuingAccent,
                      AppColors.issuingLight,
                    ),
                  if (_showIssuing && _showVerifying) _buildDivider(),
                  if (_showVerifying)
                    _buildSection(
                      'VERIFYING',
                      _navVerifying,
                      AppColors.verifyingAccent,
                      AppColors.verifyingLight,
                    ),
                  if (_showingITAdmin)
                    _buildSection(
                      'MANAGING',
                      _navITAdmin,
                      AppColors.adminAccent,
                      AppColors.adminLight,
                    ),
                ],
              ),
            ),
          ),
          _buildDivider(),
          _buildConnectionStatus(),
          _buildUserTile(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/QChain_logo_white.png'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'QPortal',
              style: AppTextStyles.navLabelActive.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                fontFamily: 'formula',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_greeting, Mohammed',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _date,
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 10,
              color: AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardLink() {
    final isActive = widget.activeRoute == RouteName.dashboard;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () {
            widget.onNavigate(RouteName.dashboard);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.surfaceHover
                  : _hovered
                  ? AppColors.surfaceHover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.dashboard,
                  size: 20,
                  color: isActive ? AppColors.white : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Dashboard',
                    style: isActive
                        ? AppTextStyles.navLabelActive
                        : AppTextStyles.navLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    String label,
    List<_NavItem> items,
    Color accent,
    Color lightAccent,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: lightAccent,
                  ),
                ),
              ],
            ),
          ),
          ...items.map(
            (item) => _SidebarNavItem(
              item: item,
              accent: accent,
              isActive: widget.activeRoute == item.route,
              onTap: () => widget.onNavigate(item.route),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    Color dotColor;
    String label;

    switch (_connStatus) {
      case ConnectionStatus.connecting:
        dotColor = Colors.amber;
        label = 'Connecting...';
        break;
      case ConnectionStatus.connected:
        dotColor = Colors.green;
        label = 'Connected';
        break;
      case ConnectionStatus.disconnected:
        dotColor = Colors.red;
        label = 'Disconnected';
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PulsingDot(color: dotColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 10,
              color: AppColors.textDim,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile() {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.issuingAccent.withOpacity(0.3),
            child: const Text(
              'M',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mohammed A.',
                  style: AppTextStyles.navLabelActive.copyWith(fontSize: 11),
                ),
                Text(
                  (_showIssuing
                      ? "Issuer"
                      : (_showVerifying)
                      ? "Verifier"
                      : "IT Admin"),
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 9,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '⋮',
            style: TextStyle(color: AppColors.textDim, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Container(
    height: 1,
    color: AppColors.border,
    margin: const EdgeInsets.symmetric(vertical: 2),
  );
}

// ─── SIDEBAR NAV ITEM ─────────────────────────────────────────────────────────

class _SidebarNavItem extends StatefulWidget {
  final _NavItem item;
  final Color accent;
  final bool isActive;
  final VoidCallback onTap;
  const _SidebarNavItem({
    required this.item,
    required this.accent,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? widget.accent.withOpacity(0.15)
                : _hovered
                ? widget.accent.withOpacity(0.1)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: active || _hovered ? widget.accent : Colors.transparent,
                width: 2,
              ),
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(
                widget.item.icon,
                size: 12,
                color: active || _hovered ? widget.accent : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.item.label,
                  style: active || _hovered
                      ? AppTextStyles.navLabelActive
                      : AppTextStyles.navLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── PULSING DOT WIDGET ───────────────────────────────────────────────────────

class PulsingDot extends StatefulWidget {
  final Color color;

  const PulsingDot({super.key, required this.color});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Animate opacity between 40% and 100% for a smooth breathing effect
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color,
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
