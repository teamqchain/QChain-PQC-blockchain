import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qwallet_mobileapp/constants/colors.dart';
import 'package:qwallet_mobileapp/constants/data.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _query = '';
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(
      () => setState(() => _query = _controller.text.toLowerCase().trim()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<ActivityItem> get _filtered => _query.isEmpty
      ? dummyActivity
      : dummyActivity
            .where((a) => a.text.toLowerCase().contains(_query))
            .toList();

  // Group activity items by date label (uses item.time as the key)
  Map<String, List<ActivityItem>> get _grouped {
    final map = <String, List<ActivityItem>>{};
    for (final item in _filtered) {
      // Derive a simple day-group from the time string
      final key = _dayLabel(item.time);
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  String _dayLabel(String time) {
    if (time.toLowerCase().contains('today')) return 'Today';
    if (time.toLowerCase().contains('yesterday')) return 'Yesterday';
    if (time.toLowerCase().contains('min') ||
        time.toLowerCase().contains('hour'))
      return 'Today';
    return 'Earlier';
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    final grouped = _grouped;
    final groups = grouped.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          // ── BLACK HERO BOX ──────────────────────────────────────────
          _ActivityHeroBox(controller: _controller, query: _query),

          // ── BODY ────────────────────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? _EmptyState(query: _query)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    itemCount: groups.fold<int>(
                      0,
                      (sum, g) => sum + 1 + grouped[g]!.length,
                    ),
                    itemBuilder: (context, index) {
                      // Flatten groups into a single list with headers
                      int cursor = 0;
                      for (final group in groups) {
                        if (index == cursor) {
                          return _GroupHeader(label: group);
                        }
                        cursor++;
                        final items = grouped[group]!;
                        if (index < cursor + items.length) {
                          final item = items[index - cursor];
                          final isLast = index == cursor + items.length - 1;
                          return _ActivityTile(item: item, isLast: isLast);
                        }
                        cursor += items.length;
                      }
                      return const SizedBox();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO BOX
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityHeroBox extends StatelessWidget {
  final TextEditingController controller;
  final String query;

  const _ActivityHeroBox({required this.controller, required this.query});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'History',
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Activity',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              // Filter chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.tune, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Filter',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Search bar
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: qBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2E2E2E)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.search,
                  color: Colors.black.withOpacity(0.35),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search activity…',
                      hintStyle: TextStyle(
                        color: Colors.black.withOpacity(0.25),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    cursorColor: Colors.white,
                  ),
                ),
                if (query.isNotEmpty)
                  GestureDetector(
                    onTap: () => controller.clear(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        Icons.close,
                        color: Colors.black.withOpacity(0.4),
                        size: 16,
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// GROUP HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFAAAAAA),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY TILE
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final ActivityItem item;
  final bool isLast;

  const _ActivityTile({required this.item, required this.isLast});

  Color get _iconBg {
    if (item.icons == Icons.download) return const Color(0xFF16A34A);
    if (item.icons == Icons.upload) return const Color(0xFF2563EB);
    if (item.icons == Icons.share) return const Color(0xFF7C3AED);
    return const Color(0xFF111111);
  }

  IconData get _dirIcon {
    if (item.icons == Icons.download) return Icons.arrow_downward;
    if (item.icons == Icons.upload) return Icons.arrow_upward;
    return item.icons;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 16 : 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEBEBEB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _iconBg),
              alignment: Alignment.center,
              child: Icon(_dirIcon, color: Colors.white, size: 17),
            ),

            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
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

            // Chevron
            const Icon(Icons.chevron_right, color: Color(0xFFDDDDDD), size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              query.isNotEmpty ? '🔍' : '📭',
              style: const TextStyle(fontSize: 32),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            query.isNotEmpty ? 'No results found' : 'No activity yet',
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            query.isNotEmpty
                ? 'Nothing matches "$query"'
                : 'Your credential activity will appear here',
            style: const TextStyle(
              color: Color(0xFF999999),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
