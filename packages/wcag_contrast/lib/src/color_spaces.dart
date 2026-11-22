import 'dart:math' as math;

import 'color.dart';

/// Converts an 8-bit gamma-encoded sRGB channel to linear light (0–1).
///
/// Uses the IEC 61966-2-1 threshold of 0.04045. The WCAG 2.1 text prints
/// 0.03928 (a known erratum, corrected in WCAG 2.2); the two produce identical
/// results for every 8-bit value.
double srgbToLinear(int channel8) {
  final c = channel8 / 255.0;
  return srgbUnitToLinear(c);
}

/// Converts a gamma-encoded sRGB channel in the 0–1 range to linear light.
double srgbUnitToLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// Converts a linear-light channel (0–1) to gamma-encoded sRGB (0–1).
double linearToSrgbUnit(double c) {
  if (c <= 0.0031308) return 12.92 * c;
  return 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;
}

/// HSL color with hue in degrees (0–360) and saturation/lightness in 0–1.
final class HslColor {
  const HslColor(this.h, this.s, this.l);

  factory HslColor.fromRgb(RgbColor color) {
    final r = color.r / 255.0;
    final g = color.g / 255.0;
    final b = color.b / 255.0;
    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    final l = (maxC + minC) / 2;
    final d = maxC - minC;
    if (d == 0) return HslColor(0, 0, l);
    final s = d / (1 - (2 * l - 1).abs());
    double h;
    if (maxC == r) {
      h = 60 * (((g - b) / d) % 6);
    } else if (maxC == g) {
      h = 60 * ((b - r) / d + 2);
    } else {
      h = 60 * ((r - g) / d + 4);
    }
    if (h < 0) h += 360;
    return HslColor(h, s.clamp(0.0, 1.0), l);
  }

  final double h;
  final double s;
  final double l;

  HslColor withLightness(double lightness) =>
      HslColor(h, s, lightness.clamp(0.0, 1.0));

  RgbColor toRgb([double alpha = 1.0]) {
    final c = (1 - (2 * l - 1).abs()) * s;
    final hp = (h % 360) / 60;
    final x = c * (1 - (hp % 2 - 1).abs());
    double r1 = 0, g1 = 0, b1 = 0;
    if (hp < 1) {
      r1 = c;
      g1 = x;
    } else if (hp < 2) {
      r1 = x;
      g1 = c;
    } else if (hp < 3) {
      g1 = c;
      b1 = x;
    } else if (hp < 4) {
      g1 = x;
      b1 = c;
    } else if (hp < 5) {
      r1 = x;
      b1 = c;
    } else {
      r1 = c;
      b1 = x;
    }
    final m = l - c / 2;
    return RgbColor.fromUnit(r1 + m, g1 + m, b1 + m, alpha);
  }

  @override
  String toString() => 'HslColor($h, $s, $l)';
}

/// A color in the OKLab perceptual color space.
final class OkLab {
  const OkLab(this.l, this.a, this.b);

  factory OkLab.fromRgb(RgbColor color) => OkLab.fromLinearSrgb(
    srgbToLinear(color.r),
    srgbToLinear(color.g),
    srgbToLinear(color.b),
  );

  factory OkLab.fromLinearSrgb(double r, double g, double b) {
    final l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
    final m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
    final s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;
    final l_ = _cbrt(l);
    final m_ = _cbrt(m);
    final s_ = _cbrt(s);
    return OkLab(
      0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
      1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
      0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
    );
  }

  final double l;
  final double a;
  final double b;

  /// Linear-light sRGB channels; may fall outside 0–1 for out-of-gamut colors.
  ({double r, double g, double b}) toLinearSrgb() {
    final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = l - 0.0894841775 * a - 1.2914855480 * b;
    final l3 = l_ * l_ * l_;
    final m3 = m_ * m_ * m_;
    final s3 = s_ * s_ * s_;
    return (
      r: 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
      g: -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
      b: -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3,
    );
  }

  OkLch toLch() {
    final c = math.sqrt(a * a + b * b);
    var h = math.atan2(b, a) * 180 / math.pi;
    if (h < 0) h += 360;
    return OkLch(l, c, h);
  }

  @override
  String toString() => 'OkLab($l, $a, $b)';
}

/// A color in OKLCH (cylindrical OKLab): lightness 0–1, chroma ≥ 0, hue in
/// degrees.
final class OkLch {
  const OkLch(this.l, this.c, this.h);

  factory OkLch.fromRgb(RgbColor color) => OkLab.fromRgb(color).toLch();

  final double l;
  final double c;
  final double h;

  OkLab toLab() {
    final rad = h * math.pi / 180;
    return OkLab(l, c * math.cos(rad), c * math.sin(rad));
  }

  /// Whether this color is inside the sRGB gamut (with a tiny tolerance).
  bool get isInSrgbGamut {
    final lin = toLab().toLinearSrgb();
    const eps = 1e-6;
    return lin.r >= -eps &&
        lin.r <= 1 + eps &&
        lin.g >= -eps &&
        lin.g <= 1 + eps &&
        lin.b >= -eps &&
        lin.b <= 1 + eps;
  }

  /// Maps to sRGB, reducing chroma (keeping lightness and hue) until the color
  /// fits in gamut, then rounds to 8-bit channels.
  RgbColor toRgbGamutMapped([double alpha = 1.0]) {
    final lightness = l.clamp(0.0, 1.0);
    if (lightness >= 1.0) return RgbColor.white.withAlpha(alpha);
    if (lightness <= 0.0) return RgbColor.black.withAlpha(alpha);
    var candidate = OkLch(lightness, c, h);
    if (!candidate.isInSrgbGamut) {
      var lo = 0.0;
      var hi = c;
      for (var i = 0; i < 24; i++) {
        final mid = (lo + hi) / 2;
        if (OkLch(lightness, mid, h).isInSrgbGamut) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      candidate = OkLch(lightness, lo, h);
    }
    final lin = candidate.toLab().toLinearSrgb();
    return RgbColor.fromUnit(
      linearToSrgbUnit(lin.r.clamp(0.0, 1.0)),
      linearToSrgbUnit(lin.g.clamp(0.0, 1.0)),
      linearToSrgbUnit(lin.b.clamp(0.0, 1.0)),
      alpha,
    );
  }

  @override
  String toString() => 'OkLch($l, $c, $h)';
}

/// Perceptual color difference: Euclidean distance in OKLab, scaled ×100 so
/// that ~2 is roughly a just-noticeable difference.
double deltaEOk(RgbColor a, RgbColor b) {
  final x = OkLab.fromRgb(a);
  final y = OkLab.fromRgb(b);
  final dl = x.l - y.l;
  final da = x.a - y.a;
  final db = x.b - y.b;
  return math.sqrt(dl * dl + da * da + db * db) * 100;
}

/// How visible a color change of [deltaE] (from [deltaEOk]) is.
enum ChangeMagnitude {
  imperceptible('Imperceptible change'),
  subtle('Subtle change'),
  noticeable('Noticeable change'),
  significant('Significant change');

  const ChangeMagnitude(this.label);

  final String label;

  static ChangeMagnitude of(double deltaE) {
    if (deltaE < 2) return imperceptible;
    if (deltaE < 6) return subtle;
    if (deltaE < 15) return noticeable;
    return significant;
  }
}

double _cbrt(double x) =>
    x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();
