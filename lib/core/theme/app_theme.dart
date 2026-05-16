import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Primary palette
  static const primary = Color(0xFF07539D);
  static const primaryDark = Color(0xFF053F7A);
  static const primaryLight = Color(0xFF1A6DB8);
  static const primarySurface = Color(0xFFE8F1FA);
  static const primarySurfaceLight = Color(0xFFF0F6FC);

  // Background
  static const background = Color(0xFFF4F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF0F4F9);
  static const surfaceBorder = Color(0xFFD1DDE9);

  // Text
  static const textPrimary = Color(0xFF0A1929);
  static const textSecondary = Color(0xFF4A6080);
  static const textHint = Color(0xFF8DA3B8);

  // Status colors
  static const success = Color(0xFF16A34A);
  static const successBg = Color(0xFFDCFCE7);
  static const warning = Color(0xFFD97706);
  static const warningBg = Color(0xFFFEF3C7);
  static const error = Color(0xFFDC2626);
  static const errorBg = Color(0xFFFEE2E2);
  static const info = Color(0xFF0284C7);
  static const infoBg = Color(0xFFE0F2FE);

  // Emergency
  static const emergency = Color(0xFFB91C1C);
  static const emergencyBright = Color(0xFFEF4444);
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySurface,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.primaryLight,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.primarySurfaceLight,
      onSecondaryContainer: AppColors.primaryDark,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceVariant,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.surfaceBorder,
      error: AppColors.error,
      onError: Colors.white,
    );

    final filledOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return Colors.white.withValues(alpha: 0.24);
      }
      if (states.contains(WidgetState.hovered)) {
        return Colors.white.withValues(alpha: 0.10);
      }
      return null;
    });
    final primaryOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return AppColors.primary.withValues(alpha: 0.18);
      }
      if (states.contains(WidgetState.hovered)) {
        return AppColors.primary.withValues(alpha: 0.08);
      }
      return null;
    });

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ).copyWith(
              overlayColor: filledOverlay,
              elevation: WidgetStateProperty.resolveWith<double?>(
                (states) => states.contains(WidgetState.pressed) ? 0 : null,
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size(100, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ).copyWith(overlayColor: primaryOverlay),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ).copyWith(overlayColor: primaryOverlay),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.primary,
        ).copyWith(overlayColor: primaryOverlay),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIconColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceBorder,
        thickness: 1,
        space: 1,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        thumbColor: AppColors.primary,
        inactiveTrackColor: AppColors.surfaceBorder,
        overlayColor: AppColors.primary.withValues(alpha: 0.15),
        trackHeight: 5,
        valueIndicatorColor: AppColors.primaryDark,
        valueIndicatorTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
