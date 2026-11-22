import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wcag_contrast/wcag_contrast.dart';

void main() {
  test('#777 on white → nearly identical darker gray for AA', () {
    final result = suggestAlternatives(
      foreground: parseColor('#777777'),
      background: RgbColor.white,
      targetRatio: 4.5,
      adjust: AdjustTarget.foreground,
    );
    expect(result.alreadyPasses, isFalse);
    expect(result.suggestions, isNotEmpty);
    final best = result.suggestions.first;
    expect(best.ratio, greaterThanOrEqualTo(4.5));
    expect(best.direction, SuggestionDirection.darker);
    expect(best.color.toHex(), '#767676');
    expect(best.magnitude, ChangeMagnitude.imperceptible);
    expect(result.fallback.color, RgbColor.black);
    expect(formatRatio(result.fallback.ratio), '21.00');
  });

  test('already passing pairs return no suggestions', () {
    final result = suggestAlternatives(
      foreground: RgbColor.black,
      background: RgbColor.white,
      targetRatio: 7,
      adjust: AdjustTarget.foreground,
    );
    expect(result.alreadyPasses, isTrue);
    expect(result.suggestions, isEmpty);
  });

  test('can adjust the background instead', () {
    final fg = parseColor('#FFFFFF');
    final bg = parseColor('#4F9BFF');
    final result = suggestAlternatives(
      foreground: fg,
      background: bg,
      targetRatio: 4.5,
      adjust: AdjustTarget.background,
    );
    expect(result.suggestions, isNotEmpty);
    for (final s in result.suggestions) {
      expect(contrastRatio(fg, s.color), greaterThanOrEqualTo(4.5));
    }
    // White text needs a darker background.
    expect(result.suggestions.first.direction, SuggestionDirection.darker);
    expect(result.fallback.color, RgbColor.black);
  });

  test('keeps the foreground alpha when the target is reachable', () {
    final fg = parseColor('#3366FF').withAlpha(0.8);
    final result = suggestAlternatives(
      foreground: fg,
      background: RgbColor.white,
      targetRatio: 4.5,
      adjust: AdjustTarget.foreground,
    );
    expect(result.suggestions, isNotEmpty);
    for (final s in result.suggestions) {
      expect(s.alphaChanged, isFalse);
      expect(s.color.alpha, closeTo(0.8, 1e-9));
      expect(contrastRatio(s.color, RgbColor.white), greaterThanOrEqualTo(4.5));
    }
  });

  test(
    'falls back to opaque colors when alpha makes the target unreachable',
    () {
      final fg = parseColor('#000000').withAlpha(0.1);
      final result = suggestAlternatives(
        foreground: fg,
        background: RgbColor.white,
        targetRatio: 7,
        adjust: AdjustTarget.foreground,
      );
      expect(result.suggestions, isNotEmpty);
      for (final s in result.suggestions) {
        expect(s.alphaChanged, isTrue);
        expect(s.color.isOpaque, isTrue);
        expect(s.ratio, greaterThanOrEqualTo(7));
      }
    },
  );

  test('property: every suggestion meets the target after 8-bit rounding', () {
    final rnd = math.Random(42);
    const targets = [3.0, 4.5, 7.0];
    var checked = 0;
    for (var i = 0; i < 1500; i++) {
      final fg = RgbColor.fromInt(rnd.nextInt(0x1000000));
      final bg = RgbColor.fromInt(rnd.nextInt(0x1000000));
      final target = targets[i % targets.length];
      final adjust = AdjustTarget.values[i % 2];
      final result = suggestAlternatives(
        foreground: fg,
        background: bg,
        targetRatio: target,
        adjust: adjust,
      );
      expect(result.suggestions.length, lessThanOrEqualTo(3));
      for (var j = 0; j < result.suggestions.length; j++) {
        final s = result.suggestions[j];
        final actual = adjust == AdjustTarget.foreground
            ? contrastRatio(s.color, bg)
            : contrastRatio(fg, s.color);
        expect(actual, greaterThanOrEqualTo(target), reason: '$fg on $bg → $s');
        expect(actual, closeTo(s.ratio, 1e-12));
        if (j > 0) {
          expect(
            s.deltaE,
            greaterThanOrEqualTo(result.suggestions[j - 1].deltaE),
          );
        }
        checked++;
      }
      // Black or white always gives at least as much contrast as any
      // suggestion.
      for (final s in result.suggestions) {
        expect(result.fallback.ratio, greaterThanOrEqualTo(s.ratio - 1e-9));
      }
    }
    expect(checked, greaterThan(1000));
  });
}
