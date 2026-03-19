import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    primary: Color(0xFFFFFFFF),
    secondary: Color(0xFFCCCCCC),
    surface: Color(0xFF000000),
    onSurface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF000000),
  ),
  scaffoldBackgroundColor: const Color(0xFFFFFFFF),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF000000),
    foregroundColor: Color(0xFFFFFFFF),
    elevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    iconTheme: IconThemeData(color: Color(0xFFFFFFFF)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFFFFFFF),
      foregroundColor: const Color(0xFF000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      minimumSize: const Size(double.infinity, 54),
      elevation: 0,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: const Color(0xFF000000)),
  ),
  cardTheme: const CardThemeData(color: Color(0xFFFFFFFF)),
  dividerColor: const Color(0xFFE5E5E5),
);

ThemeData darkMode = ThemeData(
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF000000),
    secondary: Color(0xFF555555),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF000000),
    onPrimary: Color(0xFFFFFFFF),
  ),
  scaffoldBackgroundColor: const Color(0xFFFFFFFF),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFFFFFFF),
    foregroundColor: Color(0xFF000000),
    elevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle.dark,
    iconTheme: IconThemeData(color: Color(0xFF000000)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF000000),
      foregroundColor: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      minimumSize: const Size(double.infinity, 54),
      elevation: 0,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: const Color(0xFF000000)),
  ),
  cardTheme: const CardThemeData(color: Color(0xFFFFFFFF)),
  dialogTheme: const DialogThemeData(backgroundColor: Color(0xFFFFFFFF)),
  dividerColor: const Color(0xFFE0E0E0),
  listTileTheme: const ListTileThemeData(
    textColor: Color(0xFF000000),
    iconColor: Color(0xFF555555),
  ),
);
