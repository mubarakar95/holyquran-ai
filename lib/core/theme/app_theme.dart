import 'package:flutter/material.dart';

enum AppThemeMode {
  light('light'),
  creme('creme'),
  dark('dark');

  final String value;
  const AppThemeMode(this.value);

  static AppThemeMode fromString(String val) {
    switch (val) {
      case 'creme':
        return AppThemeMode.creme;
      case 'dark':
        return AppThemeMode.dark;
      default:
        return AppThemeMode.light;
    }
  }
}

class AppColors {
  final Color background;
  final Color foreground;
  final Color surface;
  final Color border;
  final Color muted;
  final Color accent;
  final Brightness brightness;

  const AppColors({
    required this.background,
    required this.foreground,
    required this.surface,
    required this.border,
    required this.muted,
    required this.accent,
    required this.brightness,
  });

  static const light = AppColors(
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF18181B),
    surface: Color(0xFFF4F3EF),
    border: Color(0xFFE8E6E1),
    muted: Color(0xFF71717A),
    accent: Color(0xFF059669),
    brightness: Brightness.light,
  );

  static const creme = AppColors(
    background: Color(0xFFF7F2E9),
    foreground: Color(0xFF2C2419),
    surface: Color(0xFFEFE7DA),
    border: Color(0xFFE2D7C5),
    muted: Color(0xFF786D5E),
    accent: Color(0xFF047857),
    brightness: Brightness.light,
  );

  static const dark = AppColors(
    background: Color(0xFF0D0F12),
    foreground: Color(0xFFF1F5F9),
    surface: Color(0xFF16191E),
    border: Color(0xFF242830),
    muted: Color(0xFF94A3B8),
    accent: Color(0xFF10B981),
    brightness: Brightness.dark,
  );

  static AppColors fromMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.creme:
        return creme;
      case AppThemeMode.dark:
        return dark;
      case AppThemeMode.light:
        return light;
    }
  }
}

class AppTheme {
  static ThemeData getTheme(AppThemeMode mode) {
    final colors = AppColors.fromMode(mode);
    return ThemeData(
      brightness: colors.brightness,
      scaffoldBackgroundColor: colors.background,
      primaryColor: colors.accent,
      dividerColor: colors.border,
      colorScheme: ColorScheme(
        brightness: colors.brightness,
        primary: colors.accent,
        onPrimary: Colors.white,
        secondary: colors.accent,
        onSecondary: Colors.white,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: colors.surface,
        onSurface: colors.foreground,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background.withValues(alpha: 0.9),
        elevation: 0,
        iconTheme: IconThemeData(color: colors.muted),
        titleTextStyle: TextStyle(
          color: colors.foreground,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
