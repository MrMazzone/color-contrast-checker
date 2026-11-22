import 'package:flutter/material.dart';
import 'package:wcag_contrast/wcag_contrast.dart';

import '../../app.dart';
import '../../theme.dart';
import 'common.dart';

/// Pass/fail results for each WCAG 2.1 contrast criterion, with previews.
class ResultsSection extends StatelessWidget {
  const ResultsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final checker = AppScope.of(context).checker;
    final report = checker.report;
    final fg = report.foreground.flutter;
    final bg = report.background.flutter;
    final sample = checker.previewText.isEmpty ? ' ' : checker.previewText;

    List<Widget> buildCards({required bool fillHeight}) => [
      _ResultCard(
        fillHeight: fillHeight,
        title: 'Normal text',
        criteria: 'SC 1.4.3 & 1.4.6',
        rows: [
          _Row(WcagLevel.aa, 4.5, report.normalTextAA),
          _Row(WcagLevel.aaa, 7, report.normalTextAAA),
        ],
        preview: _PreviewBox(
          background: bg,
          child: Text(sample, style: TextStyle(color: fg, fontSize: 16)),
        ),
      ),
      _ResultCard(
        fillHeight: fillHeight,
        title: 'Large text',
        criteria: '≥ 24px, or ≥ 18.66px bold',
        rows: [
          _Row(WcagLevel.aa, 3, report.largeTextAA),
          _Row(WcagLevel.aaa, 4.5, report.largeTextAAA),
        ],
        preview: _PreviewBox(
          background: bg,
          child: Text(
            sample,
            style: TextStyle(
              color: fg,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      _ResultCard(
        fillHeight: fillHeight,
        title: 'Graphics & UI components',
        criteria: 'SC 1.4.11',
        rows: [_Row(WcagLevel.aa, 3, report.nonTextAA)],
        preview: _PreviewBox(
          background: bg,
          child: _UiSample(color: fg),
        ),
      ),
    ];

    return SectionCard(
      title: 'WCAG 2.1 results',
      subtitle: 'Pass/fail uses the exact ratio, not the rounded one.',
      trailing: SizedBox(
        width: 300,
        child: _PreviewTextField(
          value: checker.previewText,
          onChanged: checker.setPreviewText,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 760) {
            final cards = buildCards(fillHeight: true);
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: cards[i]),
                  ],
                ],
              ),
            );
          }
          final cards = buildCards(fillHeight: false);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                cards[i],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Row {
  const _Row(this.level, this.required, this.passed);
  final WcagLevel level;
  final double required;
  final bool passed;
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.fillHeight,
    required this.title,
    required this.criteria,
    required this.rows,
    required this.preview,
  });

  /// Push the preview to the bottom (when cards share a row height).
  final bool fillHeight;
  final String title;
  final String criteria;
  final List<_Row> rows;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: context.text.titleSmall),
          ),
          Text(
            criteria,
            style: context.text.bodySmall?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 10),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: MergeSemantics(
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        row.level.label,
                        style: context.text.labelLarge,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '≥ ${_fmt(row.required)}:1',
                        style: context.text.bodySmall?.copyWith(
                          color: c.textSecondary,
                          fontFamily: monoFamily,
                        ),
                      ),
                    ),
                    PassBadge(passed: row.passed, compact: true),
                  ],
                ),
              ),
            ),
          if (fillHeight) const Spacer(),
          const SizedBox(height: 6),
          preview,
        ],
      ),
    );
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.background, required this.child});

  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: child,
    );
  }
}

class _UiSample extends StatelessWidget {
  const _UiSample({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(Icons.star_rounded, color: color, size: 30),
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Text input',
            style: TextStyle(color: color, fontSize: 13),
          ),
        ),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(Icons.check_rounded, size: 16, color: color),
        ),
      ],
    );
  }
}

class _PreviewTextField extends StatefulWidget {
  const _PreviewTextField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_PreviewTextField> createState() => _PreviewTextFieldState();
}

class _PreviewTextFieldState extends State<_PreviewTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      style: context.text.bodyMedium,
      decoration: const InputDecoration(
        labelText: 'Sample text',
        prefixIcon: Icon(Icons.edit_rounded, size: 18),
      ),
    );
  }
}
