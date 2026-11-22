import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wcag_contrast/wcag_contrast.dart';

void main() {
  test('HSL round-trips every color in a coarse grid', () {
    for (var r = 0; r <= 255; r += 15) {
      for (var g = 0; g <= 255; g += 15) {
        for (var b = 0; b <= 255; b += 15) {
          final c = RgbColor(r, g, b);
          expect(HslColor.fromRgb(c).toRgb(), c, reason: c.toHex());
        }
      }
    }
  });

  test('OKLab reference values', () {
    final white = OkLab.fromRgb(RgbColor.white);
    expect(white.l, closeTo(1, 1e-4));
    expect(white.a, closeTo(0, 1e-4));
    expect(white.b, closeTo(0, 1e-4));

    final red = OkLab.fromRgb(const RgbColor(255, 0, 0));
    expect(red.l, closeTo(0.62796, 1e-4));
    expect(red.a, closeTo(0.22486, 1e-4));
    expect(red.b, closeTo(0.12585, 1e-4));

    expect(OkLab.fromRgb(RgbColor.black).l, closeTo(0, 1e-9));
  });

  test('OKLCH round-trips in-gamut colors', () {
    final rnd = math.Random(7);
    for (var i = 0; i < 1000; i++) {
      final c = RgbColor.fromInt(rnd.nextInt(0x1000000));
      expect(OkLch.fromRgb(c).toRgbGamutMapped(), c, reason: c.toHex());
    }
  });

  test('gamut mapping keeps out-of-gamut colors displayable', () {
    // Very high chroma at mid lightness is outside sRGB.
    const lch = OkLch(0.7, 0.5, 150);
    expect(lch.isInSrgbGamut, isFalse);
    final mapped = lch.toRgbGamutMapped();
    final back = OkLch.fromRgb(mapped);
    expect(back.l, closeTo(0.7, 0.01));
  });

  test('deltaE and magnitude', () {
    expect(deltaEOk(RgbColor.white, RgbColor.white), 0);
    expect(deltaEOk(RgbColor.black, RgbColor.white), closeTo(100, 0.01));
    expect(ChangeMagnitude.of(1), ChangeMagnitude.imperceptible);
    expect(ChangeMagnitude.of(4), ChangeMagnitude.subtle);
    expect(ChangeMagnitude.of(10), ChangeMagnitude.noticeable);
    expect(ChangeMagnitude.of(40), ChangeMagnitude.significant);
  });
}
