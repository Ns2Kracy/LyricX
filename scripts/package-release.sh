#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="LyricX"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
ZIP_PATH="$ROOT_DIR/dist/$APP_NAME.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

cd "$ROOT_DIR"

if [[ ! -x "$APP_DIR/Contents/MacOS/$APP_NAME" ]]; then
  printf '%s\n' "Missing app bundle at $APP_DIR. Run scripts/build-app.sh first." >&2
  exit 1
fi

rm -f "$ZIP_PATH" "$CHECKSUM_PATH"
ditto -c -k --keepParent "dist/$APP_NAME.app" "dist/$APP_NAME.zip"
shasum -a 256 "dist/$APP_NAME.zip" > "dist/$APP_NAME.zip.sha256"

printf '%s\n' "Packaged $ZIP_PATH"
printf '%s\n' "Wrote $CHECKSUM_PATH"
