# Color Contrast Checker (app)

The Flutter desktop app. See the [repository README](../README.md) for setup, testing and releasing.

- `lib/src/state/`: `CheckerController` (colors, results, alternatives, history) and `SettingsController`.
- `lib/src/ui/`: the home page and widgets.
- `lib/src/services/`: preferences and the eyedropper wrapper.
- `packaging/`: Inno Setup script (Windows), DMG/sign/notarize script (macOS), and AppImage/.deb/.tar.gz script (Linux).
