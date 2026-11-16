#!/bin/bash
# Builds Universal Clipboard and installs it to /Applications.
#
# The app is signed with a self-signed certificate that lives only in this Mac's
# login keychain (created on first run). Apple can't revoke it, so macOS won't
# later flag the app as malware, and the signature stays the same across
# rebuilds, so the Accessibility permission survives updates. No Apple ID needed.
#
# The build is checked before anything in /Applications is touched.

set -euo pipefail

BUNDLE_ID="com.kian.UniversalClipboard"
IDENTITY="UniversalClipboard Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
DEST="/Applications/UniversalClipboard.app"
cd "$(dirname "$0")"
DERIVED="$PWD/build/DerivedData"
BUILT="$DERIVED/Build/Products/Release/UniversalClipboard.app"

step() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nerror: %s\n' "$*" >&2; exit 1; }

command -v xcodebuild >/dev/null || fail "xcodebuild not found. Install Xcode from the App Store and open it once."
xcodebuild -version >/dev/null 2>&1 || fail "Xcode isn't set up. Run: sudo xcode-select -s /Applications/Xcode.app, then open Xcode once."

step "Checking the signing certificate"
if security find-certificate -c "$IDENTITY" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "Using \"$IDENTITY\" from the login keychain."
else
    echo "Creating \"$IDENTITY\" (valid 10 years) in the login keychain."
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
        -keyout "$tmp/key.pem" -out "$tmp/cert.pem" -subj "/CN=$IDENTITY" \
        -addext "basicConstraints=critical,CA:false" \
        -addext "keyUsage=critical,digitalSignature" \
        -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null
    /usr/bin/openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" \
        -out "$tmp/identity.p12" -passout pass:install
    security import "$tmp/identity.p12" -k "$KEYCHAIN" -P install -T /usr/bin/codesign >/dev/null
    echo "If macOS asks whether codesign may use the key, click Always Allow."
fi

step "Building (Release)"
xcodebuild -project UniversalClipboard.xcodeproj -scheme UniversalClipboard \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED" -quiet \
    CODE_SIGNING_ALLOWED=NO build

step "Signing"
codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$BUILT"
codesign --verify --deep --strict "$BUILT" || fail "the build's signature is not valid. /Applications was not changed."

step "Installing to $DEST"
if pgrep -xq UniversalClipboard; then
    osascript -e "quit app id \"$BUNDLE_ID\"" 2>/dev/null || true
    for _ in {1..20}; do pgrep -xq UniversalClipboard || break; sleep 0.25; done
    pkill -x UniversalClipboard 2>/dev/null || true
fi
# Remember whether the installed copy was signed some other way (e.g. by Xcode),
# since its Accessibility permission won't carry over.
resigned=no
if [[ -d "$DEST" ]]; then
    old_sig=$(codesign -dvv "$DEST" 2>&1 || true)
    [[ "$old_sig" == *$'\n'"Authority=$IDENTITY"$'\n'* ]] || resigned=yes
fi
rm -rf "$DEST"
ditto "$BUILT" "$DEST"
codesign --verify --deep --strict "$DEST" || fail "the installed copy failed verification."

step "Launching"
open "$DEST"

echo
echo "Installed."
if [[ "$resigned" == yes ]]; then
    cat <<EOF
The previous copy had a different signature, so give Accessibility permission again:
  tccutil reset Accessibility $BUNDLE_ID
then turn Universal Clipboard on in System Settings › Privacy & Security › Accessibility.
EOF
fi
