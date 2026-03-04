import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgBeige,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.brandBrown),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.brandBrown,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.cardStroke, width: 1),
        ),
      ),
    );
  }
}