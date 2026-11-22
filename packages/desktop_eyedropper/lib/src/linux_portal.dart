import 'dart:async';
import 'dart:math' as math;

import 'package:dbus/dbus.dart';

/// Outcome of asking the XDG desktop portal for a color.
sealed class PortalOutcome {
  const PortalOutcome();
}

/// The user picked a color (`0xRRGGBB`).
final class PortalPicked extends PortalOutcome {
  const PortalPicked(this.rgb);

  final int rgb;
}

/// The user dismissed the picker.
final class PortalCancelled extends PortalOutcome {
  const PortalCancelled();
}

/// No portal implementation offers `PickColor` on this desktop.
final class PortalUnavailable extends PortalOutcome {
  const PortalUnavailable();
}

/// Talks to `org.freedesktop.portal.Screenshot.PickColor` over the session
/// bus. Works on GNOME and KDE (Wayland and X11) and inside Flatpak.
abstract final class LinuxColorPortal {
  static const _busName = 'org.freedesktop.portal.Desktop';
  static const _screenshotInterface = 'org.freedesktop.portal.Screenshot';
  static const _requestInterface = 'org.freedesktop.portal.Request';

  static Future<PortalOutcome> pickColor({
    Duration timeout = const Duration(minutes: 10),
  }) async {
    DBusClient? client;
    StreamSubscription<DBusSignal>? subscription;
    try {
      client = DBusClient.session();
      final portal = DBusRemoteObject(
        client,
        name: _busName,
        path: DBusObjectPath('/org/freedesktop/portal/desktop'),
      );

      // PickColor was added in version 2 of the Screenshot interface.
      final version = await portal.getProperty(
        _screenshotInterface,
        'version',
        signature: DBusSignature('u'),
      );
      if (version is! DBusUint32 || version.value < 2) {
        return const PortalUnavailable();
      }

      // Subscribe to the Response signal on the request object *before*
      // calling PickColor, using the predictable request path, so a fast
      // reply can't be missed.
      final token = 'cc${math.Random().nextInt(1 << 31)}';
      final sender = client.uniqueName
          .replaceFirst(':', '')
          .replaceAll('.', '_');
      final request = DBusRemoteObject(
        client,
        name: _busName,
        path: DBusObjectPath(
          '/org/freedesktop/portal/desktop/request/$sender/$token',
        ),
      );
      final response = Completer<DBusSignal>();
      subscription =
          DBusRemoteObjectSignalStream(
            object: request,
            interface: _requestInterface,
            name: 'Response',
            signature: DBusSignature('ua{sv}'),
          ).listen((signal) {
            if (!response.isCompleted) response.complete(signal);
          });

      await portal.callMethod(_screenshotInterface, 'PickColor', [
        const DBusString(''),
        DBusDict.stringVariant({'handle_token': DBusString(token)}),
      ], replySignature: DBusSignature('o'));

      final signal = await response.future.timeout(timeout);
      final code = (signal.values[0] as DBusUint32).value;
      if (code != 0) return const PortalCancelled();
      final rgb = colorFromPortalResults(signal.values[1]);
      return rgb == null ? const PortalCancelled() : PortalPicked(rgb);
    } on TimeoutException {
      return const PortalCancelled();
    } on DBusMethodResponseException {
      return const PortalUnavailable();
    } on Exception {
      // No session bus, no portal service, unknown interface, etc.
      return const PortalUnavailable();
    } finally {
      await subscription?.cancel();
      await client?.close();
    }
  }
}

/// Extracts `0xRRGGBB` from a portal `PickColor` results dictionary, whose
/// `color` entry is a `(ddd)` struct of channels in the 0–1 range.
int? colorFromPortalResults(DBusValue results) {
  if (results is! DBusDict) return null;
  final entry = results.children[const DBusString('color')];
  final value = entry is DBusVariant ? entry.value : entry;
  if (value is! DBusStruct || value.children.length < 3) return null;
  final channels = <int>[];
  for (final c in value.children.take(3)) {
    if (c is! DBusDouble) return null;
    channels.add((c.value.clamp(0.0, 1.0) * 255).round());
  }
  return (channels[0] << 16) | (channels[1] << 8) | channels[2];
}
