import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/constants/colors.dart';
import 'package:qwallet_mobileapp/constants/data.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';
import 'package:qwallet_mobileapp/widgets/QBottomNav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  List<Credential> get _favourites =>
      dummyCredentials.where((c) => c.status == 'Valid').take(2).toList();

  int get _validCount =>
      dummyCredentials.where((c) => c.status == 'Valid').length;
  int get _suspendedCount =>
      dummyCredentials.where((c) => c.status == 'Suspended').length;
  int get _revokedCount =>
      dummyCredentials.where((c) => c.status == 'Revoked').length;
  int get _expiryCount =>
      dummyCredentials.where((c) => c.status == 'Expired').length;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          _HeroBox(
            validCount: _validCount,
            suspendedCount: _suspendedCount,
            revokedCount: _revokedCount,
            expiryCount: _expiryCount,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Favourites', onSeeAll: () {}),
                  const SizedBox(height: 14),
                  ..._favourites.map(
                    (cred) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FavouriteCard(cred: cred),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Recent Activity', onSeeAll: () {}),
                  const SizedBox(height: 14),
                  ...dummyActivity
                      .take(2)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ActivityCard(item: item),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── HERO BOX ────────────────────────────────────────────────────────────────

class _HeroBox extends StatefulWidget {
  final int validCount;
  final int suspendedCount;
  final int revokedCount;
  final int expiryCount;

  const _HeroBox({
    required this.validCount,
    required this.suspendedCount,
    required this.revokedCount,
    required this.expiryCount,
  });

  @override
  State<_HeroBox> createState() => _HeroBoxState();
}

// ✅ SingleTickerProviderStateMixin is what was missing
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
          // ── Row: Avatar + Greeting + Bell ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF222222),
                  border: Border.all(color: const Color(0xFF444444), width: 2),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'A',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Greeting + Name
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good Morning!',
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ahmed Salih',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),

              // Bell Icon
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

          // ── Active Badge with blinking dot ──
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
              crossAxisAlignment: CrossAxisAlignment.center,
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
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // const SizedBox(height: 16),

          // ── Stats 2×2 Grid ──
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 12),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.8,
            children: [
              _StatTile(
                label: 'Valid',
                count: widget.validCount,
                color: Colors.green
              ),
              _StatTile(
                label: 'Suspended',
                count: widget.suspendedCount,
                color: Colors.orange,
              ),
              _StatTile(
                label: 'Revoked',
                count: widget.revokedCount,
                color: Colors.red,
              ),
              _StatTile(
                label: 'Expired',
                count: widget.revokedCount,
                color: Colors.grey,
              ),
            ],
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
      child: Row(
        children: [
          // Container(
          //   width: 8,
          //   height: 8,
          //   decoration: BoxDecoration(
          //     shape: BoxShape.circle,
          //     color: color,
          //     boxShadow: [
          //       BoxShadow(
          //         color: color.withOpacity(0.5),
          //         blurRadius: 5,
          //         spreadRadius: 1,
          //       ),
          //     ],
          //   ),
          // ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ],
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
          child: const Text(
            'See all →',
            style: TextStyle(
              color: qSub,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── FAVOURITE CARD ──────────────────────────────────────────────────────────

class _FavouriteCard extends StatelessWidget {
  final Credential cred;

  const _FavouriteCard({required this.cred});

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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            alignment: Alignment.center,
            child: Text(cred.icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cred.name,
                  style: const TextStyle(
                    color: Color(0xFF000000),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${cred.issuer} · ${cred.issued}',
                  style: const TextStyle(color: qSub, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.star, color: Colors.amber, size: 20),
        ],
      ),
    );
  }
}

// ─── ACTIVITY CARD ───────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final ActivityItem item;

  const _ActivityCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isReceived = item.icons == Icons.download;

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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF000000),
            ),
            alignment: Alignment.center,
            child: Icon(
              isReceived ? Icons.arrow_downward : Icons.arrow_upward,
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
                  item.text,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.time,
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
