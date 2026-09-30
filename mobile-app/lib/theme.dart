import 'package:flutter/material.dart';

const teal = Color(0xFF028090);
const mint = Color(0xFF02C39A);
const amber = Color(0xFFE8A33D);
const missedRed = Color(0xFFD64545);
const backgroundColor = Color(0xFFF4FAF9);
const borderColor = Color(0xFFDCECE9);

ThemeData buildMedTrackTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: teal,
    primary: teal,
    secondary: mint,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: backgroundColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: teal,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderColor),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: mint,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: mint,
      foregroundColor: Colors.white,
    ),
  );
}
