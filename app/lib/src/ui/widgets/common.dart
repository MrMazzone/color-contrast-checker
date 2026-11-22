import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wcag_contrast/wcag_contrast.dart';

import '../../theme.dart';

extension RgbColorFlutter on RgbColor {
  /// The Flutter [Color], including alpha.
  Color get flutter => Color.fromARGB(alpha8, r, g, b);
}

extension FlutterColorRgb on Color {
  RgbColor get rgb => RgbColor(
    (r * 255).round().clamp(0, 255),
    (g * 255).round().clamp(0, 255),
    (b * 255).round().clamp(0, 255),
    a.clamp(0.0, 1.0),
  );
}

/// Copies [text] and shows a short confirmation.
Future<void> copyWithFeedback(
  BuildContext context,
  String text, {
  String? label,
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Copied ${label ?? text}'),
        duration: const Duration(milliseconds: 1600),
      ),
    );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// A card with a title row, used for every section of the page.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(title, style: context.text.titleMedium),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Pass / Fail pill. Never relies on color alone: it has an icon and a word.
class PassBadge extends StatelessWidget {
  const PassBadge({super.key, required this.passed, this.compact = false});

  final bool passed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: passed ? c.pass : c.fail,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            passed ? Icons.check_rounded : Icons.close_rounded,
            size: compact ? 14 : 16,
            color: c.onStatus,
          ),
          const SizedBox(width: 4),
          Text(
            passed ? 'Pass' : 'Fail',
            style: TextStyle(
              color: c.onStatus,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a transparency checkerboard (behind semi-transparent swatches).
class CheckerboardPainter extends CustomPainter {
  const CheckerboardPainter({
    required this.light,
    required this.dark,
    this.square = 6,
  });

  final Color light;
  final Color dark;
  final double square;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = light);
    final paint = Paint()..color = dark;
    for (var y = 0.0; y < size.height; y += square) {
      for (var x = 0.0; x < size.width; x += square) {
        final odd = ((x / square).floor() + (y / square).floor()).isOdd;
        if (odd) canvas.drawRect(Rect.fromLTWH(x, y, square, square), paint);
      }
    }
  }

  @override
  bool shouldRepaint(CheckerboardPainter old) =>
      old.light != light || old.dark != dark || old.square != square;
}

/// A color swatch that shows a checkerboard under semi-transparent colors.
class ColorSwatchBox extends StatelessWidget {
  const ColorSwatchBox({
    super.key,
    required this.color,
    this.size = 56,
    this.radius = 12,
    this.backdrop,
  });

  final RgbColor color;
  final double size;
  final double radius;

  /// If set, the swatch is shown over this opaque color instead of a
  /// checkerboard.
  final RgbColor? backdrop;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: color.isOpaque || backdrop != null
            ? null
            : CheckerboardPainter(light: c.checkerLight, dark: c.checkerDark),
        child: ColoredBox(
          color: (backdrop != null ? color.compositeOver(backdrop!) : color)
              .flutter,
        ),
      ),
    );
  }
}

/// A slider whose track is a gradient (lightness, opacity).
class GradientSlider extends StatelessWidget {
  const GradientSlider({
    super.key,
    required this.value,
    required this.colors,
    required this.onChanged,
    required this.semanticLabel,
    required this.valueLabel,
    this.checkerboard = false,
    this.onChangeEnd,
  });

  final double value;
  final List<Color> colors;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String semanticLabel;
  final String valueLabel;
  final bool checkerboard;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: semanticLabel,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 14,
          trackShape: _GradientTrackShape(
            colors: colors,
            checkerLight: checkerboard ? c.checkerLight : null,
            checkerDark: c.checkerDark,
            border: c.border,
          ),
          thumbShape: const _RingThumbShape(ring: Color(0xFF15151F)),
          overlayColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.16),
          // Not painted (the gradient shape draws the track) but must not be
          // transparent: Slider collapses the track height to 0 if both are.
          activeTrackColor: c.border,
          inactiveTrackColor: c.border,
          showValueIndicator: ShowValueIndicator.never,
        ),
        child: Slider(
          value: value.clamp(0.0, 1.0),
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
          semanticFormatterCallback: (_) => valueLabel,
        ),
      ),
    );
  }
}

class _GradientTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const _GradientTrackShape({
    required this.colors,
    required this.checkerDark,
    required this.border,
    this.checkerLight,
  });

  final List<Color> colors;
  final Color? checkerLight;
  final Color checkerDark;
  final Color border;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height / 2),
    );
    final canvas = context.canvas;
    canvas.save();
    canvas.clipRRect(rrect);
    if (checkerLight != null) {
      CheckerboardPainter(
        light: checkerLight!,
        dark: checkerDark,
        square: rect.height / 2,
      ).paint(canvas..translate(rect.left, rect.top), rect.size);
      canvas.translate(-rect.left, -rect.top);
    }
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(colors: colors).createShader(rect),
    );
    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = border,
    );
  }
}

class _RingThumbShape extends SliderComponentShape {
  const _RingThumbShape({required this.ring});

  final Color ring;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(22, 22);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center.translate(0, 1),
      11,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(center, 11, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      9.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = ring,
    );
  }
}
