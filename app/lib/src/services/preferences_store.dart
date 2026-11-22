import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wcag_contrast/wcag_contrast.dart';

/// A saved foreground/background combination.
class ColorPair {
  const ColorPair(this.foreground, this.background);

  final RgbColor foreground;
  final RgbColor background;

  double get ratio => contrastRatio(foreground, background);

  Map<String, Object> toJson() => {
    'fg': foreground.toHex(includeAlpha: true),
    'bg': background.toHex(),
  };

  static ColorPair? fromJson(Object? json) {
    if (json is! Map) return null;
    final fg = tryParseColor('${json['fg']}');
    final bg = tryParseColor('${json['bg']}');
    if (fg == null || bg == null) return null;
    return ColorPair(fg, bg.opaque);
  }

  @override
  bool operator ==(Object other) =>
      other is ColorPair &&
      other.foreground == foreground &&
      other.background == background;

  @override
  int get hashCode => Object.hash(foreground, background);
}

/// Everything persisted between launches.
class StoredState {
  const StoredState({
    this.foreground = const RgbColor(0, 0, 255),
    this.background = RgbColor.white,
    this.level = WcagLevel.aa,
    this.category = ContrastCategory.normalText,
    this.adjust = AdjustTarget.foreground,
    this.previewText = defaultPreviewText,
    this.recent = const [],
    this.themeMode = ThemeMode.system,
    this.hideWindowWhilePicking = true,
  });

  static const defaultPreviewText = 'The five boxing wizards jump quickly.';

  final RgbColor foreground;
  final RgbColor background;
  final WcagLevel level;
  final ContrastCategory category;
  final AdjustTarget adjust;
  final String previewText;
  final List<ColorPair> recent;
  final ThemeMode themeMode;
  final bool hideWindowWhilePicking;
}

/// Thin wrapper over [SharedPreferences] with defensive parsing so a corrupt
/// or outdated value never prevents the app from starting.
class PreferencesStore {
  PreferencesStore(this._prefs);

  final SharedPreferences? _prefs;

  static Future<PreferencesStore> open() async {
    try {
      return PreferencesStore(await SharedPreferences.getInstance());
    } catch (_) {
      return PreferencesStore(null);
    }
  }

  /// An in-memory store (tests and fallbacks).
  factory PreferencesStore.memory() => PreferencesStore(null);

  static const _kForeground = 'foreground';
  static const _kBackground = 'background';
  static const _kLevel = 'level';
  static const _kCategory = 'category';
  static const _kAdjust = 'adjust';
  static const _kPreview = 'previewText';
  static const _kRecent = 'recentPairs';
  static const _kTheme = 'themeMode';
  static const _kHide = 'hideWindowWhilePicking';

  StoredState load() {
    final p = _prefs;
    if (p == null) return const StoredState();
    T pick<T extends Enum>(List<T> values, String key, T fallback) {
      final name = p.getString(key);
      return values.firstWhere((v) => v.name == name, orElse: () => fallback);
    }

    List<ColorPair> recent = const [];
    try {
      final raw = p.getString(_kRecent);
      if (raw != null) {
        recent = (jsonDecode(raw) as List)
            .map(ColorPair.fromJson)
            .whereType<ColorPair>()
            .toList();
      }
    } catch (_) {}

    const defaults = StoredState();
    return StoredState(
      foreground:
          tryParseColor(p.getString(_kForeground) ?? '') ?? defaults.foreground,
      background:
          tryParseColor(p.getString(_kBackground) ?? '')?.opaque ??
          defaults.background,
      level: pick(WcagLevel.values, _kLevel, defaults.level),
      category: pick(ContrastCategory.values, _kCategory, defaults.category),
      adjust: pick(AdjustTarget.values, _kAdjust, defaults.adjust),
      previewText: p.getString(_kPreview) ?? defaults.previewText,
      recent: recent,
      themeMode: pick(ThemeMode.values, _kTheme, defaults.themeMode),
      hideWindowWhilePicking: p.getBool(_kHide) ?? true,
    );
  }

  Future<void> saveColors(RgbColor fg, RgbColor bg) async {
    await _prefs?.setString(_kForeground, fg.toHex(includeAlpha: true));
    await _prefs?.setString(_kBackground, bg.toHex());
  }

  Future<void> saveAlternativeSettings(
    WcagLevel level,
    ContrastCategory category,
    AdjustTarget adjust,
  ) async {
    await _prefs?.setString(_kLevel, level.name);
    await _prefs?.setString(_kCategory, category.name);
    await _prefs?.setString(_kAdjust, adjust.name);
  }

  Future<void> savePreviewText(String text) async =>
      _prefs?.setString(_kPreview, text);

  Future<void> saveRecent(List<ColorPair> pairs) async => _prefs?.setString(
    _kRecent,
    jsonEncode(pairs.map((p) => p.toJson()).toList()),
  );

  Future<void> saveThemeMode(ThemeMode mode) async =>
      _prefs?.setString(_kTheme, mode.name);

  Future<void> saveHideWindow(bool hide) async => _prefs?.setBool(_kHide, hide);
}
