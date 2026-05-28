import 'package:flutter/material.dart';

class _AppColorPalette {
  const _AppColorPalette({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.primarySurface,
    required this.primarySurfaceLight,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.error,
    required this.errorBg,
    required this.info,
    required this.infoBg,
    required this.emergency,
    required this.emergencyBright,
  });

  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color primarySurface;
  final Color primarySurfaceLight;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color surfaceBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color error;
  final Color errorBg;
  final Color info;
  final Color infoBg;
  final Color emergency;
  final Color emergencyBright;
}

class AppColors {
  const AppColors._();

  static const _light = _AppColorPalette(
    primary: Color(0xFF07539D),
    primaryDark: Color(0xFF053F7A),
    primaryLight: Color(0xFF1A6DB8),
    primarySurface: Color(0xFFE8F1FA),
    primarySurfaceLight: Color(0xFFF0F6FC),
    background: Color(0xFFF7FAFE),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF1F4F8),
    surfaceBorder: Color(0xFFD1DDE9),
    textPrimary: Color(0xFF0A1929),
    textSecondary: Color(0xFF4A6080),
    textHint: Color(0xFF8DA3B8),
    success: Color(0xFF16A34A),
    successBg: Color(0xFFDCFCE7),
    warning: Color(0xFFD97706),
    warningBg: Color(0xFFFEF3C7),
    error: Color(0xFFDC2626),
    errorBg: Color(0xFFFEE2E2),
    info: Color(0xFF0284C7),
    infoBg: Color(0xFFE0F2FE),
    emergency: Color(0xFFB91C1C),
    emergencyBright: Color(0xFFEF4444),
  );

  static const _dark = _AppColorPalette(
    primary: Color(0xFF67B7FF),
    primaryDark: Color(0xFF2D8FE8),
    primaryLight: Color(0xFF9DCCFF),
    primarySurface: Color(0xFF102F4D),
    primarySurfaceLight: Color(0xFF0D243D),
    background: Color(0xFF07111F),
    surface: Color(0xFF101826),
    surfaceVariant: Color(0xFF172235),
    surfaceBorder: Color(0xFF33465F),
    textPrimary: Color(0xFFE7EEF8),
    textSecondary: Color(0xFFB6C6D9),
    textHint: Color(0xFF7F94AA),
    success: Color(0xFF4ADE80),
    successBg: Color(0xFF11351F),
    warning: Color(0xFFF59E0B),
    warningBg: Color(0xFF3D2A0A),
    error: Color(0xFFF87171),
    errorBg: Color(0xFF3B1518),
    info: Color(0xFF38BDF8),
    infoBg: Color(0xFF0B2E43),
    emergency: Color(0xFFDC2626),
    emergencyBright: Color(0xFFF87171),
  );

  static bool _darkMode = false;

  static void setDarkMode(bool enabled) {
    _darkMode = enabled;
  }

  static _AppColorPalette get _active => _darkMode ? _dark : _light;

  static Color get primary => _active.primary;
  static Color get primaryDark => _active.primaryDark;
  static Color get primaryLight => _active.primaryLight;
  static Color get primarySurface => _active.primarySurface;
  static Color get primarySurfaceLight => _active.primarySurfaceLight;
  static Color get background => _active.background;
  static Color get surface => _active.surface;
  static Color get surfaceVariant => _active.surfaceVariant;
  static Color get surfaceBorder => _active.surfaceBorder;
  static Color get textPrimary => _active.textPrimary;
  static Color get textSecondary => _active.textSecondary;
  static Color get textHint => _active.textHint;
  static Color get success => _active.success;
  static Color get successBg => _active.successBg;
  static Color get warning => _active.warning;
  static Color get warningBg => _active.warningBg;
  static Color get error => _active.error;
  static Color get errorBg => _active.errorBg;
  static Color get info => _active.info;
  static Color get infoBg => _active.infoBg;
  static Color get emergency => _active.emergency;
  static Color get emergencyBright => _active.emergencyBright;
}

class AppTheme {
  const AppTheme._();

  static ThemeData dark() {
    final base = light();
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF67B7FF),
      onPrimary: Color(0xFF041A2F),
      primaryContainer: Color(0xFF0D3155),
      onPrimaryContainer: Color(0xFFD8ECFF),
      secondary: Color(0xFF9DCCFF),
      onSecondary: Color(0xFF08213A),
      secondaryContainer: Color(0xFF14304D),
      onSecondaryContainer: Color(0xFFD7E9FF),
      surface: Color(0xFF101826),
      onSurface: Color(0xFFE7EEF8),
      surfaceContainerHighest: Color(0xFF172235),
      onSurfaceVariant: Color(0xFFB6C6D9),
      outline: Color(0xFF33465F),
      error: AppColors.error,
      onError: Colors.white,
    );

    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0B1220),
      dialogTheme: DialogThemeData(backgroundColor: Color(0xFF101826)),
    );
  }

  static ThemeData light() {
    final colorScheme = ColorScheme(
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
      fontFamily: 'Inter',
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              textStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
          side: BorderSide(color: AppColors.primary),
          minimumSize: const Size(100, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ).copyWith(overlayColor: primaryOverlay),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: TextStyle(color: AppColors.textSecondary),
        prefixIconColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dividerTheme: DividerThemeData(
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
        valueIndicatorTextStyle: TextStyle(color: Colors.white, fontSize: 12),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
