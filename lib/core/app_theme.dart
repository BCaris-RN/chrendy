import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

abstract final class AppTheme {
  static ThemeData get lightTheme {
    const minimumTouchTarget = Size(
      AppTouchTargets.minSize,
      AppTouchTargets.minSize,
    );
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.x4,
      vertical: AppSpacing.x3,
    );

    final textTheme = TextTheme(
      displayLarge: GoogleFonts.dmSerifDisplay(
        fontSize: AppTypography.displayLargeSize,
        height: 0.9,
        letterSpacing: -1.5,
        color: AppColors.primaryText,
      ),
      displayMedium: GoogleFonts.dmSerifDisplay(
        fontSize: AppTypography.displayMediumSize,
        height: 1.0,
        letterSpacing: -0.5,
        color: AppColors.primaryText,
      ),
      bodyMedium: GoogleFonts.ibmPlexSans(
        fontSize: AppTypography.bodyMediumSize,
        height: 1.5,
        color: AppColors.primaryText.withValues(alpha: 0.8),
      ),
      labelMedium: GoogleFonts.ibmPlexSans(
        fontSize: AppTypography.labelMediumSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: AppColors.primaryText,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.backgroundOffWhite,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryText,
        secondary: AppColors.accent,
        surface: AppColors.backgroundOffWhite,
        onPrimary: AppColors.backgroundOffWhite,
        onSecondary: AppColors.backgroundOffWhite,
        onSurface: AppColors.primaryText,
      ),
      textTheme: textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _buttonStyle(
          minimumSize: minimumTouchTarget,
          padding: buttonPadding,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(
          minimumSize: minimumTouchTarget,
          padding: buttonPadding,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _buttonStyle(
          minimumSize: minimumTouchTarget,
          padding: buttonPadding,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: const ButtonStyle(
          minimumSize: WidgetStatePropertyAll(minimumTouchTarget),
          padding: WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.x3)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x3,
        ),
      ),
    );
  }

  static ButtonStyle _buttonStyle({
    required Size minimumSize,
    required EdgeInsets padding,
  }) {
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll(minimumSize),
      padding: WidgetStatePropertyAll(padding),
    );
  }
}
