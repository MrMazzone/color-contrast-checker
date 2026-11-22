import 'package:test/test.dart';
import 'package:wcag_contrast/wcag_contrast.dart';

void main() {
  const blue = RgbColor(0, 0, 255);

  group('hex', () {
    test('6 and 3 digit, with or without #, any case', () {
      for (final s in [
        '#0000FF',
        '0000ff',
        '#00f',
        '00F',
        '0x0000FF',
        '  #0000fF  ',
      ]) {
        expect(tryParseColor(s), blue, reason: s);
      }
    });

    test('8 and 4 digit carry alpha', () {
      final c = parseColor('#0000FF80');
      expect(c.rgb, 0x0000FF);
      expect(c.alpha, closeTo(128 / 255, 1e-9));
      expect(parseColor('#00f8').alpha, closeTo(0x88 / 255, 1e-9));
    });

    test('rejects bad lengths and characters', () {
      for (final s in ['#12', '#12345', '#1234567', '#GGGGGG', '#', '']) {
        expect(tryParseColor(s), isNull, reason: s);
      }
    });
  });

  group('rgb()', () {
    test('legacy comma syntax', () {
      expect(parseColor('rgb(0, 0, 255)'), blue);
      expect(parseColor('RGB(0,0,255);'), blue);
      final c = parseColor('rgba(0, 0, 255, .5)');
      expect(c.rgb, 0x0000FF);
      expect(c.alpha, 0.5);
    });

    test('modern space syntax with slash alpha', () {
      expect(parseColor('rgb(0 0 255)'), blue);
      final c = parseColor('rgb(0 0 255 / 50%)');
      expect(c.alpha, 0.5);
    });

    test('percent channels and clamping', () {
      expect(parseColor('rgb(0%, 0%, 100%)'), blue);
      expect(parseColor('rgb(300, -5, 0)'), const RgbColor(255, 0, 0));
    });

    test('rejects malformed input', () {
      for (final s in ['rgb(0, 0)', 'rgb(a, b, c)', 'rgb(0 0 0 /)', 'rgb()']) {
        expect(tryParseColor(s), isNull, reason: s);
      }
    });
  });

  group('hsl()', () {
    test('basic', () {
      expect(parseColor('hsl(240, 100%, 50%)'), blue);
      expect(parseColor('hsl(240deg 100% 50%)'), blue);
      expect(parseColor('hsl(0.6666667turn 100% 50%)'), blue);
      expect(parseColor('hsla(240, 100%, 50%, 0.25)').alpha, 0.25);
      expect(parseColor('hsl(0, 0%, 100%)'), RgbColor.white);
    });
  });

  group('named and bare', () {
    test('CSS named colors', () {
      expect(parseColor('blue'), blue);
      expect(parseColor('RebeccaPurple'), const RgbColor(0x66, 0x33, 0x99));
      expect(parseColor('transparent').alpha, 0);
    });

    test('bare triplets', () {
      expect(parseColor('0, 0, 255'), blue);
      expect(parseColor('0 0 255'), blue);
      expect(tryParseColor('0 0 256'), isNull);
    });

    test('parseColor throws on garbage', () {
      expect(() => parseColor('not a color'), throwsFormatException);
    });
  });

  group('formatting', () {
    test('hex output', () {
      expect(blue.toHex(), '#0000FF');
      expect(blue.toHex(leadingHash: false, upperCase: false), '0000ff');
      expect(blue.withAlpha(0.5).toHex(includeAlpha: true), '#0000FF80');
    });

    test('css output', () {
      expect(blue.toCssRgb(), 'rgb(0, 0, 255)');
      expect(blue.withAlpha(0.5).toCssRgb(), 'rgba(0, 0, 255, 0.5)');
      expect(blue.toCssHsl(), 'hsl(240, 100%, 50%)');
    });
  });
}
