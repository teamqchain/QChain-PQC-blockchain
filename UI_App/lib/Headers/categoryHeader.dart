import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';
import 'package:qwallet_mobileapp/widgets/wallet_category.dart';

class Header extends StatelessWidget {
  final WalletCategory category;
  final bool isStackView;
  final VoidCallback onToggleView;
  final String currentFilter;
  final ValueChanged<String> onFilterChanged;

  const Header({
    super.key,
    required this.category,
    required this.isStackView,
    required this.onToggleView,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  // Maps the backend status string to a readable UI label
  String get _filterName {
    switch (currentFilter) {
      case 'active':
        return 'Valid Only';
      case 'expired':
        return 'Expired';
      case 'suspended':
        return 'Suspended';
      case 'revoked':
        return 'Revoked';
      default:
        return 'All Docs';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 16,
        24,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1A1A1A),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),

              // Actions Row: Filter + View Toggle
              Row(
                children: [
                  // 1. Status Filter Dropdown
                  PopupMenuButton<String>(
                    onSelected: onFilterChanged,
                    color: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    offset: const Offset(0, 45),
                    itemBuilder: (context) => [
                      _buildMenuItem('active', 'Valid Only'),
                      _buildMenuItem('all', 'All Documents'),
                      _buildMenuItem('expired', 'Expired'),
                      _buildMenuItem('suspended', 'Suspended'),
                      _buildMenuItem('revoked', 'Revoked'),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.filter_list,
                            color: Colors.white,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _filterName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // 2. View Toggle Button
                  GestureDetector(
                    onTap: onToggleView,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1A1A1A),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isStackView
                            ? Icons.view_agenda_rounded
                            : Icons.layers_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Category Title
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                alignment: Alignment.center,
                child: Icon(category.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, String text) {
    final isSelected = currentFilter == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: isSelected ? Colors.white : const Color(0xFF555555),
            size: 16,
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFFAAAAAA),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
