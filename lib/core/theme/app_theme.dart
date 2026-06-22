import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF11091F);
  static const Color backgroundSoft = Color(0xFF070A12);

  static const Color surface = Color(0xFF090E1A);
  static const Color surfaceSoft = Color(0xFF0D1424);
  static const Color surfaceLight = Color(0xFF121B2E);

  static const Color primary = Color(0xFFF5F7FF);
  static const Color secondary = Color(0xFFC4C7D8);
  static const Color muted = Color(0xFF84889A);

  static const Color border = Color(0xFF1B2740);
  static const Color divider = Color(0xFF141B2B);

  static const Color neonPink = Color(0xFFFF3FD4);
  static const Color neonBlue = Color(0xFF246BFF);
  static const Color neonCyan = Color(0xFF00E5D4);
  static const Color neonTeal = Color(0xFF00E5D4);
  static const Color neonPurple = Color(0xFF7B2CFF);
  static const Color neonGreen = Color(0xFF00D6A3);
  static const Color neonOrange = Color(0xFFFF8A1F);
  static const Color neonRed = Color(0xFFFF2B4F);

  static const Color accent = Color(0xFFDCE5FF);
  static const Color streak = Color(0xFFF5C76B);
  static const Color danger = Color(0xFFFF6B6B);
}

const SystemUiOverlayStyle nimaluvSystemUiStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemStatusBarContrastEnforced: false,

  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
);

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',

      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: AppColors.background,
        onSecondary: AppColors.background,
        onSurface: AppColors.primary,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.primary,
        elevation: 0,
        systemOverlayStyle: nimaluvSystemUiStyle,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.primary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: AppColors.primary),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
          elevation: 0,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        elevation: 0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSoft,
        labelStyle: const TextStyle(color: AppColors.secondary),
        hintStyle: const TextStyle(color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.3),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        contentTextStyle: const TextStyle(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.primary,
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: 4,
        ),
        headlineMedium: TextStyle(
          color: AppColors.primary,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: AppColors.primary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.primary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: AppColors.secondary, fontSize: 16),
        bodyMedium: TextStyle(color: AppColors.secondary, fontSize: 14),
        bodySmall: TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    );
  }
}
