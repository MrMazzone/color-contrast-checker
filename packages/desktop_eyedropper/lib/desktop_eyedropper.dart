/// Pick a color from anywhere on the screen.
///
/// * **macOS** — the system color sampler (`NSColorSampler`). No Screen
///   Recording permission is required and it works inside the App Sandbox.
/// * **Windows** — a native full-screen overlay over a frozen screenshot with
///   a magnifier loupe.
/// * **Linux** — the XDG desktop portal color picker (GNOME, KDE, Flatpak),
///   falling back to a native X11 overlay when no portal is available.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'src/linux_portal.dart';

export 'src/linux_portal.dart' show colorFromPortalResults;

/// Thrown when the current desktop cannot pick colors from the screen.
class EyedropperUnsupportedException implements Exception {
  const EyedropperUnsupportedException(this.message);

  final String message;

  @override
  String toString() => 'EyedropperUnsupportedException: $message';
}

/// Thrown when a pick is requested while another is still in progress.
class EyedropperBusyException implements Exception {
  const EyedropperBusyException();

  @override
  String toString() => 'EyedropperBusyException: a pick is already running';
}

/// Entry point for picking screen colors.
abstract final class DesktopEyedropper {
  static const MethodChannel _channel = MethodChannel('desktop_eyedropper');

  static bool _busy = false;

  /// Lets the user pick a color from anywhere on the screen.
  ///
  /// Returns the color as `0xRRGGBB`, or `null` if the user cancelled
  /// (Esc or right-click). When [hideWindow] is true the app's window is
  /// hidden while picking so it doesn't cover what's behind it.
  ///
  /// Throws [EyedropperUnsupportedException] if the desktop offers no way to
  /// read screen colors, and [EyedropperBusyException] if a pick is already
  /// running.
  static Future<int?> pickColor({bool hideWindow = true}) async {
    if (_busy) throw const EyedropperBusyException();
    _busy = true;
    try {
      if (Platform.isLinux) return await _pickLinux(hideWindow: hideWindow);
      return await _invokePick(hideWindow: hideWindow);
    } finally {
      _busy = false;
    }
  }

  static Future<int?> _invokePick({required bool hideWindow}) async {
    try {
      return await _channel.invokeMethod<int>('pickColor', {
        'hideWindow': hideWindow,
      });
    } on PlatformException catch (e) {
      if (e.code == 'unsupported') {
        throw EyedropperUnsupportedException(e.message ?? 'Not supported');
      }
      if (e.code == 'busy') throw const EyedropperBusyException();
      rethrow;
    } on MissingPluginException {
      throw const EyedropperUnsupportedException(
        'Screen color picking is not available on this platform.',
      );
    }
  }

  static Future<int?> _pickLinux({required bool hideWindow}) async {
    if (hideWindow) await _setWindowVisible(false);
    try {
      // Give the compositor a moment to remove our window from the screen.
      if (hideWindow) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final portal = await LinuxColorPortal.pickColor();
      switch (portal) {
        case PortalPicked(:final rgb):
          return rgb;
        case PortalCancelled():
          return null;
        case PortalUnavailable():
          // No portal (e.g. a bare X11 window manager): use the native
          // X11 overlay. On Wayland without a portal this reports
          // 'unsupported'.
          return await _invokePick(hideWindow: false);
      }
    } finally {
      if (hideWindow) await _setWindowVisible(true);
    }
  }

  static Future<void> _setWindowVisible(bool visible) async {
    try {
      await _channel.invokeMethod<void>('setWindowVisible', {
        'visible': visible,
      });
    } on PlatformException {
      // Hiding is best-effort.
    } on MissingPluginException {
      // Ignore in tests / unsupported embedders.
    }
  }
}
