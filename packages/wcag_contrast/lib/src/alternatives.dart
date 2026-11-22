import 'color.dart';
import 'color_spaces.dart';
import 'wcag.dart';

/// Which color of the pair a suggestion replaces.
enum AdjustTarget {
  foreground('Foreground'),
  background('Background');

  const AdjustTarget(this.label);

  final String label;
}

/// Whether a suggestion is darker or lighter than the original color.
enum SuggestionDirection {
  darker('Darker'),
  lighter('Lighter');

  const SuggestionDirection(this.label);

  final String label;
}

/// A replacement color that meets the requested contrast ratio.
final class ColorSuggestion {
  const ColorSuggestion({
    required this.color,
    required this.ratio,
    required this.deltaE,
    required this.direction,
    this.alphaChanged = false,
  });

  /// The suggested color. For a foreground suggestion this keeps the original
  /// alpha unless [alphaChanged] is set.
  final RgbColor color;

  /// The contrast ratio the pair has with this color applied.
  final double ratio;

  /// Perceptual distance from the original color (see [deltaEOk]).
  final double deltaE;

  final SuggestionDirection direction;

  /// True when the original foreground opacity made the target unreachable and
  /// the suggestion is fully opaque instead.
  final bool alphaChanged;

  ChangeMagnitude get magnitude => ChangeMagnitude.of(deltaE);

  @override
  String toString() =>
      'ColorSuggestion(${color.toHex()}, ratio: ${ratio.toStringAsFixed(3)}, '
      'ΔE: ${deltaE.toStringAsFixed(2)}, ${direction.name})';
}

/// The result of [suggestAlternatives].
final class AlternativesResult {
  const AlternativesResult({
    required this.targetRatio,
    required this.currentRatio,
    required this.suggestions,
    required this.fallback,
  });

  final double targetRatio;
  final double currentRatio;

  /// Up to the requested number of passing colors, closest first. Empty when
  /// the pair already passes or when no color with the same hue can pass.
  final List<ColorSuggestion> suggestions;

  /// Black or white — whichever gives the higher contrast.
  final ColorSuggestion fallback;

  bool get alreadyPasses => currentRatio >= targetRatio;
}

/// Finds the colors closest to the original that make the pair reach
/// [targetRatio], changing only the color chosen by [adjust].
///
/// Candidates keep the original hue and are found by moving lightness darker
/// and lighter in both OKLCH (perceptually uniform) and HSL. Each candidate is
/// verified after rounding to 8-bit channels, so every returned suggestion
/// truly meets the target. Results are ordered by perceptual distance.
AlternativesResult suggestAlternatives({
  required RgbColor foreground,
  required RgbColor background,
  required double targetRatio,
  required AdjustTarget adjust,
  int maxSuggestions = 3,
}) {
  final bg = background.opaque;
  final current = contrastRatio(foreground, bg);
  final fallback = _fallback(foreground, bg, adjust);

  if (current >= targetRatio) {
    return AlternativesResult(
      targetRatio: targetRatio,
      currentRatio: current,
      suggestions: const [],
      fallback: fallback,
    );
  }

  final original = adjust == AdjustTarget.foreground ? foreground.opaque : bg;

  var suggestions = _search(
    original: original,
    targetRatio: targetRatio,
    ratioFor: (candidate) => adjust == AdjustTarget.foreground
        ? contrastRatio(candidate.withAlpha(foreground.alpha), bg)
        : contrastRatio(foreground, candidate),
    alpha: adjust == AdjustTarget.foreground ? foreground.alpha : 1.0,
    alphaChanged: false,
  );

  // A very transparent foreground may never reach the target. Offer opaque
  // alternatives instead of nothing — starting with the same color at full
  // opacity when that alone is enough.
  if (suggestions.isEmpty &&
      adjust == AdjustTarget.foreground &&
      !foreground.isOpaque) {
    final opaqueRatio = contrastRatio(original, bg);
    if (opaqueRatio >= targetRatio) {
      suggestions = [
        ColorSuggestion(
          color: original,
          ratio: opaqueRatio,
          deltaE: 0,
          direction: relativeLuminance(original) <= relativeLuminance(bg)
              ? SuggestionDirection.darker
              : SuggestionDirection.lighter,
          alphaChanged: true,
        ),
      ];
    } else {
      suggestions = _search(
        original: original,
        targetRatio: targetRatio,
        ratioFor: (candidate) => contrastRatio(candidate, bg),
        alpha: 1.0,
        alphaChanged: true,
      );
    }
  }

  suggestions.sort((a, b) => a.deltaE.compareTo(b.deltaE));
  return AlternativesResult(
    targetRatio: targetRatio,
    currentRatio: current,
    suggestions: suggestions.take(maxSuggestions).toList(),
    fallback: fallback,
  );
}

List<ColorSuggestion> _search({
  required RgbColor original,
  required double targetRatio,
  required double Function(RgbColor opaqueCandidate) ratioFor,
  required double alpha,
  required bool alphaChanged,
}) {
  // Neutral grays get exactly zero chroma so suggestions stay neutral instead
  // of picking up a faint tint from floating-point noise.
  final isNeutral = original.r == original.g && original.g == original.b;
  final rawLch = OkLch.fromRgb(original);
  final oklch = isNeutral ? OkLch(rawLch.l, 0, 0) : rawLch;
  final hsl = HslColor.fromRgb(original);

  RgbColor viaOklch(double l) => OkLch(l, oklch.c, oklch.h).toRgbGamutMapped();
  RgbColor viaHsl(double l) => hsl.withLightness(l).toRgb();

  final found = <int, ColorSuggestion>{};
  for (final (colorAt, start) in [(viaOklch, oklch.l), (viaHsl, hsl.l)]) {
    for (final direction in SuggestionDirection.values) {
      final end = direction == SuggestionDirection.darker ? 0.0 : 1.0;
      final candidate = _firstPassing(
        colorAt: colorAt,
        start: start,
        end: end,
        passes: (c) => ratioFor(c) >= targetRatio,
      );
      if (candidate == null || candidate.rgb == original.rgb) continue;
      final color = candidate.withAlpha(alpha);
      found.putIfAbsent(
        candidate.rgb,
        () => ColorSuggestion(
          color: color,
          ratio: ratioFor(candidate),
          deltaE: deltaEOk(original, candidate),
          direction: direction,
          alphaChanged: alphaChanged,
        ),
      );
    }
  }
  return found.values.toList();
}

/// Walks lightness from [start] to [end] and returns the first (closest)
/// 8-bit color that passes, refined by bisection. Returns `null` if even the
/// end point fails.
RgbColor? _firstPassing({
  required RgbColor Function(double lightness) colorAt,
  required double start,
  required double end,
  required bool Function(RgbColor) passes,
}) {
  const steps = 200;
  var prev = start;
  for (var i = 1; i <= steps; i++) {
    final t = start + (end - start) * i / steps;
    if (passes(colorAt(t))) {
      // Bisect between the last failing point and this passing one. The
      // passing bound is only ever replaced by another passing point, so the
      // result is guaranteed to pass even though 8-bit rounding makes the
      // ratio a step function.
      var failing = prev;
      var passing = t;
      for (var j = 0; j < 30; j++) {
        final mid = (failing + passing) / 2;
        if (passes(colorAt(mid))) {
          passing = mid;
        } else {
          failing = mid;
        }
      }
      return colorAt(passing);
    }
    prev = t;
  }
  return null;
}

ColorSuggestion _fallback(
  RgbColor foreground,
  RgbColor background,
  AdjustTarget adjust,
) {
  final original = adjust == AdjustTarget.foreground
      ? foreground.opaque
      : background;
  double ratioWith(RgbColor c) => adjust == AdjustTarget.foreground
      ? contrastRatio(c, background)
      : contrastRatio(foreground, c);
  final blackRatio = ratioWith(RgbColor.black);
  final whiteRatio = ratioWith(RgbColor.white);
  final useBlack = blackRatio >= whiteRatio;
  final color = useBlack ? RgbColor.black : RgbColor.white;
  return ColorSuggestion(
    color: color,
    ratio: useBlack ? blackRatio : whiteRatio,
    deltaE: deltaEOk(original, color),
    direction: useBlack
        ? SuggestionDirection.darker
        : SuggestionDirection.lighter,
    alphaChanged: adjust == AdjustTarget.foreground && !foreground.isOpaque,
  );
}
