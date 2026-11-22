#!/usr/bin/env bash
# Packages a Linux release build as .tar.gz, .deb and AppImage.
#
#   cd app && flutter build linux --release && packaging/linux/build_packages.sh
#
# Output goes to <repo>/dist with stable file names so the website can link to
# .../releases/latest/download/<name>.
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$APP_DIR"

APP_ID="net.joemazzone.colorcontrast"
BIN="color-contrast-checker"
VERSION="${VERSION:-$(grep -E '^version:' pubspec.yaml | sed -E 's/version: *([0-9.]+).*/\1/')}"
BUNDLE="build/linux/x64/release/bundle"
DIST="$APP_DIR/../dist"
WORK="build/package"

[ -x "$BUNDLE/$BIN" ] || { echo "Missing $BUNDLE/$BIN — run 'flutter build linux --release' first." >&2; exit 1; }
rm -rf "$WORK"
mkdir -p "$DIST" "$WORK"

install_shared_files() {
  # $1 = root of a /usr-style tree
  local root="$1"
  install -Dm644 "packaging/linux/$APP_ID.desktop" "$root/share/applications/$APP_ID.desktop"
  install -Dm644 "packaging/linux/$APP_ID.metainfo.xml" "$root/share/metainfo/$APP_ID.metainfo.xml"
  for size in 64 128 256 512; do
    install -Dm644 "packaging/linux/icons/${size}x${size}/$APP_ID.png" \
      "$root/share/icons/hicolor/${size}x${size}/apps/$APP_ID.png"
  done
}

echo "==> tar.gz"
cp -r "$BUNDLE" "$WORK/$BIN"
tar -C "$WORK" -czf "$DIST/ColorContrastChecker-Linux-x86_64.tar.gz" "$BIN"

echo "==> deb ($VERSION)"
DEB="$WORK/deb"
mkdir -p "$DEB/DEBIAN" "$DEB/opt/$BIN" "$DEB/usr/bin"
cp -r "$BUNDLE/." "$DEB/opt/$BIN/"
ln -s "/opt/$BIN/$BIN" "$DEB/usr/bin/$BIN"
install_shared_files "$DEB/usr"
INSTALLED_SIZE="$(du -sk "$DEB" | cut -f1)"
cat > "$DEB/DEBIAN/control" <<EOF
Package: $BIN
Version: $VERSION
Section: graphics
Priority: optional
Architecture: amd64
Maintainer: Joe Mazzone <MrMazzone@users.noreply.github.com>
Installed-Size: $INSTALLED_SIZE
Depends: libgtk-3-0 | libgtk-3-0t64, libc6 (>= 2.31)
Homepage: https://color-contrast.joemazzone.net
Description: WCAG 2.1 color contrast checker with a screen eyedropper
 Check foreground and background color pairs against the WCAG 2.1 contrast
 requirements for normal text, large text and UI components, at AA and AAA.
 Pick colors from anywhere on screen and get the closest accessible
 alternatives.
EOF
dpkg-deb --root-owner-group --build "$DEB" "$DIST/ColorContrastChecker-Linux-amd64.deb"

echo "==> AppImage"
APPDIR="$WORK/AppDir"
mkdir -p "$APPDIR/usr/bin"
cp -r "$BUNDLE/." "$APPDIR/usr/bin/"
install_shared_files "$APPDIR/usr"
cp "packaging/linux/$APP_ID.desktop" "$APPDIR/$APP_ID.desktop"
cp "packaging/linux/icons/256x256/$APP_ID.png" "$APPDIR/$APP_ID.png"
cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/color-contrast-checker" "$@"
EOF
chmod +x "$APPDIR/AppRun"

TOOL="${APPIMAGETOOL:-$WORK/appimagetool}"
if [ ! -x "$TOOL" ]; then
  curl -fsSL -o "$TOOL" \
    https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x "$TOOL"
fi
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" --no-appstream "$APPDIR" \
  "$DIST/ColorContrastChecker-Linux-x86_64.AppImage"

echo "==> done"
ls -lh "$DIST"
