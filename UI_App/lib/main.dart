import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';
import 'package:qwallet_mobileapp/theme/app_theme.dart';
import 'package:qwallet_mobileapp/utils/alice_inspector.dart';
import 'package:qwallet_mobileapp/utils/runtime_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Permanent so Splash and every later screen share one override slot.
  // Nothing is written here — no override means app_config.dart defaults.
  Get.put(RuntimeConfig(), permanent: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: alice.getNavigatorKey(),
      title: 'QWallet',
      debugShowCheckedModeBanner: false,
      theme: lightMode,
      darkTheme: darkMode,
      themeMode: ThemeMode.dark,
      initialRoute: Routes.SPLASH,
      getPages: AppPages.routes,
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 200),
    );
  }
}
