import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';

class PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int rowsPerPage;
  final int totalRows;
  final void Function(int) onPageChanged;
  final void Function(int) onRowsPerPageChanged;
  final Color accentColor;

  const PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.rowsPerPage,
    required this.totalRows,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
    required this.accentColor,
  });

  // Build the list of page numbers to show (with ellipsis gaps).
  List<int?> get _pageNumbers {
    if (totalPages <= 7) return List.generate(totalPages, (i) => i + 1);

    final result = <int?>[];
    result.add(1);

    if (currentPage > 4) result.add(null); // left ellipsis

    final start = (currentPage - 2).clamp(2, totalPages - 1);
    final end = (currentPage + 2).clamp(2, totalPages - 1);
    for (int i = start; i <= end; i++) {
      result.add(i);
    }

    if (currentPage < totalPages - 3) result.add(null); // right ellipsis

    result.add(totalPages);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final start = totalRows == 0 ? 0 : (currentPage - 1) * rowsPerPage + 1;
    final end = (currentPage * rowsPerPage).clamp(0, totalRows);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── Page numbers centred ──────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Prev arrow
            _PageBtn(
              enabled: currentPage > 1,
              onTap: () => onPageChanged(currentPage - 1),
              child: const Icon(Icons.chevron_left, size: 16),
              accentColor: accentColor,
            ),
            const SizedBox(width: 4),

            // Page number chips
            ..._pageNumbers.map((p) {
              if (p == null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    '…',
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 12,
                      color: AppColors.textDim,
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _PageBtn(
                  active: p == currentPage,
                  onTap: () => onPageChanged(p),
                  accentColor: accentColor,
                  child: Text(
                    '$p',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: p == currentPage
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: p == currentPage
                          ? Colors.white
                          : AppColors.textDim,
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(width: 4),
            // Next arrow
            _PageBtn(
              enabled: currentPage < totalPages,
              onTap: () => onPageChanged(currentPage + 1),
              accentColor: accentColor,
              child: const Icon(Icons.chevron_right, size: 16),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ── Rows info + rows-per-page selector ───────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              totalRows == 0
                  ? 'No results'
                  : 'Showing $start–$end of $totalRows',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                color: AppColors.textDim,
              ),
            ),
            const SizedBox(width: 20),
            Text(
              'Rows per page:',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                color: AppColors.textDim,
              ),
            ),
            const SizedBox(width: 8),
            ...[25, 50, 100].map(
              (n) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _RowsPerPageChip(
                  value: n,
                  selected: n == rowsPerPage,
                  onTap: () => onRowsPerPageChanged(n),
                  accentColor: accentColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PageBtn extends StatefulWidget {
  final Widget child;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  final Color accentColor;

  const _PageBtn({
    required this.child,
    required this.onTap,
    required this.accentColor,
    this.active = false,
    this.enabled = true,
  });

  @override
  State<_PageBtn> createState() => _PageBtnState();
}

class _PageBtnState extends State<_PageBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.active;
    final isEnabled = widget.enabled;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: isEnabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? widget.accentColor
                : _h && isEnabled
                ? AppColors.surfaceHover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isActive
                ? null
                : Border.all(
                    color: _h && isEnabled
                        ? AppColors.border
                        : Colors.transparent,
                  ),
          ),
          child: Opacity(opacity: isEnabled ? 1.0 : 0.3, child: widget.child),
        ),
      ),
    );
  }
}

class _RowsPerPageChip extends StatefulWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;
  final Color accentColor;

  const _RowsPerPageChip({
    required this.value,
    required this.selected,
    required this.onTap,
    required this.accentColor,
  });

  @override
  State<_RowsPerPageChip> createState() => _RowsPerPageChipState();
}

class _RowsPerPageChipState extends State<_RowsPerPageChip> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: widget.selected
              ? widget.accentColor.withOpacity(0.18)
              : _h
              ? AppColors.surfaceHover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: widget.selected
                ? widget.accentColor.withOpacity(0.5)
                : AppColors.border,
          ),
        ),
        child: Text(
          '${widget.value}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w400,
            color: widget.selected ? widget.accentColor : AppColors.textDim,
          ),
        ),
      ),
    ),
  );
}
