import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wcag_contrast/wcag_contrast.dart';

import '../../theme.dart';

/// Text field for a color. Accepts hex and anything [tryParseColor] can read
/// (`rgb()`, `hsl()`, names…), updates live while typing, and normalizes to
/// uppercase hex when focus leaves.
class HexField extends StatefulWidget {
  const HexField({
    super.key,
    required this.color,
    required this.onChanged,
    required this.label,
    this.allowAlpha = false,
  });

  final RgbColor color;
  final ValueChanged<RgbColor> onChanged;
  final String label;

  /// Whether 8-digit hex / rgba() alpha is applied (foreground only).
  final bool allowAlpha;

  @override
  State<HexField> createState() => _HexFieldState();
}

class _HexFieldState extends State<HexField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.color));
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  String _format(RgbColor c) => c.toHex(leadingHash: false);

  @override
  void didUpdateWidget(HexField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color == widget.color) return;
    // Don't fight the user while they type something that parses to this
    // color (e.g. "00f" or "rgb(0 0 255)").
    final typed = tryParseColor(_controller.text);
    if (_focus.hasFocus && typed != null && typed.rgb == widget.color.rgb) {
      return;
    }
    _setText(_format(widget.color));
  }

  void _setText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    if (_invalid) setState(() => _invalid = false);
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    } else {
      _commit();
    }
  }

  void _onChanged(String text) {
    final parsed = tryParseColor(text);
    if (parsed == null) {
      // Only flag as invalid once it can't be the start of a valid hex.
      final cleaned = text.trim().replaceFirst('#', '');
      final partialHex =
          RegExp(r'^[0-9a-fA-F]{0,8}$').hasMatch(cleaned) && cleaned.length < 6;
      final next = !partialHex && !text.contains('(');
      if (next != _invalid) setState(() => _invalid = next);
      return;
    }
    if (_invalid) setState(() => _invalid = false);
    widget.onChanged(widget.allowAlpha ? parsed : parsed.opaque);
  }

  void _commit() {
    final parsed = tryParseColor(_controller.text);
    if (parsed != null) {
      widget.onChanged(widget.allowAlpha ? parsed : parsed.opaque);
    }
    _setText(_format(widget.color));
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: _controller,
      focusNode: _focus,
      onChanged: _onChanged,
      onSubmitted: (_) => _commit(),
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: [LengthLimitingTextInputFormatter(40)],
      style: const TextStyle(
        fontFamily: monoFamily,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: '# ',
        prefixStyle: TextStyle(
          fontFamily: monoFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: c.textSecondary,
        ),
        errorText: _invalid ? 'Enter hex, rgb(), hsl() or a color name' : null,
        errorMaxLines: 2,
      ),
    );
  }
}
