# desktop_eyedropper

Pick a color from anywhere on the screen on Windows, macOS and Linux.

```dart
final rgb = await DesktopEyedropper.pickColor(hideWindow: true); // 0xRRGGBB or null
```

| Platform | Implementation |
| --- | --- |
| macOS 10.15+ | `NSColorSampler`, the system loupe. No Screen Recording permission; works in the App Sandbox. |
| Windows | Win32: captures every monitor, then shows a topmost overlay with a magnifier loupe. Click or Enter picks, Esc or right-click cancels, arrow keys nudge (Shift = 10px). Per-monitor DPI aware. |
| Linux | `org.freedesktop.portal.Screenshot.PickColor` over D-Bus (GNOME/KDE, Wayland/X11, Flatpak). Falls back to a GTK/X11 overlay with the same loupe. |

Throws `EyedropperUnsupportedException` when the desktop offers no way to read the screen (for example a Wayland compositor without a portal).

Part of [Color Contrast Checker](https://github.com/MrMazzone/color-contrast-checker). MIT licensed.
