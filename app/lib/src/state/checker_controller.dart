import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wcag_contrast/wcag_contrast.dart';

import '../services/preferences_store.dart';

/// Which of the two colors an action targets.
enum ColorRole {
  foreground('Foreground'),
  background('Background');

  const ColorRole(this.label);
  final String label;
}

/// App state: the color pair, alternative-suggestion settings and history.
class CheckerController extends ChangeNotifier {
  CheckerController(this._store, StoredState initial)
    : _foreground = initial.foreground,
      _background = initial.background.opaque,
      _level = initial.level,
      _category = initial.category,
      _adjust = initial.adjust,
      _previewText = initial.previewText,
      _recent = List.of(initial.recent) {
    _fgHsl = HslColor.fromRgb(_foreground);
    _bgHsl = HslColor.fromRgb(_background);
    _normalizeLevel();
  }

  static const maxRecent = 12;
  static const _historyDelay = Duration(milliseconds: 1500);
  static const _saveDelay = Duration(milliseconds: 400);

  final PreferencesStore _store;

  RgbColor _foreground;
  RgbColor _background;

  // Hue/saturation anchors so dragging lightness to black or white and back
  // doesn't lose the original hue.
  late HslColor _fgHsl;
  late HslColor _bgHsl;

  WcagLevel _level;
  ContrastCategory _category;
  AdjustTarget _adjust;
  String _previewText;
  final List<ColorPair> _recent;

  ContrastReport? _report;
  AlternativesResult? _alternatives;
  Timer? _historyTimer;
  Timer? _saveTimer;

  RgbColor get foreground => _foreground;
  RgbColor get background => _background;
  WcagLevel get level => _level;
  ContrastCategory get category => _category;
  AdjustTarget get adjust => _adjust;
  String get previewText => _previewText;
  List<ColorPair> get recent => List.unmodifiable(_recent);

  RgbColor colorOf(ColorRole role) =>
      role == ColorRole.foreground ? _foreground : _background;

  /// HSL lightness (0–1) shown on the lightness slider.
  double lightnessOf(ColorRole role) =>
      role == ColorRole.foreground ? _fgHsl.l : _bgHsl.l;

  /// The fully saturated mid-lightness color used for the slider gradient.
  RgbColor hueColorOf(ColorRole role) {
    final hsl = role == ColorRole.foreground ? _fgHsl : _bgHsl;
    return HslColor(hsl.h, hsl.s, 0.5).toRgb();
  }

  ContrastReport get report =>
      _report ??= evaluateContrast(_foreground, _background);

  /// Required ratio for the current target, never null: AAA is not defined
  /// for non-text, so the level is normalized to AA in that case.
  double get targetRatio => requiredRatio(_category, _level)!;

  AlternativesResult get alternatives => _alternatives ??= suggestAlternatives(
    foreground: _foreground,
    background: _background,
    targetRatio: targetRatio,
    adjust: _adjust,
  );

  void setColor(ColorRole role, RgbColor color, {bool keepAlpha = false}) {
    if (role == ColorRole.foreground) {
      final next = keepAlpha ? color.withAlpha(_foreground.alpha) : color;
      if (next == _foreground) return;
      _foreground = next;
      _fgHsl = HslColor.fromRgb(next);
    } else {
      final next = color.opaque;
      if (next == _background) return;
      _background = next;
      _bgHsl = HslColor.fromRgb(next);
    }
    _changed();
  }

  void setForegroundAlpha(double alpha) {
    final next = _foreground.withAlpha(alpha);
    if (next == _foreground) return;
    _foreground = next;
    _changed();
  }

  void setLightness(ColorRole role, double lightness) {
    if (role == ColorRole.foreground) {
      _fgHsl = _fgHsl.withLightness(lightness);
      _foreground = _fgHsl.toRgb(_foreground.alpha);
    } else {
      _bgHsl = _bgHsl.withLightness(lightness);
      _background = _bgHsl.toRgb();
    }
    _changed();
  }

  void swap() {
    final fg = _foreground;
    _foreground = _background.withAlpha(fg.alpha);
    _background = fg.opaque;
    final h = _fgHsl;
    _fgHsl = _bgHsl;
    _bgHsl = h;
    _changed();
  }

  void applySuggestion(ColorSuggestion suggestion) {
    if (_adjust == AdjustTarget.foreground) {
      setColor(ColorRole.foreground, suggestion.color);
    } else {
      setColor(ColorRole.background, suggestion.color);
    }
    _commitHistoryNow();
  }

  void restorePair(ColorPair pair) {
    _foreground = pair.foreground;
    _background = pair.background.opaque;
    _fgHsl = HslColor.fromRgb(_foreground);
    _bgHsl = HslColor.fromRgb(_background);
    _changed(recordHistory: false);
  }

  void clearRecent() {
    _recent.clear();
    unawaited(_store.saveRecent(_recent));
    notifyListeners();
  }

  void setLevel(WcagLevel level) {
    if (_level == level) return;
    _level = level;
    _normalizeLevel();
    _settingsChanged();
  }

  void setCategory(ContrastCategory category) {
    if (_category == category) return;
    _category = category;
    _normalizeLevel();
    _settingsChanged();
  }

  void setAdjust(AdjustTarget adjust) {
    if (_adjust == adjust) return;
    _adjust = adjust;
    _settingsChanged();
  }

  void setPreviewText(String text) {
    if (text == _previewText) return;
    _previewText = text;
    unawaited(_store.savePreviewText(text));
    notifyListeners();
  }

  /// Plain-text/Markdown summary for the clipboard.
  String buildReport() {
    final r = report;
    String verdict(ContrastCategory c, WcagLevel l) {
      final req = requiredRatio(c, l);
      if (req == null) return '—';
      final ok = r.passes(c, l);
      return '${ok ? 'Pass' : 'Fail'} (≥ ${_trim(req)}:1)';
    }

    final fg = _foreground;
    final buffer = StringBuffer()
      ..writeln(
        'Foreground: ${fg.toHex()}'
        '${fg.isOpaque ? '' : ' at ${(fg.alpha * 100).round()}% opacity '
                  '(renders as ${r.effectiveForeground.toHex()})'}',
      )
      ..writeln('Background: ${_background.toHex()}')
      ..writeln('Contrast ratio: ${formatRatio(r.ratio)}:1')
      ..writeln()
      ..writeln('| WCAG 2.1 | AA | AAA |')
      ..writeln('| --- | --- | --- |')
      ..writeln(
        '| Normal text | ${verdict(ContrastCategory.normalText, WcagLevel.aa)} '
        '| ${verdict(ContrastCategory.normalText, WcagLevel.aaa)} |',
      )
      ..writeln(
        '| Large text | ${verdict(ContrastCategory.largeText, WcagLevel.aa)} '
        '| ${verdict(ContrastCategory.largeText, WcagLevel.aaa)} |',
      )
      ..writeln(
        '| Graphics & UI components | '
        '${verdict(ContrastCategory.nonText, WcagLevel.aa)} | — |',
      )
      ..writeln()
      ..write(
        'Checked with Color Contrast Checker · color-contrast.joemazzone.net',
      );
    return buffer.toString();
  }

  void _normalizeLevel() {
    if (requiredRatio(_category, _level) == null) _level = WcagLevel.aa;
  }

  void _settingsChanged() {
    _alternatives = null;
    unawaited(_store.saveAlternativeSettings(_level, _category, _adjust));
    notifyListeners();
  }

  void _changed({bool recordHistory = true}) {
    _report = null;
    _alternatives = null;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, () {
      unawaited(_store.saveColors(_foreground, _background));
    });
    if (recordHistory) {
      _historyTimer?.cancel();
      _historyTimer = Timer(_historyDelay, _commitHistoryNow);
    }
    notifyListeners();
  }

  void _commitHistoryNow() {
    _historyTimer?.cancel();
    final pair = ColorPair(_foreground, _background);
    _recent.remove(pair);
    _recent.insert(0, pair);
    if (_recent.length > maxRecent) {
      _recent.removeRange(maxRecent, _recent.length);
    }
    unawaited(_store.saveRecent(_recent));
    notifyListeners();
  }

  @override
  void dispose() {
    _historyTimer?.cancel();
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      unawaited(_store.saveColors(_foreground, _background));
    }
    super.dispose();
  }
}

String _trim(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
