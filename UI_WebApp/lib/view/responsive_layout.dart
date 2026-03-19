import 'package:flutter/material.dart';

// ─── BREAKPOINTS ──────────────────────────────────────────────────────────────
// Large  : width >= 900  → persistent sidebar, multi-column content
// Small  : width <  900  → hamburger + drawer, single-column content

abstract class LayoutBreakpoints {
  static const double small = 910;
}

bool isSmallScreen(BuildContext context) =>
    MediaQuery.of(context).size.width < LayoutBreakpoints.small;

// ─── RESPONSIVE LAYOUT WRAPPER ────────────────────────────────────────────────
//
// Usage in any screen:
//
//   ResponsiveLayout(
//     sidebar: AppSidebar(variant: _variant),
//     topBar:  AppTopBar(variant: _variant),
//     body:    YourPageContent(),
//     drawerKey: _drawerKey,       // pass your GlobalKey<ScaffoldState>
//   )
//
// On large screens: sidebar is always visible on the left.
// On small screens: sidebar becomes a Drawer opened by a hamburger button
//                   that is injected into the top bar automatically.

class ResponsiveLayout extends StatelessWidget {
  final Widget sidebar;
  final PreferredSizeWidget topBar;
  final Widget body;
  final GlobalKey<ScaffoldState> scaffoldKey;

  const ResponsiveLayout({
    super.key,
    required this.sidebar,
    required this.topBar,
    required this.body,
    required this.scaffoldKey,
  });

  @override
  Widget build(BuildContext context) {
    final small = isSmallScreen(context);

    if (small) {
      // ── Small screen: Scaffold with Drawer ───────────────────────────────
      return Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.transparent,
        // Sidebar slides in as a drawer
        drawer: Drawer(
          width: 220,
          backgroundColor: Colors.transparent,
          child: sidebar,
        ),
        // Top bar is provided as-is; hamburger is separate (see AppTopBar)
        appBar: _HamburgerTopBar(
          scaffoldKey: scaffoldKey,
          originalTopBar: topBar,
        ),
        body: body,
      );
    } else {
      // ── Large screen: persistent sidebar ─────────────────────────────────
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: topBar,
        body: Row(
          children: [
            sidebar,
            Expanded(child: body),
          ],
        ),
      );
    }
  }
}

// ─── HAMBURGER TOP BAR WRAPPER ────────────────────────────────────────────────
// Wraps the existing AppTopBar and injects a hamburger icon on the left
// on small screens. This means AppTopBar itself never needs to know about
// screen size — the wrapper handles it.

class _HamburgerTopBar extends StatelessWidget implements PreferredSizeWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final PreferredSizeWidget originalTopBar;

  const _HamburgerTopBar({
    required this.scaffoldKey,
    required this.originalTopBar,
  });

  @override
  Size get preferredSize => originalTopBar.preferredSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The original top bar fills the full width
        originalTopBar,
        // Hamburger button overlaid on the left
        Positioned(
          left: 12,
          top: 0,
          bottom: 0,
          child: Center(
            child: _HamburgerButton(
              onTap: () => scaffoldKey.currentState?.openDrawer(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── HAMBURGER BUTTON ─────────────────────────────────────────────────────────

class _HamburgerButton extends StatefulWidget {
  final VoidCallback onTap;
  const _HamburgerButton({required this.onTap});

  @override
  State<_HamburgerButton> createState() => _HamburgerButtonState();
}

class _HamburgerButtonState extends State<_HamburgerButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF1A1A1A) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.menu_rounded,
            color: Color(0xFF888888),
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ─── RESPONSIVE CONTENT WRAPPER ───────────────────────────────────────────────
// Use this inside any page that has side-by-side columns on large screens
// and wants them stacked vertically on small screens.
//
// Usage:
//   ResponsiveColumns(
//     left:  LeftWidget(),
//     right: RightWidget(),
//   )

class ResponsiveColumns extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double spacing;

  const ResponsiveColumns({
    super.key,
    required this.left,
    required this.right,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final small = isSmallScreen(context);

    if (small) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          left,
          SizedBox(height: spacing),
          right,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        SizedBox(width: spacing),
        Expanded(child: right),
      ],
    );
  }
}
