// Renders marketing screenshots of the real UI.
//
//   cd app && flutter test --update-goldens --tags screenshots
//
// Output: app/test/screenshots/*.png (copied to website/assets/img/).
// Excluded from normal runs because font rendering differs across machines.
@Tags(['screenshots'])
library;

import 'package:color_contrast_checker/src/services/preferences_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wcag_contrast/wcag_contrast.dart';

import 'helpers.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required ThemeMode mode,
    required StoredState state,
    Size size = const Size(1440, 1180),
  }) async {
    setWindowSize(tester, size, dpr: 2);
    final app = TestApp(initial: state);
    app.settings.themeMode = mode;
    await tester.pumpWidget(app.build());
    await tester.runAsync(() async {
      final element = tester.element(find.byType(Scaffold));
      await precacheImage(
        const AssetImage('assets/images/app_icon.png'),
        element,
      );
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screenshots/$name.png'),
    );
    await tester.pump(const Duration(seconds: 2));
  }

  final recent = [
    ColorPair(parseColor('#1F2937'), RgbColor.white),
    ColorPair(parseColor('#FFFFFF'), parseColor('#4F46E5')),
    ColorPair(parseColor('#0F766E'), parseColor('#F0FDFA')),
    ColorPair(parseColor('#FDE68A'), parseColor('#1E1B4B')),
    ColorPair(parseColor('#BE185D'), parseColor('#FFF1F2')),
  ];

  testWidgets('light — failing pair with alternatives', (tester) async {
    await shoot(
      tester,
      name: 'app-light',
      mode: ThemeMode.light,
      state: StoredState(
        foreground: parseColor('#7C7CF8'),
        background: RgbColor.white,
        recent: recent,
      ),
    );
  });

  testWidgets('dark — passing pair', (tester) async {
    await shoot(
      tester,
      name: 'app-dark',
      mode: ThemeMode.dark,
      state: StoredState(
        foreground: parseColor('#FDE68A'),
        background: parseColor('#1E1B4B'),
        recent: recent,
      ),
    );
  });

  testWidgets('light — compact window', (tester) async {
    await shoot(
      tester,
      name: 'app-compact',
      mode: ThemeMode.light,
      size: const Size(900, 1300),
      state: StoredState(
        foreground: parseColor('#E11D48'),
        background: parseColor('#FFF1F2'),
        recent: recent,
      ),
    );
  });
}
