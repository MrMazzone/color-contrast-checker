/// WCAG 2.1 color contrast toolkit.
///
/// * [RgbColor] — an 8-bit sRGB color with alpha.
/// * [parseColor] / [tryParseColor] — accepts hex, `rgb()`, `hsl()`, CSS
///   color names and bare channel triplets.
/// * [contrastRatio] / [evaluateContrast] — WCAG 2.1 relative luminance and
///   contrast ratio, including foreground alpha blending.
/// * [suggestAlternatives] — the nearest colors that meet a target ratio.
library;

export 'src/alternatives.dart';
export 'src/color.dart';
export 'src/color_spaces.dart';
export 'src/format.dart';
export 'src/parse.dart';
export 'src/wcag.dart';
