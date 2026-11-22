import 'color_spaces.dart';

/// An sRGB color with 8-bit channels and a floating-point alpha (0–1).
final class RgbColor {
  /// Creates a color from 8-bit channels (0–255) and an optional alpha (0–1).
  const RgbColor(this.r, this.g, this.b, [this.alpha = 1.0])
    : assert(r >= 0 && r <= 255),
      assert(g >= 0 && g <= 255),
      assert(b >= 0 && b <= 255),
      assert(alpha >= 0 && alpha <= 1);

  /// Creates a color from a packed `0xRRGGBB` integer.
  factory RgbColor.fromInt(int rgb, {double alpha = 1.0}) => RgbColor(
    (rgb >> 16) & 0xFF,
    (rgb >> 8) & 0xFF,
    rgb & 0xFF,
    _clampUnit(alpha),
  );

  /// Creates a color from channels in the 0–1 range, clamping and rounding to
  /// the nearest 8-bit value.
  factory RgbColor.fromUnit(double r, double g, double b, [double alpha = 1]) =>
      RgbColor(_to8(r), _to8(g), _to8(b), _clampUnit(alpha));

  static const black = RgbColor(0, 0, 0);
  static const white = RgbColor(255, 255, 255);

  final int r;
  final int g;
  final int b;
  final double alpha;

  /// Whether the color is fully opaque.
  bool get isOpaque => alpha >= 1.0;

  /// The packed `0xRRGGBB` value (alpha excluded).
  int get rgb => (r << 16) | (g << 8) | b;

  /// The packed `0xAARRGGBB` value.
  int get argb => (alpha8 << 24) | rgb;

  /// Alpha as an 8-bit value.
  int get alpha8 => (alpha * 255).round();

  /// This color with full opacity.
  RgbColor get opaque => isOpaque ? this : RgbColor(r, g, b);

  RgbColor withAlpha(double alpha) => RgbColor(r, g, b, _clampUnit(alpha));

  /// Blends this color over an opaque [backdrop] the way browsers render
  /// semi-transparent colors (simple alpha compositing in gamma-encoded sRGB),
  /// rounding the result to 8-bit channels.
  RgbColor compositeOver(RgbColor backdrop) {
    if (isOpaque) return this;
    final a = alpha;
    int mix(int fg, int bg) => (fg * a + bg * (1 - a)).round().clamp(0, 255);
    return RgbColor(mix(r, backdrop.r), mix(g, backdrop.g), mix(b, backdrop.b));
  }

  /// Hex representation, e.g. `#0000FF` (or `#0000FF80` with [includeAlpha]).
  String toHex({
    bool leadingHash = true,
    bool includeAlpha = false,
    bool upperCase = true,
  }) {
    String two(int v) => v.toRadixString(16).padLeft(2, '0');
    var hex = '${two(r)}${two(g)}${two(b)}';
    if (includeAlpha) hex += two(alpha8);
    if (upperCase) hex = hex.toUpperCase();
    return leadingHash ? '#$hex' : hex;
  }

  /// CSS `rgb()` / `rgba()` notation.
  String toCssRgb() =>
      isOpaque ? 'rgb($r, $g, $b)' : 'rgba($r, $g, $b, ${_formatAlpha(alpha)})';

  /// CSS `hsl()` / `hsla()` notation (rounded to whole numbers).
  String toCssHsl() {
    final hsl = HslColor.fromRgb(this);
    final h = hsl.h.round() % 360;
    final s = (hsl.s * 100).round();
    final l = (hsl.l * 100).round();
    return isOpaque
        ? 'hsl($h, $s%, $l%)'
        : 'hsla($h, $s%, $l%, ${_formatAlpha(alpha)})';
  }

  @override
  bool operator ==(Object other) =>
      other is RgbColor &&
      other.r == r &&
      other.g == g &&
      other.b == b &&
      other.alpha8 == alpha8;

  @override
  int get hashCode => Object.hash(r, g, b, alpha8);

  @override
  String toString() =>
      'RgbColor(${toHex(includeAlpha: !isOpaque)}${isOpaque ? '' : ' α=$alpha'})';
}

int _to8(double unit) => (unit.clamp(0.0, 1.0) * 255).round();

double _clampUnit(double v) => v.isNaN ? 1.0 : v.clamp(0.0, 1.0).toDouble();

String _formatAlpha(double a) {
  final s = a.toStringAsFixed(2);
  // Trim trailing zeros: 0.50 -> 0.5, 1.00 -> 1
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}
