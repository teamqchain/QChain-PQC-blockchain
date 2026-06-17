import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/components/shimmerWave.dart';
import 'package:qwallet_mobileapp/model/activity_model.dart';
import 'package:qwallet_mobileapp/model/credential_model.dart';
import 'package:qwallet_mobileapp/model/subscription_model.dart';
import 'package:qwallet_mobileapp/screens/activity_screen.dart';
import 'package:qwallet_mobileapp/screens/add_document_screen.dart';
import 'package:qwallet_mobileapp/services/activity_controller.dart';
import 'package:qwallet_mobileapp/services/add_document_controller.dart';
import 'package:qwallet_mobileapp/utils/logger.dart';
import 'package:qwallet_mobileapp/services/manage_subscriptions_controller.dart';
import 'package:qwallet_mobileapp/services/wallet_controller.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';
import 'package:qwallet_mobileapp/routes/main_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WalletController controller = Get.put(WalletController());
  final ActivityController activityController = Get.put(ActivityController());
  final AddDocumentController addDocumentController = Get.put(
    AddDocumentController(),
  );
  final ManageSubscriptionsController subscriptionController = Get.put(
    ManageSubscriptionsController(),
  );

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: qBg,
      body: Obx(() {
        // Sync loading and error states across both controllers
        final isLoading =
            controller.isLoading.value ||
            activityController.isLoading.value ||
            addDocumentController.isLoading.value ||
            subscriptionController.isLoading.value;
        final hasError =
            controller.errorMessage.isNotEmpty ||
            activityController.errorMessage.isNotEmpty ||
            addDocumentController.errorMessage.isNotEmpty ||
            subscriptionController.errorMessage.isNotEmpty;

        return Column(
          children: [
            isLoading
                ? const _SkeletonHeroBox()
                : _HeroBox(
                    userName: controller.credentials.isNotEmpty
                        ? controller.credentials.first.holderName
                        : 'Holder',
                    validCount: controller.validCount,
                    suspendedCount: controller.suspendedCount,
                    revokedCount: controller.revokedCount,
                    expiryCount: controller.expiryCount,
                  ),

            Expanded(
              child: hasError && !isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            controller.errorMessage.value.isNotEmpty
                                ? controller.errorMessage.value
                                : activityController.errorMessage.value,
                            style: const TextStyle(color: qRed),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () {
                              controller.fetchMyCredentials();
                              activityController.fetchActivity();
                              addDocumentController.loadCatalog();
                              subscriptionController.fetchSubscriptions();
                            },
                            child: const Text(
                              "Retry",
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: Colors.black,
                      onRefresh: () async {
                        // Refresh both on pull-down
                        await controller.fetchMyCredentials();
                        await activityController.fetchActivity();
                        await addDocumentController.loadCatalog();
                        await subscriptionController.fetchSubscriptions();

                        if (controller.errorMessage.value.isNotEmpty ||
                            activityController.errorMessage.value.isNotEmpty ||
                            addDocumentController
                                .errorMessage
                                .value
                                .isNotEmpty ||
                            subscriptionController
                                .errorMessage
                                .value
                                .isNotEmpty) {
                          Get.snackbar(
                            'Network Error',
                            controller.errorMessage.value.isNotEmpty ? controller.errorMessage.value
                                : activityController.errorMessage.value.isNotEmpty? activityController.errorMessage.value
                                : addDocumentController.errorMessage.value.isNotEmpty ? addDocumentController.errorMessage.value
                                : subscriptionController.errorMessage.value.isNotEmpty ? subscriptionController.errorMessage.value : 'An unknown error occurred',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: qRed,
                            colorText: qSecondary,
                          );
                        }
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        child: isLoading
                            ? const _SkeletonList()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // --- UPDATED RECENT ACTIVITY SECTION ---
                                  _SectionHeader(
                                    title: 'Recent Activity', // Changed title
                                    onSeeAll: () {
                                      context
                                          .findAncestorStateOfType<
                                            MainShellState
                                          >()
                                          ?.switchTab(3);
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  if (activityController.activities.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      child: Text(
                                        "No recent activity found.",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  // Take strictly the first 2 records from the ActivityController
                                  ...activityController.activities
                                      .take(2)
                                      .map(
                                        (activity) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: _ActivityCard(
                                            activity: activity,
                                          ), // Pass ActivityModel
                                        ),
                                      ),

                                  const SizedBox(height: 24),
                                  _SectionHeader(
                                    title: 'Favourites',
                                    onSeeAll: () {},
                                  ),
                                  const SizedBox(height: 14),
                                  if (controller.favourites.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      child: Text(
                                        "No active credentials found.",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ...controller.favourites.map(
                                    (cred) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: GestureDetector(
                                        onTap: () => Get.toNamed(
                                          Routes.DETAIL,
                                          arguments: cred,
                                        ),
                                        child: _FavouriteCard(cred: cred),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }
}

// ─── HERO BOX ────────────────────────────────────────────────────────────────

class _HeroBox extends StatefulWidget {
  final String userName;
  final int validCount;
  final int suspendedCount;
  final int revokedCount;
  final int expiryCount;

  const _HeroBox({
    required this.userName,
    required this.validCount,
    required this.suspendedCount,
    required this.revokedCount,
    required this.expiryCount,
  });

  @override
  State<_HeroBox> createState() => _HeroBoxState();
}

class _HeroBoxState extends State<_HeroBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _fade = Tween(begin: 0.3, end: 1.0).animate(_blink);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF22C55E);

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
        MediaQuery.of(context).padding.top + 20,
        24,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF222222),
                  border: Border.all(color: const Color(0xFF444444), width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.userName.isNotEmpty
                      ? widget.userName[0].toUpperCase()
                      : 'H',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Good Morning!',
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.userName.split(' ').first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A1A1A),
                      border: Border.all(
                        color: const Color(0xFF333333),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  Positioned(
                    right: 2,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                        border: Border.all(
                          color: const Color(0xFF000000),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF22C55E).withOpacity(0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _fade,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: green,
                      boxShadow: [
                        BoxShadow(color: green, blurRadius: 6, spreadRadius: 1),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Identity Active',
                  style: TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Valid',
                        count: widget.validCount,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        label: 'Suspended',
                        count: widget.suspendedCount,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Revoked',
                        count: widget.revokedCount,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        label: 'Expired',
                        count: widget.expiryCount,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── STAT TILE ───────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatTile({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SECTION HEADER ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;

  const _SectionHeader({required this.title, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF000000),
            fontSize: 16,
            fontFamily: "SFPro",
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        GestureDetector(
          onTap: onSeeAll,
          child: (title == 'Recent Activity')
              ? Row(
                  children: [
                    const Text(
                      'See all',
                      style: TextStyle(
                        color: qSub,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: qSub, size: 16),
                  ],
                )
              : const SizedBox.shrink(), // Hide "See all" for Favourites
        ),
      ],
    );
  }
}

// ─── FAVOURITE CARD ──────────────────────────────────────────────────────────

class _FavouriteCard extends StatelessWidget {
  final CredentialModel cred;

  const _FavouriteCard({required this.cred});

  @override
  Widget build(BuildContext context) {
    // Find the existing controller
    final WalletController controller = Get.find<WalletController>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBEBEB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cred.cardColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cred.cardColor.withOpacity(0.2)),
            ),
            alignment: Alignment.center,
            child: Icon(cred.icon, size: 22, color: cred.cardColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cred.credentialType,
                  style: const TextStyle(
                    color: Color(0xFF000000),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${cred.issuedBy} · ${cred.formattedIssueDate}',
                  style: const TextStyle(color: qSub, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // --- UPDATED: Make the star tappable ---
          GestureDetector(
            onTap: () {
              controller.toggleFavoriteStatus(cred);
            },
            // Added a subtle hit-box expansion for easier tapping
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.star, color: Colors.amber, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ACTIVITY CARD ───────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final ActivityModel activity;

  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBEBEB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  activity.iconBgColor, // Dynamically use activity icon color
            ),
            alignment: Alignment.center,
            child: Icon(
              activity.icon, // Dynamically use activity icon
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.credentialID, // E.g., "Issued Bachelor of Science"
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.actionText, // E.g., "Issued Bachelor of Science"
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.timeAgo, // E.g., "2 hours ago"
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SKELETON LOADING WIDGETS ────────────────────────────────────────────────

class _SkeletonHeroBox extends StatelessWidget {
  const _SkeletonHeroBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF000000), // Background stays solidly black
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 20,
        24,
        28,
      ),
      // Wrap the contents in the shimmer wave
      child: ShimmerWave(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar Placeholder
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(width: 14),
                // Text Placeholders
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 140,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                // Static Notification Bell
                Stack(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A1A1A),
                        border: Border.all(
                          color: const Color(0xFF333333),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    Positioned(
                      right: 2,
                      top: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                          border: Border.all(
                            color: const Color(0xFF000000),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Identity Pill Placeholder
            Container(
              width: double.infinity,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
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

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Headers remain solid, they don't need to shimmer
        _SectionHeader(title: 'Favourites', onSeeAll: () {}),
        const SizedBox(height: 14),
        // Cards get the wave effect
        ShimmerWave(child: SkeletonIssuerTile(isHome: true)),
        const SizedBox(height: 10),
        ShimmerWave(child: SkeletonIssuerTile(isHome: true)),
        const SizedBox(height: 24),

        _SectionHeader(title: 'Recent Activity', onSeeAll: () {}),
        const SizedBox(height: 14),
        ShimmerWave(child: SkeletonActivityTile(myheight: 15)),
      ],
    );
  }
}
