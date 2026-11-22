# wcag_contrast

Pure Dart WCAG 2.1 contrast toolkit used by Color Contrast Checker.

- `parseColor` / `tryParseColor`: hex (3/4/6/8 digits), `rgb()`/`rgba()`, `hsl()`/`hsla()`, CSS named colors, bare triplets.
- `contrastRatio`, `evaluateContrast`: WCAG 2.1 relative luminance and contrast ratio, with foreground alpha blended over the background.
- `formatRatio`: truncates to two decimals, so 4.499 shows as `4.49`.
- `HslColor`, `OkLab`, `OkLch`, `deltaEOk`: color spaces and perceptual difference.
- `suggestAlternatives`: the closest colors that meet a target ratio, keeping the hue, verified after 8-bit rounding.

```dart
final report = evaluateContrast(parseColor('#777'), RgbColor.white);
print(formatRatio(report.ratio)); // 4.47
print(report.normalTextAA);       // false
```
