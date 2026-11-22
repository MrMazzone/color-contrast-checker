import 'dart:io';

import 'package:color_contrast_checker/src/app.dart';
import 'package:color_contrast_checker/src/services/eyedropper_service.dart';
import 'package:color_contrast_checker/src/services/preferences_store.dart';
import 'package:color_contrast_checker/src/state/checker_controller.dart';
import 'package:color_contrast_checker/src/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEyedropper extends EyedropperService {
  FakeEyedropper([this.next = const PickCancelled()]);

  PickOutcome next;
  int calls = 0;
  bool? lastHideWindow;

  @override
  Future<PickOutcome> pick({required bool hideWindow}) async {
    calls++;
    lastHideWindow = hideWindow;
    return next;
  }
}

class TestApp {
  TestApp({
    StoredState initial = const StoredState(),
    FakeEyedropper? eyedropper,
  }) : store = PreferencesStore.memory(),
       eyedropper = eyedropper ?? FakeEyedropper() {
    checker = CheckerController(store, initial);
    settings = SettingsController(store, initial);
  }

  final PreferencesStore store;
  final FakeEyedropper eyedropper;
  late final CheckerController checker;
  late final SettingsController settings;

  Widget build() => ContrastCheckerApp(
    checker: checker,
    settings: settings,
    eyedropper: eyedropper,
  );
}

void setWindowSize(WidgetTester tester, Size size, {double dpr = 1}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = size * dpr;
  addTearDown(tester.view.reset);
}

/// Loads the real app fonts (and Material Icons) so goldens look like the app.
Future<void> loadAppFonts() async {
  Future<ByteData> asset(String path) => rootBundle.load(path);

  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    inter.addFont(asset('assets/fonts/Inter-$w.ttf'));
  }
  await inter.load();

  final mono = FontLoader('JetBrains Mono')
    ..addFont(asset('assets/fonts/JetBrainsMono-Medium.ttf'))
    ..addFont(asset('assets/fonts/JetBrainsMono-Bold.ttf'));
  await mono.load();

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final file = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await icons.load();
    }
  }
}
