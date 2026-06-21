import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/appButton.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';

class ExportDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final List<String> formats;
  final void Function(String format)? onExport;

  const ExportDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.formats = const ['XLSX', 'PDF', 'JSON'], // Default has all 3 options
    this.onExport,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  late String _selected;

  // Stores the UI definitions for the 3 options
  static const _kFormats = {
    'XLSX': (
      icon: Icons.table_chart_outlined,
      description: 'Spreadsheet — ideal for analysis',
    ),
    'PDF': (
      icon: Icons.picture_as_pdf_outlined,
      description: 'Formal compliance report',
    ),
    'JSON': (
      icon: Icons.data_object_rounded,
      description: 'Machine-readable — ideal for integrations',
    ),
  };

  @override
  void initState() {
    super.initState();
    // Default selection to the first available format in the list
    _selected = widget.formats.isNotEmpty ? widget.formats.first : 'PDF';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 40,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.accentColor.withOpacity(0.14),
                      border: Border.all(
                        color: widget.accentColor.withOpacity(0.4),
                      ),
                    ),
                    child: Icon(
                      Icons.download_rounded,
                      size: 17,
                      color: widget.accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: AppTextStyles.navLabelActive.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: AppTextStyles.bodyTiny.copyWith(
                            fontSize: 11,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Format options ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELECT FORMAT',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: AppColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...widget.formats.map((fKey) {
                    final fDef = _kFormats[fKey];
                    if (fDef == null)
                      return const SizedBox.shrink(); // Failsafe
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FormatOption(
                        value: fKey,
                        icon: fDef.icon,
                        description: fDef.description,
                        accentColor: widget.accentColor,
                        selected: _selected == fKey,
                        onTap: () => setState(() => _selected = fKey),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // ── Buttons ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancel',
                      showBorder: true,
                      borderColor: AppColors.border,
                      hoverColor: AppColors.surfaceHover,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      icon: Icons.download_rounded,
                      label: 'Export as $_selected',
                      backgroundColor: widget.accentColor,
                      hoverColor: widget.accentColor.withOpacity(0.82),
                      onTap: () {
                        if (widget.onExport != null) {
                          widget.onExport!(_selected);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FORMAT OPTION ROW ────────────────────────────────────────────────────────

class _FormatOption extends StatefulWidget {
  final String value;
  final IconData icon;
  final String description;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;

  const _FormatOption({
    required this.value,
    required this.icon,
    required this.description,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FormatOption> createState() => _FormatOptionState();
}

class _FormatOptionState extends State<_FormatOption> {
  bool _h = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: widget.selected
              ? widget.accentColor.withOpacity(0.09)
              : _h
              ? AppColors.surfaceHover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.selected
                ? widget.accentColor.withOpacity(0.4)
                : AppColors.border,
            width: widget.selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: widget.accentColor.withOpacity(
                  widget.selected ? 0.15 : 0.08,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(widget.icon, size: 17, color: widget.accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: widget.selected
                          ? widget.accentColor
                          : AppColors.text,
                    ),
                  ),
                  Text(
                    widget.description,
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 11,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.selected)
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: widget.accentColor,
              ),
          ],
        ),
      ),
    ),
  );
}
