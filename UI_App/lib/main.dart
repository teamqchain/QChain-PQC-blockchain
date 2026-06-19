import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';
import 'package:qwallet_mobileapp/theme/app_theme.dart';


Future<void> main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
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
