import 'package:flutter/material.dart';

abstract final class AppColors {
  static const navy = Color(0xFF173B57);
  static const blue = Color(0xFF176B87);
  static const teal = Color(0xFF0E7C72);
  static const ink = Color(0xFF17212B);
  static const muted = Color(0xFF5D6975);
  static const canvas = Color(0xFFF5F7F8);
  static const border = Color(0xFFDDE3E7);
  static const success = Color(0xFF187A55);
}

ThemeData buildAppTheme() {
  final colors =
      ColorScheme.fromSeed(
        seedColor: AppColors.blue,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.blue,
        onPrimary: Colors.white,
        secondary: AppColors.teal,
        surface: Colors.white,
        onSurface: AppColors.ink,
        outline: AppColors.border,
        surfaceContainerLowest: Colors.white,
      );

  final base = ThemeData(colorScheme: colors, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.canvas,
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: AppColors.ink,
        fontSize: 16,
        height: 1.4,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: AppColors.muted,
        fontSize: 15,
        height: 1.4,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 21,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      labelStyle: const TextStyle(color: AppColors.muted, fontSize: 16),
      hintStyle: const TextStyle(color: Color(0xFF7B8791), fontSize: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.blue, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.blue
              : AppColors.muted,
          fontSize: 13,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
        );
      }),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
  );
}
