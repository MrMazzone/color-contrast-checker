import 'package:dbus/dbus.dart';
import 'package:desktop_eyedropper/desktop_eyedropper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the portal (ddd) color struct', () {
    final results = DBusDict.stringVariant({
      'color': DBusStruct([
        const DBusDouble(0),
        const DBusDouble(0.5),
        const DBusDouble(1),
      ]),
    });
    expect(colorFromPortalResults(results), 0x0080FF);
  });

  test('clamps out-of-range channels', () {
    final results = DBusDict.stringVariant({
      'color': DBusStruct([
        const DBusDouble(-0.2),
        const DBusDouble(1.4),
        const DBusDouble(0.2),
      ]),
    });
    expect(colorFromPortalResults(results), 0x00FF33);
  });

  test('returns null for missing or malformed data', () {
    expect(colorFromPortalResults(DBusDict.stringVariant({})), isNull);
    expect(
      colorFromPortalResults(
        DBusDict.stringVariant({'color': const DBusString('red')}),
      ),
      isNull,
    );
    expect(colorFromPortalResults(const DBusString('x')), isNull);
  });
}
