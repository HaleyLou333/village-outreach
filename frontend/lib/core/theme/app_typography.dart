import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static const String headingFont = 'Nunito';
  static const String bodyFont = 'Inter';
  static const String brandFont = 'Raleway';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: headingFont,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: AppColors.charcoal,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: headingFont,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.charcoal,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: headingFont,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.charcoal,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: bodyFont,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.charcoal,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: bodyFont,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.charcoal,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: bodyFont,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.charcoal,
  );

  static const TextStyle brandTitle = TextStyle(
    fontFamily: brandFont,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.forestGreen,
  );
}
