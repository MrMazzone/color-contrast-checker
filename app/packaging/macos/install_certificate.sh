#!/usr/bin/env bash
# Installs the Developer ID Application certificate on a CI Mac (Codemagic)
# and exports MACOS_SIGN_IDENTITY / ASC_KEY_PATH for later steps via $CM_ENV.
#
# Environment (Codemagic "apple_signing" group):
#   MACOS_CERTIFICATE_P12_BASE64, MACOS_CERTIFICATE_PASSWORD,
#   APP_STORE_CONNECT_PRIVATE_KEY
#
# The .p12 may have been made without a Mac (OpenSSL). OpenSSL 3 encrypts
# .p12 files with AES/PBKDF2 by default, which macOS `security` can refuse;
# if the first import fails, the file is re-packed with legacy algorithms.
set -euo pipefail

: "${MACOS_CERTIFICATE_P12_BASE64:?missing}"
: "${MACOS_CERTIFICATE_PASSWORD:?missing}"
: "${APP_STORE_CONNECT_PRIVATE_KEY:?missing}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
P12="$WORK/developer_id.p12"

keychain initialize

# Apple's Developer ID intermediates; a fresh keychain may not chain to them.
for ca in DeveloperIDG2CA DeveloperIDCA; do
  if curl -fsSL -o "$WORK/$ca.cer" "https://www.apple.com/certificateauthority/$ca.cer"; then
    security import "$WORK/$ca.cer" >/dev/null 2>&1 || true
  fi
done

# Strip whitespace/CRLF that copy-paste (e.g. from PowerShell) can introduce.
printf '%s' "$MACOS_CERTIFICATE_P12_BASE64" | tr -d ' \r\n\t' | base64 --decode > "$P12"

if ! keychain add-certificates --certificate "$P12" --certificate-password "$MACOS_CERTIFICATE_PASSWORD"; then
  echo "Import failed; re-packing the .p12 with legacy encryption and retrying."
  OPENSSL="$(brew --prefix openssl@3 2>/dev/null || true)/bin/openssl"
  [ -x "$OPENSSL" ] || OPENSSL="$(command -v openssl)"
  "$OPENSSL" version
  LEGACY_FLAG=""
  "$OPENSSL" pkcs12 -help 2>&1 | grep -q -- "-legacy" && LEGACY_FLAG="-legacy"
  "$OPENSSL" pkcs12 $LEGACY_FLAG -in "$P12" -passin env:MACOS_CERTIFICATE_PASSWORD -nodes -out "$WORK/identity.pem"
  "$OPENSSL" pkcs12 -export $LEGACY_FLAG \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
    -in "$WORK/identity.pem" -out "$WORK/legacy.p12" \
    -passout env:MACOS_CERTIFICATE_PASSWORD
  keychain add-certificates --certificate "$WORK/legacy.p12" --certificate-password "$MACOS_CERTIFICATE_PASSWORD"
fi

IDENTITY="$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)"/\1/' || true)"
if [ -z "$IDENTITY" ]; then
  echo "No valid 'Developer ID Application' identity after import. Identities found:" >&2
  security find-identity -p codesigning >&2 || true
  echo "Check that the certificate type is Developer ID Application (not Apple Development/Distribution) and that the .p12 contains its private key." >&2
  exit 1
fi
echo "Signing identity: $IDENTITY"

KEY_PATH="$HOME/AuthKey_notary.p8"
printf '%s\n' "$APP_STORE_CONNECT_PRIVATE_KEY" > "$KEY_PATH"
chmod 600 "$KEY_PATH"

if [ -n "${CM_ENV:-}" ]; then
  echo "MACOS_SIGN_IDENTITY=$IDENTITY" >> "$CM_ENV"
  echo "ASC_KEY_PATH=$KEY_PATH" >> "$CM_ENV"
fi
