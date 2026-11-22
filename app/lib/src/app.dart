import 'package:flutter/material.dart';

import 'services/eyedropper_service.dart';
import 'state/checker_controller.dart';
import 'state/settings_controller.dart';
import 'theme.dart';
import 'ui/home_page.dart';

/// Makes the app's controllers available to the widget tree. Widgets that
/// call [of] rebuild whenever the [CheckerController] changes.
class AppScope extends InheritedNotifier<CheckerController> {
  const AppScope({
    super.key,
    required CheckerController checker,
    required this.settings,
    required this.eyedropper,
    required super.child,
  }) : super(notifier: checker);

  CheckerController get checker => notifier!;
  final SettingsController settings;
  final EyedropperService eyedropper;

  /// Looks up the scope and rebuilds the caller when the checker changes.
  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!;
  }

  /// Looks up the scope without subscribing (for callbacks).
  static AppScope read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!;
  }
}

class ContrastCheckerApp extends StatelessWidget {
  const ContrastCheckerApp({
    super.key,
    required this.checker,
    required this.settings,
    required this.eyedropper,
  });

  final CheckerController checker;
  final SettingsController settings;
  final EyedropperService eyedropper;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      checker: checker,
      settings: settings,
      eyedropper: eyedropper,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          title: 'Color Contrast Checker',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: settings.themeMode,
          home: const HomePage(),
        ),
      ),
    );
  }
}
