import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/Headers/QPageTitle.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';
import 'package:qwallet_mobileapp/widgets/QSearchBar.dart';

class WalletHeader extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int totalDocs;
  final bool isLoading; // <-- ADD THIS

  const WalletHeader({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.totalDocs,
    required this.isLoading, // <-- ADD THIS
  });

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
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              QPageTitle(
                mainTitle: 'My Wallet',
                subTitle: 'All your credentials, organised',
              ),
              // ─── SKELETON OR ACTUAL BADGE ───
              isLoading
                  ? Container(
                      width: 110,
                      height: 28,
                      decoration: BoxDecoration(
                        color: qAccent, // Dark grey placeholder
                        borderRadius: BorderRadius.circular(20),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: qAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: qValid,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$totalDocs Credential${totalDocs != 1 ? 's' : ''}', // Pluralize "Credential
                            style: const TextStyle(
                              color: qSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 20),
          QSearchBar(
            controller: controller,
            onChanged: onChanged,
            textInside: 'Search credentials...',
          ),
        ],
      ),
    );
  }
}
