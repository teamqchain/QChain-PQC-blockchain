import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/countChip.dart';
import 'package:qportal_webapp/components/filterButton.dart';
import 'package:qportal_webapp/components/searchBar.dart';

class BuildToolBar extends StatelessWidget {
  final Set<String> selected;
  final int totalFiltered;
  final TextEditingController searchCtrl;
  final String search;
  final void Function(String p1) onSearchChanged;
  final VoidCallback onClearSearch;
  final String searchLabel;
  final String trueMessage;
  final String falseMessage;
  final Color searchColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final String? falsePluralMessage;

  final Widget? actionButton;

  const BuildToolBar({
    super.key,
    required this.selected,
    required this.totalFiltered,
    required this.searchCtrl,
    required this.search,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.searchLabel,
    required this.trueMessage,
    required this.falseMessage,
    required this.searchColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    this.falsePluralMessage,
    this.actionButton, 
  });

  @override
  Widget build(BuildContext context) {
    final selCount = selected.length;

    return Container(
      color: const Color(0xFF161616),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CountChip(
            count: (selCount > 0) ? selCount : totalFiltered,
            label: (selCount > 0) ? trueMessage : falseMessage,
            pluralLabel: (selCount > 1) ? trueMessage : falsePluralMessage,
            zeroLabel: falseMessage,
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
          const Spacer(),

          // Filter icon
          ToolbarIconBtn(
            icon: Icons.filter_list_rounded,
            tooltip: 'Filter',
            onTap: () {},
          ),
          const SizedBox(width: 6),

          // Search bar
          QSearchBar(
            controller: searchCtrl,
            query: search,
            onChanged: onSearchChanged,
            onClear: onClearSearch,
            barWidth: 240,
            searchLabel: searchLabel,
            activeColor: searchColor,
          ),

          if (actionButton != null) ...[
            const SizedBox(width: 10),
            actionButton!,
          ],
        ],
      ),
    );
  }
}
