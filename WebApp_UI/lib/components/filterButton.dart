import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';
class ToolbarIconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  const ToolbarIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });
  @override
  State<ToolbarIconBtn> createState() => ToolbarIconBtnState();
}

class ToolbarIconBtnState extends State<ToolbarIconBtn> {
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
          child: Icon(
            widget.icon,
            size: 17,
            color: widget.color ?? AppColors.textMuted,
          ),
        ),
      ),
    ),
  );
}
