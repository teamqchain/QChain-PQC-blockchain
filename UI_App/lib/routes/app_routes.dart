import 'package:get/get.dart';
import 'package:qwallet_mobileapp/routes/main_shell.dart';
import 'package:qwallet_mobileapp/screens/activity_screen.dart';
import 'package:qwallet_mobileapp/screens/add_document_screen.dart';
import 'package:qwallet_mobileapp/screens/category_documents_screen.dart';
import 'package:qwallet_mobileapp/screens/document_detail_screen.dart';
import 'package:qwallet_mobileapp/screens/manage_subscriptions_screen.dart';
import 'package:qwallet_mobileapp/screens/onboard_1_screen.dart';
import 'package:qwallet_mobileapp/screens/onboard_2_screen.dart';
import 'package:qwallet_mobileapp/screens/onboard_3_screen.dart';
import 'package:qwallet_mobileapp/screens/present_screen.dart';
import 'package:qwallet_mobileapp/screens/receive_screen.dart';
import 'package:qwallet_mobileapp/screens/splash_screen.dart';



// ─── ROUTE NAMES ─────────────────────────────────────────────────────────────

abstract class Routes {
  static const SPLASH = '/';
  static const ONBOARD1 = '/onboard1';
  static const ONBOARD2 = '/onboard2';
  static const ONBOARD3 = '/onboard3';

  // Shell hosts Home, Wallet, Activity, Settings tabs — one single route
  static const SHELL = '/shell';

  // Deep-link routes that push ON TOP of the shell
  static const CATEGORY = '/category-documents';
  static const DETAIL = '/detail';
  static const PRESENT = '/present';
  static const RECEIVE = '/receive';
  static const ADD = '/add-document';
  static const ACTIVITY = '/activity';
  static const SUBSCRIPTION = '/subscription';
}

// ─── ROUTE PAGES ─────────────────────────────────────────────────────────────

class AppPages {
  static final routes = [
    // ── Pre-auth ────────────────────────────────────────────────────────────
    GetPage(name: Routes.SPLASH, page: () => const SplashScreen()),
    GetPage(name: Routes.ONBOARD1, page: () => const Onboard1Screen()),
    GetPage(name: Routes.ONBOARD2, page: () => const Onboard2Screen()),
    GetPage(name: Routes.ONBOARD3, page: () => const Onboard3Screen()),

    // ── Main app shell (tabs live inside here, not as separate routes) ──────
    GetPage(
      name: Routes.SHELL,
      page: () => const MainShell(),
      transition: Transition.noTransition, // shell itself never animates in
    ),

    // ── Screens that push on top of the shell ────────────────────────────────
    GetPage(
      name: Routes.CATEGORY,
      page: () => const CategoryDocumentsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 220),
    ),
    GetPage(
      name: Routes.DETAIL,
      page: () => const DocumentDetailScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 220),
    ),
    GetPage(
      name: Routes.PRESENT,
      page: () => const PresentScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 220),
    ),
    GetPage(
      name: Routes.RECEIVE,
      page: () => const ReceiveScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 220),
    ),
    GetPage(
      name: Routes.ADD,
      page: () => const AddDocumentScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 220),
    ),
    GetPage(
      name: Routes.ACTIVITY,
      page: () => const ActivityScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 220),
    ),
    GetPage(
      name: Routes.SUBSCRIPTION,
      page: () => const ManageSubscriptionsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 220),
    ),
  ];
}
