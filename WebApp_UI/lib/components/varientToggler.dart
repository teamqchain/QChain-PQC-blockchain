import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/dashboard_Model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/view/responsive_layout.dart';

/// Demo-only widget — shows a floating bar at the bottom to switch variants.
/// Remove this before production.
class VariantToggler extends StatelessWidget {
  final DashboardVariant current;
  final ValueChanged<DashboardVariant> onChanged;
  const VariantToggler({
    super.key,
    required this.current,
    required this.onChanged,
  });

  String extractedLabel(label) {
    String ex_label = label[8];
    // logDebug(ex_label);

    return ex_label;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xEE0A0A0A),
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isSmallScreen(context)) ...[
                Text(
                  'DEMO VARIANT  ',
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.0,
                    color: AppColors.textDim,
                    decoration: TextDecoration.none,
                  ),
                ),
                ...DashboardVariant.values.map(
                  (v) => _ToggleBtn(
                    label: v.label,
                    active: current == v,
                    onTap: () => onChanged(v),
                  ),
                ),
              ] else ...[
                ...DashboardVariant.values.map(
                  (v) => _ToggleBtn(
                    label: extractedLabel(v.label),
                    active: current == v,
                    onTap: () => onChanged(v),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleBtn extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_ToggleBtn> createState() => _ToggleBtnState();
}

class _ToggleBtnState extends State<_ToggleBtn> {
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
          margin: EdgeInsets.only(left: isSmallScreen(context) ? 3 : 6),
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen(context) ? 8 : 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.active
                ? AppColors.white
                : _hovered
                ? AppColors.surfaceHover
                : Colors.transparent,
            border: Border.all(
              color: widget.active ? AppColors.white : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 11,
              fontWeight: widget.active ? FontWeight.w700 : FontWeight.w400,
              color: widget.active ? Colors.black : AppColors.textMuted,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
