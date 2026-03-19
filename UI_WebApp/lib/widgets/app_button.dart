import 'package:flutter/material.dart';

/// A fully customisable button widget.
///
/// Every visual property (colours, sizes, border, hover, disabled state) is
/// exposed as a named parameter with a sensible default so you only override
/// what you need.
class AppButton extends StatefulWidget {
  // ── REQUIRED ──────────────────────────────────────────────────────────

  /// The text shown on the button.
  final String label;

  /// Called when the button is tapped (ignored when [enabled] is `false`).
  final VoidCallback onTap;

  // ── BACKGROUND ────────────────────────────────────────────────────────

  /// Background colour of the button.
  /// Default: `Colors.transparent` (no fill).
  final Color backgroundColor;

  /// Background colour when the cursor hovers over the button.
  /// Default: same as [backgroundColor] (no visible hover change).
  final Color? hoverColor;

  /// Background colour when the button is disabled.
  /// Default: [backgroundColor] at 35 % opacity.
  final Color? disabledBackgroundColor;

  // ── BORDER ────────────────────────────────────────────────────────────

  /// Whether to draw a border around the button.
  /// Default: `false`.
  final bool showBorder;

  /// Border colour (only used when [showBorder] is `true`).
  /// Default: `Colors.white24`.
  final Color borderColor;

  /// Border colour when the button is disabled.
  /// Default: `Colors.white10`.
  final Color? disabledBorderColor;

  /// Thickness of the border in logical pixels.
  /// Default: `1.0`.
  final double borderWidth;

  // ── TEXT ───────────────────────────────────────────────────────────────

  /// Colour of the label text.
  /// Default: `Colors.white`.
  final Color textColor;

  /// Colour of the label text when the button is disabled.
  /// Default: `Colors.white70`.
  final Color? disabledTextColor;

  /// Font size of the label in logical pixels.
  /// Default: `12`.
  final double fontSize;

  /// Font weight (boldness) of the label.
  /// Default: `FontWeight.w700`.
  final FontWeight fontWeight;

  // ── ICON ──────────────────────────────────────────────────────────────

  /// Optional icon shown to the left of the label.
  final IconData? icon;
  final bool? iconRight;

  /// Colour of the icon.
  /// Default: same as [textColor].
  final Color? iconColor;

  /// Colour of the icon when the button is disabled.
  /// Default: same as [disabledTextColor].
  final Color? disabledIconColor;

  /// Size of the icon in logical pixels.
  /// Default: `14`.
  final double iconSize;

  /// Gap between the icon and the label in logical pixels.
  /// Default: `7`.
  final double iconSpacing;

  // ── SIZE & SHAPE ──────────────────────────────────────────────────────

  /// Fixed width. When `null` the button sizes itself to its content.
  final double? width;

  /// Height of the button in logical pixels.
  /// Default: `36`.
  final double height;

  /// Left & right padding inside the button.
  /// Default: `16`.
  final double horizontalPadding;

  /// Top & bottom padding inside the button.
  /// Default: `9`.
  final double verticalPadding;

  /// Corner roundness in logical pixels.
  /// Default: `7`.
  final double borderRadius;

  // ── BEHAVIOUR ─────────────────────────────────────────────────────────

  /// Whether the button is interactive.
  /// When `false` the button is dimmed and taps are ignored.
  /// Default: `true`.
  final bool enabled;

  /// Tooltip text shown on hover when the button is **disabled**.
  /// Leave `null` for no tooltip.
  final String? tooltip;

  const AppButton({
    super.key,
    // required
    required this.label,
    required this.onTap,
    // background
    this.backgroundColor = Colors.transparent,
    this.hoverColor,
    this.disabledBackgroundColor,
    // border
    this.showBorder = false,
    this.borderColor = Colors.white24,
    this.disabledBorderColor,
    this.borderWidth = 1.0,
    // text
    this.textColor = Colors.white,
    this.disabledTextColor,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w700,
    // icon
    this.icon,
    this.iconColor,
    this.disabledIconColor,
    this.iconSize = 14,
    this.iconSpacing = 7,
    this.iconRight = false,
    // size & shape
    this.width,
    this.height = 36,
    this.horizontalPadding = 16,
    this.verticalPadding = 9,
    this.borderRadius = 7,
    // behaviour
    this.enabled = true,
    this.tooltip,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.enabled;

    // ── resolve colours ──────────────────────────────────────────────────

    // Background
    final Color bg;
    if (!isEnabled) {
      bg = widget.disabledBackgroundColor ??
          widget.backgroundColor.withOpacity(0.35);
    } else if (_hovered && widget.hoverColor != null) {
      bg = widget.hoverColor!;
    } else {
      bg = widget.backgroundColor;
    }

    // Text
    final Color fg =
        isEnabled ? widget.textColor : (widget.disabledTextColor ?? widget.textColor.withOpacity(0.7));

    // Icon (falls back to text colour)
    final Color ic = isEnabled
        ? (widget.iconColor ?? fg)
        : (widget.disabledIconColor ?? widget.disabledTextColor ?? fg);

    // Border
    final Color? resolvedBorder = widget.showBorder
        ? (isEnabled
            ? widget.borderColor
            : (widget.disabledBorderColor ?? widget.borderColor.withOpacity(0.4)))
        : null;

    // ── content (label ± icon) ───────────────────────────────────────────

    final textStyle = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: widget.fontWeight,
      color: fg,
    );

    Widget content;
    if (widget.icon != null) {
      if(widget.iconRight == true) {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.label, style: textStyle),
            SizedBox(width: widget.iconSpacing),
            Icon(widget.icon, size: widget.iconSize, color: ic),
          ],
        );
      } else {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: widget.iconSize, color: ic),
            SizedBox(width: widget.iconSpacing),
            Text(widget.label, style: textStyle),
          ],
        );
      }
    } else {
      content = Text(widget.label, style: textStyle);
    }

    // ── container ────────────────────────────────────────────────────────

    Widget btn = MouseRegion(
      cursor:
          isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: isEnabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: widget.height,
          padding: EdgeInsets.symmetric(
            horizontal: widget.horizontalPadding,
            vertical: widget.verticalPadding,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: resolvedBorder != null
                ? Border.all(color: resolvedBorder, width: widget.borderWidth)
                : null,
          ),
          child: Center(child: content),
        ),
      ),
    );

    if (widget.width != null) {
      btn = SizedBox(width: widget.width, child: btn);
    }

    // ── tooltip ──────────────────────────────────────────────────────────

    if (!isEnabled && widget.tooltip != null) {
      btn = Tooltip(message: widget.tooltip!, child: btn);
    }

    return btn;
  }
}
