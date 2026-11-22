import 'dart:async';

import 'package:flutter/material.dart';

import '../services/preferences_store.dart';

/// App-wide preferences: theme and eyedropper behaviour.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store, StoredState initial)
    : _themeMode = initial.themeMode,
      _hideWindowWhilePicking = initial.hideWindowWhilePicking;

  final PreferencesStore _store;
  ThemeMode _themeMode;
  bool _hideWindowWhilePicking;

  ThemeMode get themeMode => _themeMode;
  bool get hideWindowWhilePicking => _hideWindowWhilePicking;

  set themeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    unawaited(_store.saveThemeMode(mode));
    notifyListeners();
  }

  set hideWindowWhilePicking(bool value) {
    if (value == _hideWindowWhilePicking) return;
    _hideWindowWhilePicking = value;
    unawaited(_store.saveHideWindow(value));
    notifyListeners();
  }
}
