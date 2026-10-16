#!/usr/bin/env bash
# Azeroth Survivors: build the game as a static library for iOS (Linux or macOS host).
#
#   ios/build-staticlib.sh      # -> target/survivors-ios-out/libsurvivors_ios.a
#
# A staticlib is an archive, not a link, so no Apple linker or SDK is needed on Linux: the few C
# files in the graph compile against open-source Darwin headers (ios/toolchain/linux-env.sh).
# Linking into an .ipa happens on macOS (a later step).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROFILE="${SURVIVORS_PROFILE:-release}"
TARGET="aarch64-apple-ios"
OUT="$ROOT/target/survivors-ios-out"
export IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-17.0}"

if [ "$(uname -s)" != "Darwin" ]; then
    # shellcheck source=toolchain/linux-env.sh
    source "$ROOT/ios/toolchain/linux-env.sh"
fi

rustup target add "$TARGET" >/dev/null 2>&1 || true

echo "survivors: building $TARGET ($PROFILE)"
mkdir -p "$OUT"
messages="$OUT/build-messages.json"
cargo build --target "$TARGET" --profile "$PROFILE" -p survivors-ios \
    --message-format=json-render-diagnostics >"$messages"

# Native libraries a build script links as `static:-bundle` (e.g. Lua) are not inside the
# staticlib: ship each one beside it, in lib/, for the app link to find.
rm -rf "$OUT/lib"
mkdir -p "$OUT/lib"
jq -r 'select(.reason == "build-script-executed")
       | . as $m
       | .linked_libs[]
       | select(test("^static:([^=]*,)?-bundle"))
       | sub("^[^=]*="; "") as $name
       | $m.linked_paths[] | sub("^[a-z]*="; "") | "\(.)/lib\($name).a"' "$messages" |
    while read -r archive; do
        if [ -f "$archive" ]; then
            cp "$archive" "$OUT/lib/"
            echo "survivors: unbundled archive $(basename "$archive")"
        fi
    done

# The system libraries the archive needs at link time, as rustc reports them.
notes="$OUT/native-static-libs.log"
cargo rustc --color never --target "$TARGET" --profile "$PROFILE" -p survivors-ios --lib \
    -- --print native-static-libs 2>"$notes" || { cat "$notes"; exit 1; }
# CI sets CARGO_TERM_COLOR=always, so strip colour codes before reading the flags.
esc=$'\033'
libs="$(sed -e "s/${esc}\[[0-9;]*m//g" "$notes" | sed -n 's/.*native-static-libs: //p' | tail -n 1)"
if [ -z "$libs" ]; then
    echo "survivors: rustc printed no native-static-libs line:" >&2
    cat "$notes" >&2
    exit 1
fi
echo "$libs" >"$OUT/native-libs.txt"

cp "target/$TARGET/$PROFILE/libsurvivors_ios.a" "$OUT/libsurvivors_ios.a"
git -C "$ROOT" rev-parse --short HEAD >"$OUT/commit.txt" 2>/dev/null || echo unknown >"$OUT/commit.txt"
ls -lh "$OUT/libsurvivors_ios.a"
echo "survivors: link flags: $libs"
