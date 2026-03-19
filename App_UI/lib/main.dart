import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';
import 'package:qwallet_mobileapp/theme/app_theme.dart';


Future<void> main() async {
  // WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // usePathUrlStrategy();

  // Initialize theme controller
  // Get.put(ThemeController());


  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'QPortal',
      debugShowCheckedModeBanner: true,
      theme: lightMode,
      darkTheme: darkMode,
      themeMode: ThemeMode.dark,
      initialRoute: Routes.SPLASH,
      getPages: AppPages.routes,

      // ✅ Global transition for all routes
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 200),
    );
  }
}
