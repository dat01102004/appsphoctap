import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData light() {
    const baseTextTheme = TextTheme(
      displayLarge: TextStyle(color: AppColors.textDark),
      displayMedium: TextStyle(color: AppColors.textDark),
      displaySmall: TextStyle(color: AppColors.textDark),
      headlineLarge: TextStyle(color: AppColors.textDark),
      headlineMedium: TextStyle(color: AppColors.textDark),
      headlineSmall: TextStyle(color: AppColors.textDark),
      titleLarge: TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: AppColors.textDark),
      bodyMedium: TextStyle(color: AppColors.textDark),
      bodySmall: TextStyle(color: AppColors.muted),
      labelLarge: TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.w800,
      ),
      labelMedium: TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: TextStyle(
        color: AppColors.muted,
        fontWeight: FontWeight.w700,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgBeige,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.brandBrown,
            brightness: Brightness.light,
          ).copyWith(
            primary: AppColors.brandBrown,
            onPrimary: Colors.white,
            primaryContainer: AppColors.cardStroke,
            onPrimaryContainer: AppColors.textDark,
            secondary: AppColors.brandBrownDark,
            surface: AppColors.card,
            onSurface: AppColors.textDark,
            error: AppColors.danger,
          ),
      textTheme: baseTextTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.brandBrown,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.cardStroke, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandBrown,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.cardStroke,
          disabledForegroundColor: AppColors.muted,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandBrown,
          side: const BorderSide(color: AppColors.cardStroke, width: 1.3),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandBrown,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        labelStyle: const TextStyle(color: AppColors.muted),
        hintStyle: const TextStyle(color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.cardStroke, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.cardStroke, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.brandBrown, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.cardStroke.withValues(alpha: 0.78),
        disabledColor: AppColors.bgBeige,
        side: const BorderSide(color: AppColors.cardStroke, width: 1.2),
        labelStyle: const TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w800,
        ),
        brightness: Brightness.light,
      ),
      iconTheme: const IconThemeData(color: AppColors.textDark),
      dividerTheme: const DividerThemeData(
        color: AppColors.cardStroke,
        thickness: 1,
      ),
    );
  }
}
