
import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/screens/activity_screen.dart';
import 'package:qwallet_mobileapp/screens/add_document_screen.dart';
import 'package:qwallet_mobileapp/screens/home_screen.dart';
import 'package:qwallet_mobileapp/screens/settings_screen.dart';
import 'package:qwallet_mobileapp/screens/wallet_screen.dart';
import 'package:qwallet_mobileapp/routes/QBottomNav.dart';
// shell/main_shell.dart
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _index = 0;

  void switchTab(int index) {
    setState(() => _index = index);
  }

  // All your tab screens live here, pre-built
  static const _screens = [
    HomeScreen(),
    WalletScreen(),
    AddDocumentScreen(), 
    ActivityScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(
          key: ValueKey(_index), // tells AnimatedSwitcher the child changed
          child: _screens[_index],
        ),
      ),
      bottomNavigationBar: QBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
