// screens/issuer/request_capabilities_page.dart
//
// Request Additional Capabilities — view and manage capability requests.
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   import 'package:qportal_webapp/screens/issuer/request_capabilities_page.dart';
//
//   // Add route constant:
//   static const issuerCapabilities = '/issue/settings/capabilities';
//
//   // In IssuerSettingsPage:
//   IssuerSettingsPage(
//     onRequestCapabilities: () => _handleNavigate(RouteName.issuerCapabilities),
//     ...
//   );
//
//   // In _buildPage():
//   case RouteName.issuerCapabilities:
//     return RequestCapabilitiesPage(
//       onBack: () => _handleNavigate(RouteName.issuingSettings),
//     );

import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/filterButton.dart';
import 'package:qportal_webapp/components/searchBar.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/app_button.dart';

// ─── MODELS ───────────────────────────────────────────────────────────────────

enum _RequestStatus { accepted, rejected, pending }

extension _RequestStatusX on _RequestStatus {
  String get label {
    switch (this) {
      case _RequestStatus.accepted:
        return 'Accepted';
      case _RequestStatus.rejected:
        return 'Rejected';
      case _RequestStatus.pending:
        return 'Pending';
    }
  }
}

enum _RequestType { verifierAccess, issuerAccess }

extension _RequestTypeX on _RequestType {
  String get label {
    switch (this) {
      case _RequestType.verifierAccess:
        return 'Request Verifier Access';
      case _RequestType.issuerAccess:
        return 'Request Issuer Access';
    }
  }
}

class _CapabilityRequest {
  final String id;
  final _RequestType type;
  final String requestedDate;
  final String requestedBy;
  _RequestStatus status;

  _CapabilityRequest({
    required this.id,
    required this.type,
    required this.requestedDate,
    required this.requestedBy,
    required this.status,
  });
}

// ─── MOCK DATA ────────────────────────────────────────────────────────────────

final _kMockRequests = <_CapabilityRequest>[
  _CapabilityRequest(
    id: 'REQ-2025-001',
    type: _RequestType.verifierAccess,
    requestedDate: '14 Jan 2025',
    requestedBy: 'Mohammed A.',
    status: _RequestStatus.rejected,
  ),
  _CapabilityRequest(
    id: 'REQ-2025-002',
    type: _RequestType.issuerAccess,
    requestedDate: '03 Mar 2025',
    requestedBy: 'Registrar Ali',
    status: _RequestStatus.rejected,
  ),
  _CapabilityRequest(
    id: 'REQ-2025-003',
    type: _RequestType.verifierAccess,
    requestedDate: '18 Jun 2025',
    requestedBy: 'Mohammed A.',
    status: _RequestStatus.pending,
  ),
];

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class RequestCapabilitiesPage extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback? onNewRequest;

  const RequestCapabilitiesPage({
    super.key,
    required this.onBack,
    this.onNewRequest,
  });

  @override
  State<RequestCapabilitiesPage> createState() =>
      _RequestCapabilitiesPageState();
}

class _RequestCapabilitiesPageState extends State<RequestCapabilitiesPage> {
  late List<_CapabilityRequest> _requests;
  late List<_CapabilityRequest> _filtered;

  String _query = '';
  final _searchCtrl = TextEditingController();
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _requests = List.from(_kMockRequests);
    _applyFilter();
  }

  // ── filter ────────────────────────────────────────────────────────────────

  void _applyFilter() {
    final q = _query.toLowerCase().trim();
    _filtered = q.isEmpty
        ? List.from(_requests)
        : _requests.where((r) {
            return r.id.toLowerCase().contains(q) ||
                r.type.label.toLowerCase().contains(q) ||
                r.requestedBy.toLowerCase().contains(q) ||
                r.status.label.toLowerCase().contains(q);
          }).toList();
  }

  // ── selection ─────────────────────────────────────────────────────────────

  _CapabilityRequest? get _sel => _selectedId == null
      ? null
      : _requests.where((r) => r.id == _selectedId).firstOrNull;

  bool get _hasAccepted =>
      _requests.any((r) => r.status == _RequestStatus.accepted);

  bool get _canDelete => _sel != null && _sel!.status == _RequestStatus.pending;

  bool get _canNewRequest => !_hasAccepted;

  // ── delete ────────────────────────────────────────────────────────────────

  void _deleteSelected() {
    if (_sel == null) return;
    final id = _sel!.id;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteDialog(
        onConfirm: () {
          setState(() {
            _requests.removeWhere((r) => r.id == id);
            _selectedId = null;
            _applyFilter();
          });
        },
      ),
    );
  }

  // ── new request ───────────────────────────────────────────────────────────

  void _newRequest() {
    showDialog(
      context: context,
      builder: (_) => _NewRequestDialog(
        onSubmit: (type) {
          setState(() {
            _requests.insert(
              0,
              _CapabilityRequest(
                id: 'REQ-${DateTime.now().millisecondsSinceEpoch}',
                type: type,
                requestedDate: _todayLabel(),
                requestedBy: 'Mohammed A.',
                status: _RequestStatus.pending,
              ),
            );
            _applyFilter();
          });
        },
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const months = [
      '',
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
    return '${now.day.toString().padLeft(2, '0')} ${months[now.month]} ${now.year}';
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Request Additional Capabilities',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // Container
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
                  _buildColHeader(),
                  Expanded(child: _buildRows()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              AppButton(
                label: 'Back',
                icon: Icons.arrow_back_rounded,
                onTap: widget.onBack,
                showBorder: true,
                borderColor: AppColors.border,
              ),
              const SizedBox(width: 10),
              AppButton(
                label: 'Delete',
                backgroundColor: AppColors.revoked,
                icon: Icons.delete_outline_rounded,
                enabled: _canDelete,
                tooltip: _sel == null
                    ? 'Select a request first'
                    : _sel!.status != _RequestStatus.pending
                    ? 'Only pending requests can be deleted'
                    : null,
                onTap: _deleteSelected,
              ),
              const SizedBox(width: 10),
              AppButton(
                label: 'New Request',
                backgroundColor: AppColors.adminAccent,
                icon: Icons.add_rounded,
                enabled: _canNewRequest,
                tooltip: _canNewRequest
                    ? null
                    : 'A capability has already been accepted',
                onTap: () => widget.onNewRequest?.call(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TOOLBAR ───────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF161616),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          // Count chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.adminAccent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.adminAccent.withOpacity(0.25),
              ),
            ),
            child: Text(
              '${_requests.length} request${_requests.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.adminLight,
              ),
            ),
          ),
          const Spacer(),

          // Filter icon
          ToolbarIconBtn(
            icon: Icons.filter_list_rounded,
            tooltip: 'Filter',
            onTap: () {},
          ),
          const SizedBox(width: 10),

          // Search bar
          QSearchBar(
            controller: _searchCtrl,
            query: _query,
            onChanged: (v) => setState(() {
              _query = v;
              _applyFilter();
            }),
            onClear: () => setState(() {
              _query = '';
              _searchCtrl.clear();
              _applyFilter();
            }),
            barWidth: 280,
            searchLabel: 'Search requests…',
          ),
        ],
      ),
    );
  }

  // ─── COLUMN HEADER ─────────────────────────────────────────────────────────

  Widget _buildColHeader() {
    return Container(
      decoration:  BoxDecoration(
        color: AppColors.adminAccent.withOpacity(0.16),
        border: Border(
          top: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 36),
          _CH('REQUEST ID', flex: 3),
          _CH('REQUEST TYPE', flex: 4),
          _CH('REQUESTED DATE', flex: 3),
          _CH('REQUESTED BY', flex: 3),
          _CH('STATUS', flex: 2),
        ],
      ),
    );
  }

  // ─── ROWS ──────────────────────────────────────────────────────────────────

  Widget _buildRows() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _query.isEmpty ? Icons.inbox_outlined : Icons.search_off_rounded,
              size: 36,
              color: AppColors.textDim,
            ),
            const SizedBox(height: 12),
            Text(
              _query.isEmpty
                  ? 'No requests found.'
                  : 'No results for "$_query".',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 13,
                color: AppColors.textDim,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _filtered.length,
      separatorBuilder: (_, __) =>
          Container(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final r = _filtered[i];
        return _RequestRow(
          request: r,
          selected: r.id == _selectedId,
          onTap: () =>
              setState(() => _selectedId = r.id == _selectedId ? null : r.id),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  REQUEST ROW
// ═════════════════════════════════════════════════════════════════════════════

class _RequestRow extends StatefulWidget {
  final _CapabilityRequest request;
  final bool selected;
  final VoidCallback onTap;

  const _RequestRow({
    required this.request,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends State<_RequestRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.request;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: widget.selected
              ? AppColors.adminAccent.withOpacity(0.07)
              : _hovered
              ? AppColors.surfaceHover
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Checkbox
              SizedBox(
                width: 36,
                child: Checkbox(
                  value: widget.selected,
                  onChanged: (_) => widget.onTap(),
                  activeColor: AppColors.adminAccent,
                  checkColor: Colors.white,
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),

              // Request ID
              Expanded(
                flex: 3,
                child: Text(
                  r.id,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.adminLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Request Type
              Expanded(
                flex: 4,
                child: Text(
                  r.type.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Requested Date
              Expanded(
                flex: 3,
                child: Text(
                  r.requestedDate,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                ),
              ),

              // Requested By
              Expanded(
                flex: 3,
                child: Text(
                  r.requestedBy,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Status badge
              Expanded(flex: 2, child: _StatusBadge(status: r.status)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DELETE DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _DeleteDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  const _DeleteDialog({required this.onConfirm});

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
              color: Colors.black.withOpacity(0.6),
              blurRadius: 48,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.revoked.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: AppColors.revoked,
                  ),
                ),
                const SizedBox(width: 13),
                Text(
                  'Delete Request',
                  style: AppTextStyles.navLabelActive.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Message
            Text(
              'This request will be cancelled if it is deleted.',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(label: 'Cancel', onTap: () => Navigator.pop(context)),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Confirm Delete',
                  backgroundColor: AppColors.revoked,
                  icon: Icons.delete_outline_rounded,
                  onTap: () {
                    Navigator.pop(context);
                    onConfirm();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  NEW REQUEST DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _NewRequestDialog extends StatefulWidget {
  final void Function(_RequestType type) onSubmit;
  const _NewRequestDialog({required this.onSubmit});

  @override
  State<_NewRequestDialog> createState() => _NewRequestDialogState();
}

class _NewRequestDialogState extends State<_NewRequestDialog> {
  _RequestType _type = _RequestType.verifierAccess;

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
              color: Colors.black.withOpacity(0.6),
              blurRadius: 48,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.adminAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.add_circle_outline_rounded,
                    size: 20,
                    color: AppColors.adminAccent,
                  ),
                ),
                const SizedBox(width: 13),
                Text(
                  'New Capability Request',
                  style: AppTextStyles.navLabelActive.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Request Type label
            Text(
              'Request Type',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),

            // Type dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceHover,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: AppColors.adminAccent.withOpacity(0.5),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<_RequestType>(
                  value: _type,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E1E1E),
                  iconEnabledColor: AppColors.textDim,
                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                  items: _RequestType.values
                      .map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _type = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(label: 'Cancel', onTap: () => Navigator.pop(context)),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Submit',
                  backgroundColor: AppColors.adminAccent,
                  icon: Icons.send_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSubmit(_type);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final _RequestStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color c;
    final IconData icon;
    switch (status) {
      case _RequestStatus.accepted:
        c = AppColors.verifyingAccent;
        icon = Icons.check_circle_outline_rounded;
        break;
      case _RequestStatus.rejected:
        c = AppColors.revoked;
        icon = Icons.cancel_outlined;
        break;
      case _RequestStatus.pending:
        c = AppColors.suspended;
        icon = Icons.schedule_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: c),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _CH(String label, {int flex = 1}) => Expanded(
  flex: flex,
  child: Text(
    label,
    style: AppTextStyles.bodyTiny.copyWith(
      fontSize: 9,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
      color: AppColors.white,
    ),
  ),
);

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
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
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _h ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _h ? AppColors.borderLight : AppColors.border,
            ),
          ),
          child: Icon(widget.icon, size: 16, color: AppColors.textMuted),
        ),
      ),
    ),
  );
}
