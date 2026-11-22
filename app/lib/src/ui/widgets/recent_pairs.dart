import 'package:flutter/material.dart';
import 'package:wcag_contrast/wcag_contrast.dart';

import '../../app.dart';
import '../../theme.dart';
import 'common.dart';

/// The most recent color pairs, restorable with one click.
class RecentPairs extends StatelessWidget {
  const RecentPairs({super.key});

  @override
  Widget build(BuildContext context) {
    final checker = AppScope.of(context).checker;
    final recent = checker.recent;
    final c = context.colors;

    return SectionCard(
      title: 'Recent',
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      trailing: recent.isEmpty
          ? null
          : TextButton(
              onPressed: checker.clearRecent,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('Clear'),
            ),
      child: recent.isEmpty
          ? Text(
              'Color pairs you check appear here.',
              style: context.text.bodySmall?.copyWith(color: c.textSecondary),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pair in recent)
                  _PairChip(
                    foreground: pair.foreground,
                    background: pair.background,
                    ratio: pair.ratio,
                    onTap: () => checker.restorePair(pair),
                  ),
              ],
            ),
    );
  }
}

class _PairChip extends StatelessWidget {
  const _PairChip({
    required this.foreground,
    required this.background,
    required this.ratio,
    required this.onTap,
  });

  final RgbColor foreground;
  final RgbColor background;
  final double ratio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label =
        '${foreground.toHex()} on ${background.toHex()} · ${formatRatio(ratio)}:1';
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: 'Restore $label',
        excludeSemantics: true,
        child: Material(
          color: background.flutter,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: context.colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 52,
              height: 40,
              child: Center(
                child: Text(
                  'Aa',
                  style: TextStyle(
                    color: foreground.flutter,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
