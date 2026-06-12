import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';
import 'package:qwallet_mobileapp/widgets/wallet_category.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';

/// A single grid tile on the wallet screen.
/// Tapping it navigates to CategoryDocumentsScreen for that category.
class CategoryTile extends StatelessWidget {
  final WalletCategory category;

  const CategoryTile({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(Routes.CATEGORY, arguments: category),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEBEBEB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon box + count badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    category.icon,
                    color: qPrimary,
                    size: 22,
                  ),
                ),
                Container(
                  // padding: const EdgeInsets.symmetric(
                  //   horizontal: 8,
                  //   vertical: 3,
                  // ),
                  // decoration: BoxDecoration(
                  //   color: const Color(0xFF000000),
                  //   borderRadius: BorderRadius.circular(20),
                  // ),
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 4, right: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF000000),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${category.count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            Text(
              category.title,
              style: const TextStyle(
                color: Color(0xFF000000),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              category.subtitle,
              style: const TextStyle(
                color: Color(0xFF999999),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
