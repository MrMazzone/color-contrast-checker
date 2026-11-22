import 'package:flutter/material.dart';

/// Brand and semantic colors not covered by [ColorScheme].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.pass,
    required this.fail,
    required this.warn,
    required this.onStatus,
    required this.checkerLight,
    required this.checkerDark,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  /// Badge fills. White text on each meets WCAG AA (≥ 4.5:1).
  final Color pass;
  final Color fail;
  final Color warn;
  final Color onStatus;

  /// Transparency checkerboard.
  final Color checkerLight;
  final Color checkerDark;

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA855F7), Color(0xFF4F46E5), Color(0xFF0EA5E9)],
    stops: [0, 0.55, 1],
  );

  static const light = AppColors(
    background: Color(0xFFF4F4F9),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F1F7),
    border: Color(0xFFE2E2EC),
    textPrimary: Color(0xFF15151F),
    textSecondary: Color(0xFF52526A),
    pass: Color(0xFF15803D),
    fail: Color(0xFFB42318),
    warn: Color(0xFF9A4A06),
    onStatus: Color(0xFFFFFFFF),
    checkerLight: Color(0xFFFFFFFF),
    checkerDark: Color(0xFFD9D9E3),
  );

  static const dark = AppColors(
    background: Color(0xFF0D0E18),
    surface: Color(0xFF161726),
    surfaceMuted: Color(0xFF1E2033),
    border: Color(0xFF2B2D44),
    textPrimary: Color(0xFFF1F1F8),
    textSecondary: Color(0xFFA9ABC4),
    pass: Color(0xFF15803D),
    fail: Color(0xFFB42318),
    warn: Color(0xFF9A4A06),
    onStatus: Color(0xFFFFFFFF),
    checkerLight: Color(0xFF3A3C52),
    checkerDark: Color(0xFF26283B),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      border: l(border, other.border),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      pass: l(pass, other.pass),
      fail: l(fail, other.fail),
      warn: l(warn, other.warn),
      onStatus: l(onStatus, other.onStatus),
      checkerLight: l(checkerLight, other.checkerLight),
      checkerDark: l(checkerDark, other.checkerDark),
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
}

const monoFamily = 'JetBrains Mono';

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final c = isDark ? AppColors.dark : AppColors.light;
  final primary = isDark ? const Color(0xFF9D97FF) : const Color(0xFF4F46E5);
  final onPrimary = isDark ? const Color(0xFF14123A) : Colors.white;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: isDark
        ? const Color(0xFF2E2A6B)
        : const Color(0xFFE6E4FF),
    onPrimaryContainer: isDark
        ? const Color(0xFFE6E4FF)
        : const Color(0xFF1E1A5C),
    secondary: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
    onSecondary: isDark ? const Color(0xFF082F49) : Colors.white,
    secondaryContainer: isDark
        ? const Color(0xFF26284A)
        : const Color(0xFFE9E8F7),
    onSecondaryContainer: c.textPrimary,
    error: isDark ? const Color(0xFFFF8A80) : const Color(0xFFB42318),
    onError: isDark ? const Color(0xFF3B0A06) : Colors.white,
    surface: c.surface,
    onSurface: c.textPrimary,
    onSurfaceVariant: c.textSecondary,
    surfaceContainerLowest: c.background,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surfaceMuted,
    surfaceContainerHigh: c.surfaceMuted,
    surfaceContainerHighest: c.border,
    outline: isDark ? const Color(0xFF6E7090) : const Color(0xFF8A8AA0),
    outlineVariant: c.border,
    inverseSurface: isDark ? const Color(0xFFF1F1F8) : const Color(0xFF1E1F2E),
    onInverseSurface: isDark
        ? const Color(0xFF15151F)
        : const Color(0xFFF1F1F8),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: c.background,
    visualDensity: VisualDensity.standard,
    extensions: [c],
  );

  final textTheme = base.textTheme.apply(
    bodyColor: c.textPrimary,
    displayColor: c.textPrimary,
  );

  return base.copyWith(
    textTheme: textTheme.copyWith(
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: c.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      // Input boundaries use `outline` (≥ 3:1, WCAG 1.4.11), not the
      // decorative card border.
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: c.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      textStyle: TextStyle(
        color: scheme.onInverseSurface,
        fontSize: 12,
        fontFamily: 'Inter',
      ),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 420,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 14,
      overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
    ),
  );
}
