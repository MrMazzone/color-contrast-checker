import 'package:flutter/material.dart';
import 'package:wcag_contrast/wcag_contrast.dart';

import '../../app.dart';
import '../../theme.dart';
import 'common.dart';

/// Suggests the nearest colors that meet the chosen WCAG target.
class AlternativesPanel extends StatelessWidget {
  const AlternativesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final checker = AppScope.of(context).checker;
    final result = checker.alternatives;
    final c = context.colors;
    final isNonText = checker.category == ContrastCategory.nonText;

    final controls = Wrap(
      spacing: 20,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Labeled(
          label: 'Target',
          child: SegmentedButton<WcagLevel>(
            segments: [
              const ButtonSegment(value: WcagLevel.aa, label: Text('Meet AA')),
              ButtonSegment(
                value: WcagLevel.aaa,
                label: const Text('Meet AAA'),
                enabled: !isNonText,
                tooltip: isNonText
                    ? 'WCAG defines no AAA level for UI components'
                    : null,
              ),
            ],
            selected: {checker.level},
            onSelectionChanged: (s) => checker.setLevel(s.first),
          ),
        ),
        _Labeled(
          label: 'For',
          child: SegmentedButton<ContrastCategory>(
            segments: const [
              ButtonSegment(
                value: ContrastCategory.normalText,
                label: Text('Normal text'),
              ),
              ButtonSegment(
                value: ContrastCategory.largeText,
                label: Text('Large text'),
              ),
              ButtonSegment(
                value: ContrastCategory.nonText,
                label: Text('UI & graphics'),
              ),
            ],
            selected: {checker.category},
            onSelectionChanged: (s) => checker.setCategory(s.first),
          ),
        ),
        _Labeled(
          label: 'Adjust',
          child: SegmentedButton<AdjustTarget>(
            segments: const [
              ButtonSegment(
                value: AdjustTarget.foreground,
                label: Text('Foreground'),
              ),
              ButtonSegment(
                value: AdjustTarget.background,
                label: Text('Background'),
              ),
            ],
            selected: {checker.adjust},
            onSelectionChanged: (s) => checker.setAdjust(s.first),
          ),
        ),
      ],
    );

    final target =
        '${checker.level.label} for ${checker.category.label.toLowerCase()}';

    Widget body;
    if (result.alreadyPasses) {
      body = _Banner(
        icon: Icons.check_circle_rounded,
        color: c.pass,
        message:
            'These colors already meet $target '
            '(${formatRatio(result.currentRatio)}:1 ≥ ${_fmt(result.targetRatio)}:1).',
        action: checker.level == WcagLevel.aa && !isNonText
            ? TextButton(
                onPressed: () => checker.setLevel(WcagLevel.aaa),
                child: const Text('Try AAA'),
              )
            : null,
      );
    } else {
      body = Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (i, s) in result.suggestions.indexed)
            _SuggestionCard(
              suggestion: s,
              adjust: checker.adjust,
              title: [
                i == 0 ? 'Closest match' : '${s.direction.label} alternative',
                if (s.alphaChanged) '100% opacity',
              ].join(' · '),
            ),
          _SuggestionCard(
            suggestion: result.fallback,
            adjust: checker.adjust,
            title: 'Best-contrast fallback',
            isFallback: true,
          ),
        ],
      );
      if (result.suggestions.isEmpty) {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Banner(
              icon: Icons.info_rounded,
              color: c.warn,
              message:
                  'No ${checker.adjust.label.toLowerCase()} with the same hue reaches '
                  '${_fmt(result.targetRatio)}:1 here. Try adjusting the other color, '
                  'or use the fallback.',
            ),
            const SizedBox(height: 12),
            body,
          ],
        );
      }
    }

    return SectionCard(
      title: 'Better alternatives',
      subtitle:
          'The closest colors that meet $target, keeping the same hue. '
          'Ordered by how little they change.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [controls, const SizedBox(height: 16), body],
      ),
    );
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: context.text.labelLarge?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        child,
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: context.text.bodyMedium)),
          ?action,
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.adjust,
    required this.title,
    this.isFallback = false,
  });

  final ColorSuggestion suggestion;
  final AdjustTarget adjust;
  final String title;
  final bool isFallback;

  @override
  Widget build(BuildContext context) {
    final checker = AppScope.of(context).checker;
    final c = context.colors;
    final s = suggestion;
    final fg = adjust == AdjustTarget.foreground ? s.color : checker.foreground;
    final bg = adjust == AdjustTarget.background ? s.color : checker.background;
    final hex = s.color.toHex();

    return SizedBox(
      width: 236,
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFallback
                ? c.border
                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: context.text.labelMedium?.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              height: 64,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: bg.flutter,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.border),
              ),
              child: Text(
                'Aa  Sample',
                style: TextStyle(
                  color: fg.flutter,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ColorSwatchBox(color: s.color, size: 28, radius: 7),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        hex,
                        style: const TextStyle(
                          fontFamily: monoFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Ratio ${formatRatio(s.ratio)}:1',
                        style: context.text.bodySmall?.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        s.magnitude.label,
                        style: context.text.bodySmall?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: isFallback
                      ? OutlinedButton(
                          onPressed: () => checker.applySuggestion(s),
                          child: const Text('Apply'),
                        )
                      : FilledButton(
                          onPressed: () => checker.applySuggestion(s),
                          child: const Text('Apply'),
                        ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Copy $hex',
                  onPressed: () => copyWithFeedback(context, hex),
                  icon: const Icon(Icons.content_copy_rounded, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
