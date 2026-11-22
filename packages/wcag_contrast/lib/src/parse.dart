import 'color.dart';
import 'color_spaces.dart';
import 'named_colors.dart';

/// Parses a color, returning `null` if [input] is not recognised.
///
/// Accepted forms (case-insensitive, surrounding whitespace ignored):
/// * Hex: `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`, with or without `#`/`0x`.
/// * `rgb()` / `rgba()` with comma or space syntax, numbers or percentages,
///   and an optional alpha (`rgb(0 0 255 / 50%)`).
/// * `hsl()` / `hsla()` with `deg`, `rad`, `grad` or `turn` hue units.
/// * CSS named colors (`rebeccapurple`, `transparent`).
/// * A bare channel triplet: `0, 0, 255` or `0 0 255`.
RgbColor? tryParseColor(String input) {
  final s = input.trim().toLowerCase().replaceAll(RegExp(r';$'), '').trim();
  if (s.isEmpty) return null;

  final named = cssNamedColors[s];
  if (named != null) return named;

  final hex = _parseHex(s);
  if (hex != null) return hex;

  final fn = RegExp(r'^(rgba?|hsla?)\((.*)\)$').firstMatch(s);
  if (fn != null) {
    final name = fn.group(1)!;
    final args = _splitArgs(fn.group(2)!);
    if (args == null) return null;
    return name.startsWith('rgb') ? _parseRgbArgs(args) : _parseHslArgs(args);
  }

  // Bare triplet such as "12, 34, 56" or "12 34 56".
  final bare = _splitArgs(s);
  if (bare != null && bare.channels.length == 3 && bare.alpha == null) {
    final values = bare.channels.map(int.tryParse).toList();
    if (values.every((v) => v != null && v >= 0 && v <= 255)) {
      return RgbColor(values[0]!, values[1]!, values[2]!);
    }
  }
  return null;
}

/// Parses a color or throws a [FormatException]. See [tryParseColor].
RgbColor parseColor(String input) {
  final color = tryParseColor(input);
  if (color == null) {
    throw FormatException('Unrecognised color', input);
  }
  return color;
}

final _hexDigits = RegExp(r'^[0-9a-f]+$');

RgbColor? _parseHex(String s) {
  var h = s;
  if (h.startsWith('#')) {
    h = h.substring(1);
  } else if (h.startsWith('0x')) {
    h = h.substring(2);
  }
  if (!_hexDigits.hasMatch(h)) return null;
  if (h.length == 3 || h.length == 4) {
    h = h.split('').map((c) => '$c$c').join();
  }
  if (h.length != 6 && h.length != 8) return null;
  final r = int.parse(h.substring(0, 2), radix: 16);
  final g = int.parse(h.substring(2, 4), radix: 16);
  final b = int.parse(h.substring(4, 6), radix: 16);
  final a = h.length == 8 ? int.parse(h.substring(6, 8), radix: 16) / 255 : 1.0;
  return RgbColor(r, g, b, a);
}

typedef _Args = ({List<String> channels, String? alpha});

/// Splits function arguments in either legacy comma syntax
/// (`a, b, c[, alpha]`) or modern space syntax (`a b c[ / alpha]`).
_Args? _splitArgs(String body) {
  final b = body.trim();
  if (b.isEmpty) return null;
  if (b.contains(',')) {
    final parts = b.split(',').map((p) => p.trim()).toList();
    if (parts.any((p) => p.isEmpty)) return null;
    if (parts.length == 3) return (channels: parts, alpha: null);
    if (parts.length == 4) {
      return (channels: parts.sublist(0, 3), alpha: parts[3]);
    }
    return null;
  }
  String? alpha;
  var main = b;
  if (b.contains('/')) {
    final halves = b.split('/');
    if (halves.length != 2) return null;
    main = halves[0].trim();
    alpha = halves[1].trim();
    if (alpha.isEmpty) return null;
  }
  final parts = main.split(RegExp(r'\s+'));
  if (parts.length != 3) return null;
  return (channels: parts, alpha: alpha);
}

double? _parseNumber(String s) {
  final v = double.tryParse(s);
  if (v == null || v.isNaN || v.isInfinite) return null;
  return v;
}

/// Parses an alpha value (`0.5` or `50%`) into 0–1.
double? _parseAlpha(String? s) {
  if (s == null) return 1.0;
  if (s.endsWith('%')) {
    final v = _parseNumber(s.substring(0, s.length - 1));
    return v == null ? null : (v / 100).clamp(0.0, 1.0);
  }
  final v = _parseNumber(s);
  return v?.clamp(0.0, 1.0);
}

RgbColor? _parseRgbArgs(_Args args) {
  final channels = <int>[];
  for (final c in args.channels) {
    double? v;
    if (c.endsWith('%')) {
      final p = _parseNumber(c.substring(0, c.length - 1));
      v = p == null ? null : p / 100 * 255;
    } else {
      v = _parseNumber(c);
    }
    if (v == null) return null;
    channels.add(v.round().clamp(0, 255));
  }
  final alpha = _parseAlpha(args.alpha);
  if (alpha == null) return null;
  return RgbColor(channels[0], channels[1], channels[2], alpha);
}

RgbColor? _parseHslArgs(_Args args) {
  final hue = _parseHue(args.channels[0]);
  final sat = _parsePercent(args.channels[1]);
  final light = _parsePercent(args.channels[2]);
  final alpha = _parseAlpha(args.alpha);
  if (hue == null || sat == null || light == null || alpha == null) {
    return null;
  }
  return HslColor(hue, sat, light).toRgb(alpha);
}

double? _parseHue(String s) {
  const units = {
    'deg': 1.0,
    'grad': 0.9,
    'rad': 57.29577951308232,
    'turn': 360.0,
  };
  for (final entry in units.entries) {
    if (s.endsWith(entry.key)) {
      final v = _parseNumber(s.substring(0, s.length - entry.key.length));
      return v == null ? null : (v * entry.value) % 360;
    }
  }
  final v = _parseNumber(s);
  return v == null ? null : v % 360;
}

/// Parses `50%` (or a bare `50`) into 0–1.
double? _parsePercent(String s) {
  final raw = s.endsWith('%') ? s.substring(0, s.length - 1) : s;
  final v = _parseNumber(raw);
  return v == null ? null : (v / 100).clamp(0.0, 1.0);
}
