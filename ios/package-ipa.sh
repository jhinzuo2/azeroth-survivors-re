#!/usr/bin/env bash
# Azeroth Survivors: link the static library into AzerothSurvivors.app and package the .ipa. This
# is the one step that needs macOS (Apple's linker and the iPhoneOS SDK's framework stubs).
#
#   ios/package-ipa.sh      # reads target/survivors-ios-out/{libsurvivors_ios.a,lib/,native-libs.txt}
#                           # writes target/survivors-ios-out/AzerothSurvivors.ipa
#
# Knobs: SURVIVORS_BUNDLE_ID (default org.azeroth.survivors), SURVIVORS_VERSION, SURVIVORS_BUILD,
# SURVIVORS_CLAIM_SDK (see below), SURVIVORS_STRIP=1 (drop local symbols).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/target/survivors-ios-out"
MIN_OS="${IPHONEOS_DEPLOYMENT_TARGET:-17.0}"
BUNDLE_ID="${SURVIVORS_BUNDLE_ID:-org.azeroth.survivors}"
VERSION="${SURVIVORS_VERSION:-0.1.0}"
BUILD="${SURVIVORS_BUILD:-$(date -u +%Y%m%d%H%M)}"

[ "$(uname -s)" = "Darwin" ] || { echo "package-ipa.sh runs on macOS (it needs Apple's linker)"; exit 1; }
[ -f "$OUT/libsurvivors_ios.a" ] || { echo "no $OUT/libsurvivors_ios.a: run ios/build-staticlib.sh first"; exit 1; }

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"
SDK_MAJOR="${SDK_VERSION%%.*}"
echo "survivors: iPhoneOS SDK $SDK_VERSION ($(xcodebuild -version | head -n1))"

# The SDK version the binary claims. iOS keys behaviour on the SDK an app was linked against, and
# from the release after iOS 26 an app linked against the newest SDK must adopt the UIScene life
# cycle. winit 0.30 drives UIKit through the classic app delegate, so the binary claims at most
# SDK 26.0 unless told otherwise.
if [ -z "${SURVIVORS_CLAIM_SDK:-}" ]; then
    if [ "$SDK_MAJOR" -ge 27 ]; then SURVIVORS_CLAIM_SDK="26.0"; else SURVIVORS_CLAIM_SDK="$SDK_VERSION"; fi
fi

APP="$OUT/Payload/AzerothSurvivors.app"
rm -rf "$OUT/Payload" "$OUT/AzerothSurvivors.ipa"
mkdir -p "$APP"

CC=(xcrun --sdk iphoneos clang -arch arm64 "-mios-version-min=$MIN_OS" -isysroot "$SDK")
"${CC[@]}" -c "$ROOT/ios/main.c" -o "$OUT/main.o"

# shellcheck disable=SC2046 # the flags are a list, split on purpose
"${CC[@]}" "$OUT/main.o" "$OUT/libsurvivors_ios.a" -L"$OUT/lib" $(cat "$OUT/native-libs.txt") \
    -Wl,-dead_strip -o "$APP/AzerothSurvivors"

if [ "$SURVIVORS_CLAIM_SDK" != "$SDK_VERSION" ]; then
    echo "survivors: rewriting LC_BUILD_VERSION: ios $MIN_OS, sdk $SURVIVORS_CLAIM_SDK (linked with $SDK_VERSION)"
    xcrun vtool -set-build-version ios "$MIN_OS" "$SURVIVORS_CLAIM_SDK" -replace \
        -output "$APP/AzerothSurvivors.tmp" "$APP/AzerothSurvivors"
    mv "$APP/AzerothSurvivors.tmp" "$APP/AzerothSurvivors"
fi
if [ "${SURVIVORS_STRIP:-0}" = "1" ]; then
    xcrun strip -x "$APP/AzerothSurvivors"
fi

sed -e "s/@BUNDLE_ID@/$BUNDLE_ID/" -e "s/@VERSION@/$VERSION/" -e "s/@BUILD@/$BUILD/" \
    -e "s/@SDK_VERSION@/$SURVIVORS_CLAIM_SDK/g" -e "s/@MIN_OS@/$MIN_OS/" \
    "$ROOT/ios/Info.plist.in" >"$APP/Info.plist"
plutil -lint "$APP/Info.plist"
plutil -convert binary1 "$APP/Info.plist"
printf 'APPL????' >"$APP/PkgInfo"

# App icons: copy ios/icons/*.png if present. Without them the app still installs, with a generic icon.
for icon in AppIcon60x60@2x.png AppIcon60x60@3x.png AppIcon76x76@2x.png AppIcon83.5x83.5@2x.png; do
    if [ -f "$ROOT/ios/icons/$icon" ]; then
        cp "$ROOT/ios/icons/$icon" "$APP/"
    else
        echo "survivors: no ios/icons/$icon, using a generic icon"
    fi
done

# Ad-hoc signature: SideStore / AltStore / LiveContainer re-sign with the player's own identity.
codesign --force --sign - --entitlements "$ROOT/ios/AzerothSurvivors.entitlements" --timestamp=none "$APP"
codesign --verify --verbose=2 "$APP"

(cd "$OUT" && zip -qry AzerothSurvivors.ipa Payload)
ls -lh "$OUT/AzerothSurvivors.ipa" "$APP/AzerothSurvivors"
xcrun vtool -show-build "$APP/AzerothSurvivors" | sed -n '1,12p'
echo "survivors: $OUT/AzerothSurvivors.ipa"
