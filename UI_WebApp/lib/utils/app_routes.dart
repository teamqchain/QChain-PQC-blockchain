// import 'package:get/get.dart';
// import 'package:qportal_webapp/models/dashboard_Model.dart';
// import 'package:qportal_webapp/screens/dashboard_screen.dart';
// import 'package:qportal_webapp/screens/issue/issue_single_screen.dart';


// // ─── ROUTE NAMES ─────────────────────────────────────────────────────────────

// abstract class Routes {
//   static const LOGIN = '/login';
//   static const SIGNUP = '/signup';
//   static const DASHBOARD = '/dashboard';
//   static const ISSUE_SINGLE = '/issue/single';
//   static const ISSUE_BATCH = '/issue/batch';
//   static const ALL_CREDENTIALS = '/issue/credentials';
//   static const REVOKE_SUSPEND = '/issue/revoke';
//   static const SCHEMAS = '/issue/schemas';
//   static const ISSUING_SETTINGS = '/issue/settings';

//   // Add more portal routes below as you build them:
//   // static const ISSUE_SINGLE   = '/issue/single';
//   // static const ISSUE_BATCH    = '/issue/batch';
//   // static const ALL_CREDENTIALS = '/credentials';
//   // static const SCAN_QR        = '/verify/scan';
//   // static const MANUAL_VERIFY  = '/verify/manual';
//   // static const HISTORY        = '/verify/history';
// }

// // ─── ROUTE PAGES ─────────────────────────────────────────────────────────────

// class AppPages {
//   static final routes = [
//     // ── Dashboard (initial screen, skipping login for now) ───────────────────
//     GetPage(
//       name: Routes.DASHBOARD,
//       page: () => DashboardScreen(
//         variant: DashboardVariant.issuerOnly,
//         onVariantChanged: (_) {},
//       ),
//       transition: Transition.noTransition,
//     ),
//     GetPage(
//       name: Routes.ISSUE_SINGLE,
//       page: () => const IssueSingleScreen(),
//       transition: Transition.noTransition,
//     ),
//     // GetPage(
//     //   name: Routes.ISSUE_BATCH,
//     //   page: () => const BatchIssueScreen(),
//     //   transition: Transition.noTransition,
//     // ),
//     // GetPage(
//     //   name: Routes.ALL_CREDENTIALS,
//     //   page: () => const AllCredentialsScreen(),
//     //   transition: Transition.noTransition,
//     // ),
//     // GetPage(
//     //   name: Routes.REVOKE_SUSPEND,
//     //   page: () => const RevokeSuspendScreen(),
//     //   transition: Transition.noTransition,
//     // ),
//     // GetPage(
//     //   name: Routes.SCHEMAS,
//     //   page: () => const SchemasScreen(),
//     //   transition: Transition.noTransition,
//     // ),
//     // GetPage(
//     //   name: Routes.ISSUING_SETTINGS,
//     //   page: () => const IssuingSettingsScreen(),
//     //   transition: Transition.noTransition,
//     // ),

//     // ── Auth (implement later) ───────────────────────────────────────────────
//     // GetPage(name: Routes.LOGIN,  page: () => const LoginScreen()),
//     // GetPage(name: Routes.SIGNUP, page: () => const SignUpScreen()),
//   ];
// }
