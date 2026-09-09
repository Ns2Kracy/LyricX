#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="LyricX"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$ROOT_DIR"

BUILD_DIR="$(swift build -c release --show-bin-path)"
swift build -c release --product "$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Sources/LyricX/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

if [[ -n "${SPOTIFY_CLIENT_ID:-}" ]]; then
    if [[ ! "$SPOTIFY_CLIENT_ID" =~ ^[[:alnum:]]+$ ]]; then
        printf '%s\n' "SPOTIFY_CLIENT_ID must contain only letters and numbers" >&2
        exit 1
    fi
    /usr/libexec/PlistBuddy -c "Set :SpotifyClientID $SPOTIFY_CLIENT_ID" "$CONTENTS_DIR/Info.plist"
fi

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"
chmod +x "$MACOS_DIR/$APP_NAME"

printf '%s\n' "Built $APP_DIR"
