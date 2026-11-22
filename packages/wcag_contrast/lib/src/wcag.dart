import 'color.dart';
import 'color_spaces.dart';

/// WCAG conformance level.
enum WcagLevel {
  aa('AA'),
  aaa('AAA');

  const WcagLevel(this.label);

  final String label;
}

/// The kind of content a contrast requirement applies to.
enum ContrastCategory {
  /// SC 1.4.3 / 1.4.6 — regular body text.
  normalText('Normal text'),

  /// SC 1.4.3 / 1.4.6 — text at least 18pt (24px), or 14pt (≈18.66px) bold.
  largeText('Large text'),

  /// SC 1.4.11 — graphical objects and user interface components.
  nonText('Graphical objects and UI components');

  const ContrastCategory(this.label);

  final String label;
}

/// The minimum contrast ratio WCAG 2.1 requires for [category] at [level], or
/// `null` when the level does not define a requirement (AAA for non-text).
double? requiredRatio(ContrastCategory category, WcagLevel level) =>
    switch ((category, level)) {
      (ContrastCategory.normalText, WcagLevel.aa) => 4.5,
      (ContrastCategory.normalText, WcagLevel.aaa) => 7.0,
      (ContrastCategory.largeText, WcagLevel.aa) => 3.0,
      (ContrastCategory.largeText, WcagLevel.aaa) => 4.5,
      (ContrastCategory.nonText, WcagLevel.aa) => 3.0,
      (ContrastCategory.nonText, WcagLevel.aaa) => null,
    };

/// WCAG 2.1 relative luminance of a color (alpha is ignored).
double relativeLuminance(RgbColor color) =>
    0.2126 * srgbToLinear(color.r) +
    0.7152 * srgbToLinear(color.g) +
    0.0722 * srgbToLinear(color.b);

/// Contrast ratio between two relative luminances: (L1 + 0.05) / (L2 + 0.05).
double contrastRatioOfLuminances(double a, double b) {
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}

/// WCAG 2.1 contrast ratio (1–21) between [foreground] and [background].
///
/// The background is treated as opaque. A semi-transparent foreground is
/// blended over the background first, matching what is actually rendered.
double contrastRatio(RgbColor foreground, RgbColor background) {
  final bg = background.opaque;
  final fg = foreground.compositeOver(bg);
  return contrastRatioOfLuminances(
    relativeLuminance(fg),
    relativeLuminance(bg),
  );
}

/// Full WCAG 2.1 evaluation of a color pair.
final class ContrastReport {
  ContrastReport._(this.foreground, this.background, this.effectiveForeground)
    : ratio = contrastRatioOfLuminances(
        relativeLuminance(effectiveForeground),
        relativeLuminance(background),
      );

  /// The foreground as entered (may be semi-transparent).
  final RgbColor foreground;

  /// The opaque background.
  final RgbColor background;

  /// The foreground after blending over the background.
  final RgbColor effectiveForeground;

  /// The unrounded contrast ratio. Pass/fail always uses this value.
  final double ratio;

  /// Whether the pair meets [level] for [category]. Returns `false` when the
  /// level has no requirement for that category.
  bool passes(ContrastCategory category, WcagLevel level) {
    final required = requiredRatio(category, level);
    return required != null && ratio >= required;
  }

  bool get normalTextAA => passes(ContrastCategory.normalText, WcagLevel.aa);
  bool get normalTextAAA => passes(ContrastCategory.normalText, WcagLevel.aaa);
  bool get largeTextAA => passes(ContrastCategory.largeText, WcagLevel.aa);
  bool get largeTextAAA => passes(ContrastCategory.largeText, WcagLevel.aaa);
  bool get nonTextAA => passes(ContrastCategory.nonText, WcagLevel.aa);

  /// Overall status used for at-a-glance UI.
  ContrastRating get rating {
    if (normalTextAAA) return ContrastRating.excellent;
    if (normalTextAA) return ContrastRating.good;
    if (largeTextAA) return ContrastRating.limited;
    return ContrastRating.poor;
  }
}

/// At-a-glance summary of a [ContrastReport].
enum ContrastRating {
  /// Passes every WCAG 2.1 contrast criterion, including AAA.
  excellent('Passes AA and AAA at every text size'),

  /// Passes AA for all text; AAA only for large text.
  good('Passes AA for all text and UI components'),

  /// Passes only for large text and UI components.
  limited('Passes only for large text and UI components'),

  /// Fails every WCAG 2.1 contrast criterion.
  poor('Fails all WCAG 2.1 contrast requirements');

  const ContrastRating(this.summary);

  final String summary;
}

/// Evaluates [foreground] over [background] against WCAG 2.1.
ContrastReport evaluateContrast(RgbColor foreground, RgbColor background) {
  final bg = background.opaque;
  return ContrastReport._(foreground, bg, foreground.compositeOver(bg));
}
