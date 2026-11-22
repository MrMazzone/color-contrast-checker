import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/services/eyedropper_service.dart';
import 'src/services/preferences_store.dart';
import 'src/state/checker_controller.dart';
import 'src/state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await PreferencesStore.open();
  final initial = store.load();
  runApp(
    ContrastCheckerApp(
      checker: CheckerController(store, initial),
      settings: SettingsController(store, initial),
      eyedropper: const EyedropperService(),
    ),
  );
}
