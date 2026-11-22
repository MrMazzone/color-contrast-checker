import 'package:color_contrast_checker/src/services/eyedropper_service.dart';
import 'package:color_contrast_checker/src/services/preferences_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wcag_contrast/wcag_contrast.dart';

import 'helpers.dart';

/// The headline ratio (rendered as "8.59:1").
Finder ratio(String text) => find.text('$text:1', findRichText: true);

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  // Let the debounced history/save timers fire.
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('shows the default blue-on-white ratio and passes', (
    tester,
  ) async {
    setWindowSize(tester, const Size(1400, 1000));
    final app = TestApp();
    await tester.pumpWidget(app.build());

    expect(ratio('8.59'), findsOneWidget);
    expect(find.text('Passes AA and AAA at every text size'), findsOneWidget);
    expect(find.text('Fail'), findsNothing);
    expect(find.textContaining('already meet'), findsOneWidget);
  });

  testWidgets('typing a hex value updates results live', (tester) async {
    setWindowSize(tester, const Size(1400, 1000));
    final app = TestApp();
    await tester.pumpWidget(app.build());

    await tester.enterText(find.byType(TextField).first, '777777');
    await settle(tester);

    expect(app.checker.foreground, const RgbColor(0x77, 0x77, 0x77));
    expect(ratio('4.47'), findsOneWidget);
    expect(
      find.text('Passes only for large text and UI components'),
      findsOneWidget,
    );
    // Normal AA, normal AAA and large AAA fail.
    expect(find.text('Fail'), findsNWidgets(3));
  });

  testWidgets('accepts rgb() and named colors', (tester) async {
    setWindowSize(tester, const Size(1400, 1000));
    final app = TestApp();
    await tester.pumpWidget(app.build());

    await tester.enterText(find.byType(TextField).at(1), 'rgb(0, 0, 0)');
    await settle(tester);
    expect(app.checker.background, RgbColor.black);

    await tester.enterText(find.byType(TextField).first, 'white');
    await settle(tester);
    expect(app.checker.foreground, RgbColor.white);
    expect(ratio('21.00'), findsOneWidget);
  });

  testWidgets('applying a suggestion makes the pair pass', (tester) async {
    setWindowSize(tester, const Size(1400, 1100));
    final app = TestApp(
      initial: const StoredState(foreground: RgbColor(0x99, 0x99, 0x99)),
    );
    await tester.pumpWidget(app.build());
    expect(app.checker.report.normalTextAA, isFalse);

    final apply = find.widgetWithText(FilledButton, 'Apply').first;
    await tester.ensureVisible(apply);
    await tester.pumpAndSettle();
    await tester.tap(apply);
    await settle(tester);

    expect(app.checker.report.normalTextAA, isTrue);
    expect(find.textContaining('already meet'), findsOneWidget);
    expect(app.checker.recent, isNotEmpty);
  });

  testWidgets('eyedropper sets the picked color', (tester) async {
    setWindowSize(tester, const Size(1400, 1000));
    final eyedropper = FakeEyedropper(const Picked(RgbColor(0, 0, 0)));
    final app = TestApp(eyedropper: eyedropper);
    await tester.pumpWidget(app.build());

    await tester.tap(find.byTooltip('Pick foreground from screen (Ctrl+1)'));
    await settle(tester);

    expect(eyedropper.calls, 1);
    expect(eyedropper.lastHideWindow, isTrue);
    expect(app.checker.foreground, RgbColor.black);
    expect(ratio('21.00'), findsOneWidget);
  });

  testWidgets('eyedropper failures are reported', (tester) async {
    setWindowSize(tester, const Size(1400, 1000));
    final app = TestApp(
      eyedropper: FakeEyedropper(const PickFailed('No portal')),
    );
    await tester.pumpWidget(app.build());

    await tester.tap(find.byTooltip('Pick background from screen (Ctrl+2)'));
    await tester.pump();
    expect(find.text('No portal'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('swap exchanges the colors', (tester) async {
    setWindowSize(tester, const Size(1400, 1000));
    final app = TestApp();
    await tester.pumpWidget(app.build());

    await tester.tap(find.byTooltip('Swap colors (Ctrl+Shift+X)'));
    await settle(tester);

    expect(app.checker.foreground, RgbColor.white);
    expect(app.checker.background, const RgbColor(0, 0, 255));
  });

  testWidgets('narrow window stacks the layout without overflow', (
    tester,
  ) async {
    setWindowSize(tester, const Size(760, 900));
    final app = TestApp();
    await tester.pumpWidget(app.build());
    expect(tester.takeException(), isNull);
    expect(ratio('8.59'), findsOneWidget);
  });

  test('report text', () {
    final app = TestApp(
      initial: const StoredState(foreground: RgbColor(0x77, 0x77, 0x77)),
    );
    final report = app.checker.buildReport();
    expect(report, contains('Foreground: #777777'));
    expect(report, contains('Contrast ratio: 4.47:1'));
    expect(report, contains('| Normal text | Fail (≥ 4.5:1) | Fail (≥ 7:1) |'));
    expect(report, contains('| Large text | Pass (≥ 3:1) | Fail (≥ 4.5:1) |'));
  });
}
