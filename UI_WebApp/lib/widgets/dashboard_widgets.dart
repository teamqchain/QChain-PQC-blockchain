import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/dashboard_Model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/view/responsive_layout.dart';

// ─── CAPABILITY BADGE ─────────────────────────────────────────────────────────

class CapabilityBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const CapabilityBadge({
    super.key,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: AppTextStyles.badge.copyWith(color: color)),
    );
  }
}

// ─── STAT CHIP ────────────────────────────────────────────────────────────────

class StatChip extends StatefulWidget {
  final String label;
  final int value;
  final Color accent;
  final VoidCallback? onTap;
  const StatChip({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    this.onTap,
  });

  @override
  State<StatChip> createState() => _StatChipState();
}

class _StatChipState extends State<StatChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          width: 150,
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceHover : widget.accent,
            border: Border.all(
              color: _hovered ? widget.accent : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.accent.withOpacity(0.15),
                      blurRadius: 18,
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.value}',
                style: AppTextStyles.statValue.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4), // stat label
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SECTION HEADER ───────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final Color accent;
  final String? linkText;
  final VoidCallback? onLinkTap;
  const SectionHeader({
    super.key,
    required this.title,
    required this.accent,
    this.linkText,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (!isSmallScreen(context)) ...[
            Container(
              //small line in the heading
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(title.toUpperCase(), style: AppTextStyles.sectionLabel),
            const Spacer(),
            if (linkText != null)
              GestureDetector(
                onTap: onLinkTap,
                child: Text(
                  '$linkText →',
                  style: AppTextStyles.linkText.copyWith(color: accent),
                ),
              ),
          ] else ...[
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(title.toUpperCase(), style: AppTextStyles.sectionLabel),
            const Spacer(),
            if (linkText != null)
              GestureDetector(
                onTap: onLinkTap,
                child: Text(
                  '$linkText →',
                  style: AppTextStyles.linkText.copyWith(color: accent),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── DASHBOARD CARD ───────────────────────────────────────────────────────────

class DashCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  final Color? backgroundColor;
  const DashCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        border: Border.all(color: borderColor ?? AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

// ─── ACTIVITY ROW ─────────────────────────────────────────────────────────────

class ActivityRow extends StatefulWidget {
  final ActivityItem item;
  final Color accent;
  const ActivityRow({super.key, required this.item, required this.accent});

  @override
  State<ActivityRow> createState() => _ActivityRowState();
}

class _ActivityRowState extends State<ActivityRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surfaceHover : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: _hovered ? widget.accent : Colors.transparent,
              width: 2,
            ),
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(widget.item.text, style: AppTextStyles.bodySmall),
            ),
            const SizedBox(width: 12),
            Text(widget.item.time, style: AppTextStyles.bodyTiny),
          ],
        ),
      ),
    );
  }
}

// ─── VERIFICATION ROW ─────────────────────────────────────────────────────────

class VerificationRow extends StatefulWidget {
  final VerificationItem item;
  const VerificationRow({super.key, required this.item});

  @override
  State<VerificationRow> createState() => _VerificationRowState();
}

class _VerificationRowState extends State<VerificationRow> {
  bool _hovered = false;

  Color get _statusColor {
    switch (widget.item.status) {
      case 'VALID':
        return AppColors.valid;
      case 'REVOKED':
        return AppColors.revoked;
      case 'SUSPENDED':
        return AppColors.suspended;
      case 'EXPIRED':
        return AppColors.expired;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surfaceHover : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: _hovered ? AppColors.verifyingAccent : Colors.transparent,
              width: 2,
            ),
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.item.holderName} — ${widget.item.credential}',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(widget.item.time, style: AppTextStyles.bodyTiny),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.item.status,
                style: AppTextStyles.badge.copyWith(color: _statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ALERT ROW ────────────────────────────────────────────────────────────────

class AlertRow extends StatefulWidget {
  final AlertItem item;
  const AlertRow({super.key, required this.item});

  @override
  State<AlertRow> createState() => _AlertRowState();
}

class _AlertRowState extends State<AlertRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFF1A1000) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            const Text('⚠', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: AppTextStyles.bodySmall,
                  children: [
                    TextSpan(text: '${item.name} — ${item.credential}  '),
                    WidgetSpan(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.suspended.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          item.event,
                          style: AppTextStyles.badge.copyWith(
                            color: AppColors.suspended,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(item.time, style: AppTextStyles.bodyTiny),
          ],
        ),
      ),
    );
  }

  AlertItem get item => widget.item;
}

// ─── EXPIRY ROW ───────────────────────────────────────────────────────────────

class ExpiryRow extends StatefulWidget {
  final ExpiryItem item;
  const ExpiryRow({super.key, required this.item});

  @override
  State<ExpiryRow> createState() => _ExpiryRowState();
}

class _ExpiryRowState extends State<ExpiryRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final urgent = widget.item.daysLeft <= 10;
    final color = urgent ? AppColors.revoked : AppColors.suspended;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surfaceHover : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.item.name, style: AppTextStyles.bodySmall),
                  const SizedBox(height: 2),
                  Text(widget.item.credential, style: AppTextStyles.bodyTiny),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${widget.item.daysLeft}d left',
                style: AppTextStyles.badge.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── MINI BAR CHART ───────────────────────────────────────────────────────────

class MiniBarChart extends StatelessWidget {
  final List<BarDataPoint> data;
  final Color accent;
  const MiniBarChart({super.key, required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: 90,
        child: Center(
          child: Text('No chart data available', style: AppTextStyles.bodyTiny),
        ),
      );
    }

    final maxVal = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    final safeMaxVal = maxVal <= 0 ? 1 : maxVal;
    return SizedBox(
      height: 90,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((d) {
          final heightFraction = d.value / safeMaxVal;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${d.value.toInt()}',
                    style: AppTextStyles.bodyTiny.copyWith(fontSize: 9),
                  ),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    height: (heightFraction * 48).clamp(6, 48),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.85),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    d.label,
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 8,
                    ), // week number wk1, wk2, etc.
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── ACTION BUTTON ────────────────────────────────────────────────────────────

class DashActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool large;
  final VoidCallback onTap;
  const DashActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    this.large = false,
    required this.onTap,
  });

  @override
  State<DashActionButton> createState() => _DashActionButtonState();
}

class _DashActionButtonState extends State<DashActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: widget.large
              ? const EdgeInsets.symmetric(horizontal: 24, vertical: 14)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? widget.accent : widget.accent.withOpacity(0.12),
            border: Border.all(color: widget.accent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: _hovered ? Colors.white : widget.accent,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: widget.large ? 13 : 12,
                    fontWeight: FontWeight.w600,
                    color: _hovered ? Colors.white : widget.accent,
                  ),
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

// ─── LOCKED SECTION NOTICE ────────────────────────────────────────────────────

class LockedNotice extends StatelessWidget {
  final String message;
  const LockedNotice({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Text('🔒', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: AppTextStyles.bodyTiny)),
        ],
      ),
    );
  }
}
