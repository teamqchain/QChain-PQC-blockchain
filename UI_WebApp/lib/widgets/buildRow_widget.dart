import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/connection_error.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';

class BuildrowWidget<T> extends StatelessWidget {
  // State
  final String? errorMessage;
  final bool isLoading;
  final List<T> items;
  final String query; // Used to determine which empty state to show

  // Callbacks & Builders
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T item) itemBuilder;

  // Customization
  final String emptyDefaultMessage;
  final String emptySearchMessage;
  final IconData emptyDefaultIcon;
  final IconData emptySearchIcon;
  final Color accentColor;

  const BuildrowWidget({
    super.key,
    required this.errorMessage,
    required this.isLoading,
    required this.items,
    required this.query,
    required this.onRetry,
    required this.itemBuilder,
    required this.emptyDefaultMessage,
    required this.emptySearchMessage,
    this.emptyDefaultIcon = Icons.group_outlined,
    this.emptySearchIcon = Icons.search_off_rounded,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Error State
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 80.0),
        child: ConnectionErrorWidget(onRetry: onRetry),
      );
    }

    // 2. Loading State
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: accentColor));
    }

    // 3. Empty State
    if (items.isEmpty) {
      final isSearching = query.isNotEmpty;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching ? emptySearchIcon : emptyDefaultIcon,
              size: 36,
              color: AppColors.textDim,
            ),
            const SizedBox(height: 12),
            Text(
              isSearching
                  ? emptySearchMessage.replaceAll('{query}', query)
                  : emptyDefaultMessage,
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 13,
                color: AppColors.textDim,
              ),
            ),
          ],
        ),
      );
    }

    // 4. Populated List State
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          Container(height: 1, color: AppColors.border),
      itemBuilder: (context, i) => itemBuilder(context, items[i]),
    );
  }
}
