import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0B3954);
  static const Color secondary = Color(0xFFFFB703);
  static const Color accent = Color(0xFF17BEBB);
  static const Color success = Color(0xFF2A9D8F);
  static const Color warning = Color(0xFFF4A261);
  static const Color danger = Color(0xFFE63946);
  static const Color info = Color(0xFF125E82);
  static const Color ink = Color(0xFF1F2937);
  static const Color inkMuted = Color(0xFF64748B);
  static const Color background = Color(0xFFF6F2E9);
  static const Color surface = Color(0xFFFDFBF7);
  static const Color surfaceAlt = Color(0xFFF2F7F9);
  static const Color outline = Color(0xFFD0D7DE);
  static const Color outlineSubtle = Color(0xFFE6EBEF);
}

class AppGradients {
  static const LinearGradient primary = LinearGradient(
    colors: [AppColors.primary, Color(0xFF125E82)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient accent = LinearGradient(
    colors: [AppColors.secondary, Color(0xFFFFD166)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient surface = LinearGradient(
    colors: [AppColors.background, AppColors.surfaceAlt],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppRadii {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
}

class AppShadows {
  static final List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.08),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
  static final List<BoxShadow> floating = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.14),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
  static final List<BoxShadow> glow = [
    BoxShadow(
      color: AppColors.secondary.withValues(alpha: 0.35),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

class AppMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 520);
}

class AppSizes {
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;
}
