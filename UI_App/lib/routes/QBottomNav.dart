import 'package:flutter/material.dart';

class QBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const QBottomNav({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  static const _items = [
    (Icons.home_rounded, 'Home', '/home'),
    (Icons.account_balance_wallet_outlined, 'Wallet', '/wallet'),
    (Icons.add, 'Add', ''),
    (Icons.history_rounded, 'Activity', '/activity'),
    (Icons.person_outline, 'Profile', '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEBEBEB))),
      ),
      padding: EdgeInsets.only(
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (i) {
          final (IconData icon, String label, String route) = _items[i];
          final active = i == currentIndex;
          final isAdd = i == 2;

          // ── Add / FAB button ──────────────────────────────────────────────
          if (isAdd) {
            return GestureDetector(
              onTap: () {
                onTap(i);
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF000000),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            );
          }

          // ── Regular nav item with animated pill ──────────────────────────
          return GestureDetector(
            onTap: () {
              onTap(i);
              // if (route.isNotEmpty && route != Get.currentRoute) {
              //   Get.offAllNamed(
              //     route,
              //     predicate: (route) => false,
              //   );
              // }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF000000) : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: active
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFFBBBBBB),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: active
                        ? Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
