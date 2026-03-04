import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color backgroundOffWhite = Color(0xFFF8F9FA);
  static const Color richDarkBackground = Color(0xFF14181F);
  static const Color primaryText = Color(0xFF0A0A0A);
  static const Color accent = Color(0xFF0055FF);
  static const Color muted = Color(0xFF64748B);
}

abstract final class AppTypography {
  static const double labelMediumSize = 12;
  static const double bodyMediumSize = 16;
  static const double displayMediumSize = 32;
  static const double displayLargeSize = 64;
}

abstract final class AppSpacing {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 16;
  static const double x4 = 32;
  static const double x5 = 64;
}

abstract final class AppTouchTargets {
  static const double minSize = 44;
}
