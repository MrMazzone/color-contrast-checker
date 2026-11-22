import 'dart:io' show Platform;

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:wcag_contrast/wcag_contrast.dart';

import '../../app.dart';
import '../../state/checker_controller.dart';
import '../../theme.dart';
import 'common.dart';
import 'hex_field.dart';

/// Editor for one color of the pair: swatch, text field, eyedropper,
/// opacity (foreground only) and lightness.
class ColorPanel extends StatelessWidget {
  const ColorPanel({
    super.key,
    required this.role,
    required this.onPickFromScreen,
  });

  final ColorRole role;
  final VoidCallback onPickFromScreen;

  bool get _isForeground => role == ColorRole.foreground;

  Future<void> _openPicker(
    BuildContext context,
    CheckerController checker,
  ) async {
    final current = checker.colorOf(role);
    final picked = await showColorPickerDialog(
      context,
      current.opaque.flutter,
      title: Text('${role.label} color', style: context.text.titleMedium),
      pickersEnabled: const {
        ColorPickerType.both: false,
        ColorPickerType.primary: false,
        ColorPickerType.accent: false,
        ColorPickerType.bw: false,
        ColorPickerType.custom: false,
        ColorPickerType.wheel: true,
      },
      enableShadesSelection: false,
      wheelDiameter: 260,
      wheelWidth: 18,
      wheelSquareBorderRadius: 8,
      wheelHasBorder: true,
      showColorCode: true,
      colorCodeHasColor: true,
      width: 44,
      height: 44,
      borderRadius: 10,
      actionButtons: const ColorPickerActionButtons(
        dialogActionButtons: true,
        okButton: true,
        closeButton: true,
        dialogOkButtonLabel: 'Use color',
        dialogCancelButtonLabel: 'Cancel',
      ),
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(
        copyFormat: ColorPickerCopyFormat.numHexRRGGBB,
      ),
      constraints: const BoxConstraints(minWidth: 340, maxWidth: 360),
    );
    checker.setColor(role, picked.rgb.opaque, keepAlpha: _isForeground);
  }

  @override
  Widget build(BuildContext context) {
    final checker = AppScope.of(context).checker;
    final color = checker.colorOf(role);
    final c = context.colors;
    final shortcut = Platform.isMacOS ? '⌘' : 'Ctrl+';
    final key = _isForeground ? '1' : '2';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Semantics(
                  header: true,
                  child: Text(role.label, style: context.text.titleMedium),
                ),
                const Spacer(),
                _CopyMenu(color: color),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  button: true,
                  label:
                      '${role.label} swatch ${color.toHex()}. Opens color picker.',
                  child: Tooltip(
                    message: 'Open color picker',
                    child: InkWell(
                      onTap: () => _openPicker(context, checker),
                      borderRadius: BorderRadius.circular(12),
                      child: ColorSwatchBox(color: color, size: 52),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HexField(
                    color: color,
                    label: 'Hex value',
                    allowAlpha: _isForeground,
                    onChanged: (value) => checker.setColor(role, value),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onPickFromScreen,
                  tooltip:
                      'Pick ${role.label.toLowerCase()} from screen ($shortcut$key)',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(52, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.colorize_rounded),
                  iconSize: 24,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              '${color.toCssRgb()}  ·  ${color.toCssHsl()}',
              style: context.text.bodySmall?.copyWith(
                color: c.textSecondary,
                fontFamily: monoFamily,
              ),
            ),
            if (_isForeground) ...[
              const SizedBox(height: 10),
              _SliderRow(
                label: 'Opacity',
                value: color.alpha,
                valueLabel: '${(color.alpha * 100).round()}%',
                colors: [color.withAlpha(0).flutter, color.opaque.flutter],
                checkerboard: true,
                onChanged: checker.setForegroundAlpha,
              ),
            ],
            const SizedBox(height: 4),
            _SliderRow(
              label: 'Lightness',
              value: checker.lightnessOf(role),
              valueLabel: '${(checker.lightnessOf(role) * 100).round()}%',
              colors: [
                const Color(0xFF000000),
                checker.hueColorOf(role).flutter,
                const Color(0xFFFFFFFF),
              ],
              onChanged: (v) => checker.setLightness(role, v),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.colors,
    required this.onChanged,
    this.checkerboard = false,
  });

  final String label;
  final double value;
  final String valueLabel;
  final List<Color> colors;
  final ValueChanged<double> onChanged;
  final bool checkerboard;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: GradientSlider(
            value: value,
            colors: colors,
            checkerboard: checkerboard,
            onChanged: onChanged,
            semanticLabel: label,
            valueLabel: valueLabel,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            valueLabel,
            textAlign: TextAlign.right,
            style: context.text.labelMedium?.copyWith(
              fontFamily: monoFamily,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _CopyMenu extends StatelessWidget {
  const _CopyMenu({required this.color});

  final RgbColor color;

  @override
  Widget build(BuildContext context) {
    final formats = <String, String>{
      'HEX': color.isOpaque ? color.toHex() : color.toHex(includeAlpha: true),
      'RGB': color.toCssRgb(),
      'HSL': color.toCssHsl(),
    };
    return MenuAnchor(
      menuChildren: [
        for (final entry in formats.entries)
          MenuItemButton(
            onPressed: () => copyWithFeedback(context, entry.value),
            leadingIcon: const Icon(Icons.content_copy_rounded, size: 18),
            child: Text('${entry.key}  ${entry.value}'),
          ),
      ],
      builder: (context, menu, _) => TextButton.icon(
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: const Icon(Icons.content_copy_rounded, size: 16),
        label: const Text('Copy'),
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      ),
    );
  }
}
