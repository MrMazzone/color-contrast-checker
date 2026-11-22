import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wcag_contrast/wcag_contrast.dart';

void main() {
  group('relative luminance', () {
    test('black and white are the extremes', () {
      expect(relativeLuminance(RgbColor.black), 0);
      expect(relativeLuminance(RgbColor.white), closeTo(1, 1e-12));
    });

    test('pure blue uses the 0.0722 coefficient', () {
      expect(
        relativeLuminance(const RgbColor(0, 0, 255)),
        closeTo(0.0722, 1e-12),
      );
    });

    test('0.03928 and 0.04045 thresholds agree for every 8-bit value', () {
      double legacy(int v) {
        final c = v / 255;
        return c <= 0.03928
            ? c / 12.92
            : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
      }

      for (var v = 0; v <= 255; v++) {
        expect(srgbToLinear(v), closeTo(legacy(v), 1e-15), reason: 'v=$v');
      }
    });
  });

  group('contrast ratio', () {
    test('black on white is 21:1', () {
      expect(contrastRatio(RgbColor.black, RgbColor.white), closeTo(21, 1e-9));
      expect(
        formatRatio(contrastRatio(RgbColor.black, RgbColor.white)),
        '21.00',
      );
    });

    test('identical colors are 1:1', () {
      expect(
        contrastRatio(const RgbColor(10, 20, 30), const RgbColor(10, 20, 30)),
        1,
      );
    });

    test('matches WebAIM reference values', () {
      String ratio(String fg, String bg) =>
          formatRatio(contrastRatio(parseColor(fg), parseColor(bg)));
      expect(ratio('#0000FF', '#FFFFFF'), '8.59');
      expect(ratio('#777777', '#FFFFFF'), '4.47');
      expect(ratio('#767676', '#FFFFFF'), '4.54');
      expect(ratio('#FF0000', '#FFFFFF'), '3.99');
      expect(ratio('#008000', '#FFFFFF'), '5.13'); // 5.1374 truncated
      expect(ratio('#1F2937', '#FFFFFF'), '14.67'); // 14.6797 truncated
    });

    test('is symmetric for opaque colors', () {
      final rnd = math.Random(1);
      for (var i = 0; i < 500; i++) {
        final a = RgbColor.fromInt(rnd.nextInt(0x1000000));
        final b = RgbColor.fromInt(rnd.nextInt(0x1000000));
        expect(contrastRatio(a, b), closeTo(contrastRatio(b, a), 1e-12));
      }
    });

    test('blends a semi-transparent foreground over the background', () {
      const fg = RgbColor(0, 0, 0, 0.5);
      final report = evaluateContrast(fg, RgbColor.white);
      expect(report.effectiveForeground, const RgbColor(128, 128, 128));
      expect(
        report.ratio,
        closeTo(
          contrastRatio(const RgbColor(128, 128, 128), RgbColor.white),
          1e-12,
        ),
      );
    });

    test('background alpha is ignored', () {
      expect(
        contrastRatio(RgbColor.black, const RgbColor(255, 255, 255, 0.2)),
        closeTo(21, 1e-9),
      );
    });
  });

  group('WCAG thresholds', () {
    test('required ratios', () {
      expect(requiredRatio(ContrastCategory.normalText, WcagLevel.aa), 4.5);
      expect(requiredRatio(ContrastCategory.normalText, WcagLevel.aaa), 7);
      expect(requiredRatio(ContrastCategory.largeText, WcagLevel.aa), 3);
      expect(requiredRatio(ContrastCategory.largeText, WcagLevel.aaa), 4.5);
      expect(requiredRatio(ContrastCategory.nonText, WcagLevel.aa), 3);
      expect(requiredRatio(ContrastCategory.nonText, WcagLevel.aaa), isNull);
    });

    test('#777 on white fails normal AA but passes large AA', () {
      final r = evaluateContrast(parseColor('#777'), RgbColor.white);
      expect(r.normalTextAA, isFalse);
      expect(r.normalTextAAA, isFalse);
      expect(r.largeTextAA, isTrue);
      expect(r.largeTextAAA, isFalse);
      expect(r.nonTextAA, isTrue);
      expect(r.rating, ContrastRating.limited);
      expect(r.passes(ContrastCategory.nonText, WcagLevel.aaa), isFalse);
    });

    test('ratings', () {
      expect(
        evaluateContrast(RgbColor.black, RgbColor.white).rating,
        ContrastRating.excellent,
      );
      expect(
        evaluateContrast(parseColor('#767676'), RgbColor.white).rating,
        ContrastRating.good,
      );
      expect(
        evaluateContrast(parseColor('#BBBBBB'), RgbColor.white).rating,
        ContrastRating.poor,
      );
    });
  });

  group('formatRatio', () {
    test('truncates instead of rounding', () {
      expect(formatRatio(4.4999), '4.49');
      expect(formatRatio(4.5), '4.50');
      expect(formatRatio(6.999999), '6.99');
      expect(formatRatio(8.5925), '8.59');
      expect(formatRatio(1), '1.00');
      expect(formatRatio(20.999999999999996), '21.00');
    });

    test('supports other precisions', () {
      expect(formatRatio(8.5925, decimals: 1), '8.5');
      expect(formatRatio(8.5925, decimals: 0), '8');
    });
  });
}
