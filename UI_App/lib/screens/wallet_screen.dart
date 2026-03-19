import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/Headers/walletHeader.dart';
import 'package:qwallet_mobileapp/components/categoryTile.dart';
import 'package:qwallet_mobileapp/constants/colors.dart';
import 'package:qwallet_mobileapp/model/wallet_category.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';
import 'package:qwallet_mobileapp/widgets/QBottomNav.dart';

const List<WalletCategory> _categories = [
  WalletCategory(
    id: 'identity',
    icon: '🪪',
    title: 'Identity',
    subtitle: 'IDs & Passports',
    count: 3,
  ),
  WalletCategory(
    id: 'medical',
    icon: '🏥',
    title: 'Medical',
    subtitle: 'Health Records',
    count: 2,
  ),
  WalletCategory(
    id: 'banking',
    icon: '🏦',
    title: 'Banking',
    subtitle: 'Finance & Cards',
    count: 1,
  ),
  WalletCategory(
    id: 'education',
    icon: '🎓',
    title: 'Education',
    subtitle: 'Degrees & Certs',
    count: 4,
  ),
  WalletCategory(
    id: 'government',
    icon: '🏛️',
    title: 'Government',
    subtitle: 'Official Docs',
    count: 2,
  ),
  WalletCategory(
    id: 'professional',
    icon: '💼',
    title: 'Professional',
    subtitle: 'Work & Licenses',
    count: 3,
  ),
  WalletCategory(
    id: 'travel',
    icon: '✈️',
    title: 'Travel',
    subtitle: 'Visas & Permits',
    count: 1,
  ),
  WalletCategory(
    id: 'memberships',
    icon: '🔐',
    title: 'Memberships',
    subtitle: 'Clubs & Access',
    count: 2,
  ),
];

// ─── WALLET SCREEN ────────���───────────────────────────────────────────────────

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _navIndex = 1;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<WalletCategory> get _filtered {
    if (_query.trim().isEmpty) return _categories;
    final q = _query.toLowerCase();
    return _categories
        .where(
          (c) =>
              c.title.toLowerCase().contains(q) ||
              c.subtitle.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          // ── TOP HEADER ────────────────────────────────────────────────────
          WalletHeader(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
          ),

          // ── GRID BODY WITH SCROLLBAR ──────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? const _EmptyState()
                : Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    thickness: 6,
                    radius: const Radius.circular(10),
                    child: GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.05,
                          ),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) =>
                          CategoryTile(category: _filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
      // bottomNavigationBar: QBottomNav(
      //   currentIndex: _navIndex,
      //   onTap: (i) => setState(() => _navIndex = i),
      // ),
    );
  }
}

// ─── HEADER ───────────────────────────────────────────────────────────────────



// ─── CATEGORY TILE ────────────────────────────────────────────────────────────



// ─── EMPTY STATE ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔍', style: TextStyle(fontSize: 40)),
          SizedBox(height: 14),
          Text(
            'No categories found',
            style: TextStyle(
              color: Color(0xFF000000),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try a different search term',
            style: TextStyle(color: Color(0xFF999999), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
