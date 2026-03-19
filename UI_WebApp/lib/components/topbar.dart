import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/dashboard_Model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/view/responsive_layout.dart';
import 'package:qportal_webapp/widgets/dashboard_widgets.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final DashboardVariant variant;
  const AppTopBar({super.key, required this.variant});

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      color: const Color(0xFF080808),
      padding: EdgeInsets.only(
        left: isSmallScreen(context) ? 56 : 24,
        right: 24,
      ),
      child: Row(
        children: [
          const Spacer(),


          // Org name + badges

          if(!isSmallScreen(context))...[
           Row(
              children: [
                Text(
                  'University of Sharjah',
                  style: AppTextStyles.bodyTiny.copyWith(fontSize: 11),
                ),
                const SizedBox(width: 10),

                if (variant.canIssue)
                  CapabilityBadge(
                    label: 'ISSUER',
                    color: AppColors.issuingLight,
                    bg: AppColors.issuingAccent.withOpacity(0.2),
                  )
                else if (variant.canVerify)
                  CapabilityBadge(
                    label: 'VERIFIER',
                    color: AppColors.verifyingLight,
                    bg: AppColors.verifyingAccent.withOpacity(0.2),
                  )
                else
                  CapabilityBadge(
                    label: 'IT ADMIN',
                    color: AppColors.adminLight,
                    bg: AppColors.adminAccent.withOpacity(0.2),
                  ),
              ],
            ),
          ] else ...[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (variant.canIssue)
                      CapabilityBadge(
                        label: 'ISSUER',
                        color: AppColors.issuingLight,
                        bg: AppColors.issuingAccent.withOpacity(0.2),
                      )
                    else
                      CapabilityBadge(
                        label: 'VERIFIER',
                        color: AppColors.verifyingLight,
                        bg: AppColors.verifyingAccent.withOpacity(0.2),
                      ),
                  ],
                ),
                const SizedBox(height: 2,),
                Text(
                  'University of Sharjah',
                  style: AppTextStyles.bodyTiny.copyWith(fontSize: 11),
                ),
                
              ],
            )
          ],

          
          

          SizedBox(width: isSmallScreen(context) ? 12 : 20),

          // Notification bell
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: AppColors.revoked,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '3',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

           SizedBox(width:isSmallScreen(context)? 12:16 ),

          // Search bar
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding:  EdgeInsets.symmetric(horizontal: isSmallScreen(context) ? 7 : 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSmallScreen(context,))
                    Icon(Icons.search, color: AppColors.textDim, size: 16) // Hide placeholder text on small screens to save space
                  else ...[
                    const Icon(Icons.search, color: AppColors.textDim, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Search',
                      style: AppTextStyles.bodyTiny.copyWith(
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
