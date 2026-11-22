import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme.dart';

/// Collapsible "how this works" section with links to the WCAG criteria.
class ExplanationCard extends StatelessWidget {
  const ExplanationCard({super.key});

  static final _links = <(String, String)>[
    (
      'SC 1.4.3 Contrast (Minimum)',
      'https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html',
    ),
    (
      'SC 1.4.6 Contrast (Enhanced)',
      'https://www.w3.org/WAI/WCAG21/Understanding/contrast-enhanced.html',
    ),
    (
      'SC 1.4.11 Non-text Contrast',
      'https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = context.text.bodyMedium?.copyWith(height: 1.5);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Icon(Icons.menu_book_rounded, color: c.textSecondary),
          title: Text(
            'How WCAG 2.1 contrast works',
            style: context.text.titleMedium,
          ),
          children: [
            Text(
              'Enter colors as hex, rgb(), hsl() or a CSS color name, use the '
              'color picker, or pick from anywhere on screen with the '
              'eyedropper. Opacity blends the foreground over the background '
              'exactly as a browser renders it; lightness adjusts the HSL '
              'lightness while keeping the hue.',
              style: body,
            ),
            const SizedBox(height: 12),
            Text(
              'WCAG 2.1 Level AA requires a contrast ratio of at least 4.5:1 '
              'for normal text and 3:1 for large text. Graphics and user '
              'interface components (icons, focus indicators, form input '
              'borders) need at least 3:1. Level AAA requires 7:1 for normal '
              'text and 4.5:1 for large text.',
              style: body,
            ),
            const SizedBox(height: 12),
            Text(
              'Large text is at least 18 point (24px), or 14 point (about '
              '18.66px) when bold.',
              style: body,
            ),
            const SizedBox(height: 12),
            Text(
              'The ratio is (L1 + 0.05) / (L2 + 0.05), where L1 and L2 are the '
              'relative luminances of the lighter and darker colors. It is '
              'shown truncated to two decimals, so 4.499:1 reads 4.49 and '
              'fails rather than rounding up to a misleading 4.50.',
              style: body,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, url) in _links)
                  ActionChip(
                    avatar: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text(label),
                    onPressed: () => launchUrl(Uri.parse(url)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
