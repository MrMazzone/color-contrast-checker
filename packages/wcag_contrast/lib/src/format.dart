/// Formats a contrast ratio for display, truncating (never rounding up) to
/// [decimals] places so a failing ratio such as 4.499 shows as `4.49`, never
/// as a misleading `4.50`.
String formatRatio(double ratio, {int decimals = 2}) {
  var factor = 1;
  for (var i = 0; i < decimals; i++) {
    factor *= 10;
  }
  // The tiny epsilon only absorbs floating-point noise (e.g. 20.999999999996
  // for black on white) so exact values are not truncated one step low.
  final truncated = (ratio * factor + 1e-9).floor() / factor;
  return truncated.toStringAsFixed(decimals);
}
