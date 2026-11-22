import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wcag_contrast/wcag_contrast.dart';

import '../../app.dart';
import '../../theme.dart';
import 'common.dart';

/// The headline: contrast ratio, overall rating, a ratio meter with WCAG
/// thresholds, and a live preview in the actual colors.
class RatioCard extends StatelessWidget {
  const RatioCard({super.key});

  @override
  Widget build(BuildContext context) {
    final checker = AppScope.of(context).checker;
    final report = checker.report;
    final c = context.colors;
    final ratioText = formatRatio(report.ratio);
    final (statusColor, statusIcon) = switch (report.rating) {
      ContrastRating.excellent => (c.pass, Icons.verified_rounded),
      ContrastRating.good => (c.pass, Icons.check_circle_rounded),
      ContrastRating.limited => (c.warn, Icons.error_rounded),
      ContrastRating.poor => (c.fail, Icons.cancel_rounded),
    };

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Contrast ratio',
          style: context.text.labelLarge?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 2),
        Semantics(
          liveRegion: true,
          label: 'Contrast ratio $ratioText to 1. ${report.rating.summary}.',
          excludeSemantics: true,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: ratioText,
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                    height: 1.05,
                  ),
                ),
                TextSpan(
                  text: ':1',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 16, color: c.onStatus),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  report.rating.summary,
                  style: TextStyle(
                    color: c.onStatus,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!report.foreground.isOpaque) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorSwatchBox(
                color: report.effectiveForeground,
                size: 18,
                radius: 4,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Foreground at ${(report.foreground.alpha * 100).round()}% '
                  'renders as ${report.effectiveForeground.toHex()}',
                  style: context.text.bodySmall?.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        _RatioMeter(ratio: report.ratio),
      ],
    );

    final preview = _LivePreview(
      foreground: report.foreground,
      background: report.background,
      text: checker.previewText,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [summary, const SizedBox(height: 16), preview],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: summary),
                  const SizedBox(width: 20),
                  Expanded(flex: 6, child: preview),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  const _LivePreview({
    required this.foreground,
    required this.background,
    required this.text,
  });

  final RgbColor foreground;
  final RgbColor background;
  final String text;

  @override
  Widget build(BuildContext context) {
    final fg = foreground.flutter;
    return Semantics(
      label: 'Preview of the foreground color on the background color',
      child: Container(
        decoration: BoxDecoration(
          color: background.flutter,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Aa',
                  style: TextStyle(
                    color: fg,
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(Icons.star_rounded, color: fg, size: 34),
                const SizedBox(width: 6),
                Icon(Icons.favorite_rounded, color: fg, size: 30),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              text.isEmpty ? ' ' : text,
              style: TextStyle(
                color: fg,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Body copy at 16px is held to the strictest requirement: '
              '4.5:1 for AA and 7:1 for AAA.',
              style: TextStyle(color: fg, fontSize: 16, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal meter from 1:1 to 21:1 on a log scale, with markers at the
/// WCAG thresholds. Painted directly (no LayoutBuilder) so it works inside
/// intrinsic-height rows.
class _RatioMeter extends StatelessWidget {
  const _RatioMeter({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: ratio.clamp(1, 21).toDouble()),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        builder: (context, value, _) => SizedBox(
          height: 34,
          width: double.infinity,
          child: CustomPaint(
            painter: _MeterPainter(
              ratio: value,
              track: c.surfaceMuted,
              border: c.border,
              marker: c.textPrimary,
              label: c.textSecondary,
              labelStyle: context.text.labelSmall!,
            ),
          ),
        ),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  _MeterPainter({
    required this.ratio,
    required this.track,
    required this.border,
    required this.marker,
    required this.label,
    required this.labelStyle,
  });

  final double ratio;
  final Color track;
  final Color border;
  final Color marker;
  final Color label;
  final TextStyle labelStyle;

  static double _pos(double r) => math.log(r) / math.log(21);

  @override
  void paint(Canvas canvas, Size size) {
    const barHeight = 8.0;
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, barHeight),
      const Radius.circular(4),
    );
    canvas.drawRRect(bar, Paint()..color = track);
    final fillWidth = _pos(ratio) * size.width;
    if (fillWidth > 0) {
      final fillRect = Rect.fromLTWH(0, 0, fillWidth, barHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, const Radius.circular(4)),
        Paint()
          ..shader = AppColors.brandGradient.createShader(
            Rect.fromLTWH(0, 0, size.width, barHeight),
          ),
      );
    }
    canvas.drawRRect(
      bar,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = border,
    );

    for (final (value, text) in const [
      (3.0, '3:1'),
      (4.5, '4.5:1'),
      (7.0, '7:1'),
    ]) {
      final x = _pos(value) * size.width;
      canvas.drawRect(Rect.fromLTWH(x - 1, -3, 2, 14), Paint()..color = marker);
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: labelStyle.copyWith(
            color: ratio >= value ? marker : label,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, 15));
    }
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.ratio != ratio ||
      old.track != track ||
      old.marker != marker ||
      old.label != label;
}
