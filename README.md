# LyricX

LyricX is a macOS menu-bar app with a companion SwiftUI window for synced Spotify lyrics, similar to the desktop lyric modes in NetEase Cloud Music or QQ Music.

It is built with SwiftUI and Swift Package Manager. The repository does not require a generated Xcode project for normal build, test, or packaging tasks.

## Features

- Shows the current synced lyric line in the macOS menu bar.
- Shows an optional always-on-top Dynamic Island-style floating lyric panel with lock, click-through, opacity, and timing controls.
- Provides a main LyricX window with track status, lyric preview, artwork, playback controls, and settings.
- Includes settings for lyric style presets, menu-bar width, font size, color, alignment, and missing-lyrics fallback behavior.
- Supports true KTV-style highlighting when the lyric source provides timed word or segment data, with line-level fallback otherwise.
- Falls back to the current Spotify track name when synced lyrics are missing.
- Hides the menu-bar icon when lyric or track text is available, and shows the icon only as the empty-state fallback.
- Reads local Spotify playback state through AppleScript.
- Fetches synced lyrics from LRCLIB and caches them in Application Support.
- Checks GitHub Releases manually from the app UI when you want to look for an update.

## Requirements

- macOS 14 or newer
- Apple Swift 6.2 or newer
- Spotify for macOS installed
- Internet access for LRCLIB lyric lookup
- Internet access for manual GitHub Release update checks

## Quick Start

Build the Swift package:

```bash
swift build
```

Run the logic test executable:

```bash
swift run LyricXUnitTests
```

Create a runnable app bundle:

```bash
bash scripts/build-app.sh
```

Launch the app:

```bash
open dist/LyricX.app
```

LyricX opens a main window and also keeps the lyric line in the menu bar. Open the menu-bar item to show the main window, control Spotify playback, refresh lyrics, toggle lyric text, show the track name when lyrics are missing, toggle floating lyrics, or quit. Settings live in the main window's Settings tab.

## Main Window

The main window has a Now Playing tab and a Settings tab. Now Playing shows the current Spotify track, playback state, previous/current/next lyric context, the active style preset, update status, and playback controls for previous, play/pause, next, and lyric refresh.

Spotify artwork is loaded when the current track exposes an artwork URL. LyricX falls back to a compact placeholder when artwork is unavailable.

## Settings

Open the main LyricX window and choose the Settings tab. Settings currently include:

- Lyric style preset selection and editing.
- Menu-bar width, font size, font weight, text color, alignment, and missing-lyrics fallback behavior.
- Spotify as the active phase-one music app.
- Disabled entries for future music-app support.
- Manual GitHub Release update checking and an Open Release link when an update is available.
- Floating lyric controls for visibility, lock, click-through, KTV mode, background opacity, and millisecond timing offsets.

Preset edits are saved as JSON under Application Support.

## Commands

| Command | Description |
| --- | --- |
| `swift build` | Build all SwiftPM targets in debug mode. |
| `swift run LyricXUnitTests` | Run the executable unit test suite. |
| `bash scripts/build-app.sh` | Build `dist/LyricX.app` in release mode. |
| `bash scripts/package-release.sh` | Package `dist/LyricX.app` as `dist/LyricX.zip` and write `dist/LyricX.zip.sha256`. |

## Packaging

Create a local release package with:

```bash
bash scripts/build-app.sh
bash scripts/package-release.sh
```

The packaged files are written to:

- `dist/LyricX.zip`
- `dist/LyricX.zip.sha256`

The app is currently unsigned. If macOS Gatekeeper blocks a downloaded build, users may need to remove quarantine manually or open it through Finder's context menu. Code signing and notarization can be added later once a Developer ID certificate is available.

## GitHub CI/CD

The repository includes two GitHub Actions workflows:

- `.github/workflows/ci.yml` runs on pull requests and pushes to `main`.
- `.github/workflows/release.yml` runs when a tag matching `v*` is pushed.

CI runs these gates on the macOS runner:

1. `swift run LyricXUnitTests`
2. `swift build`
3. `bash scripts/build-app.sh`
4. `bash scripts/package-release.sh`

The CI workflow uploads `LyricX.zip` and `LyricX.zip.sha256` as a build artifact.

## Release

Create and publish a GitHub release by pushing a version tag:

```bash
git tag v0.1.3
git push origin v0.1.3
```

The release workflow builds the app, packages the zip and checksum, then creates a GitHub Release with generated notes.

The workflow uses the default `GITHUB_TOKEN` with `contents: write` permission. No additional repository secrets are required for unsigned releases.

## Spotify Permissions

LyricX reads the local Spotify desktop app with AppleScript through `/usr/bin/osascript`. On first launch, macOS may ask for Automation permission to control Spotify or System Events. Approve that permission for playback sync to work.

Spotify is the only enabled music app in this phase. Apple Music, NetEase Cloud Music, QQ Music, and browser players are intentionally shown as disabled future entries in settings.

## Lyrics

Spotify playback state comes from the local Spotify app. Synced lyrics come from LRCLIB and are cached under Application Support. LyricX tries LRCLIB exact lookup first, then LRCLIB search.

If LRCLIB does not have synced lyrics for the current track, LyricX keeps polling Spotify and shows the track name or a visible `No synced lyrics for <track>` state.

Floating lyric KTV mode uses only source-provided timed word or segment timestamps. When the active lyric has only ordinary line-level LRC timestamps, LyricX shows the current line and next-line context without fabricating per-word timing.

## Project Layout

```text
Sources/LyricX/          SwiftUI menu-bar app target
Sources/LyricXCore/      Playback contracts, lyric lookup, parsing, caching, style, artwork, and update logic
Sources/LyricXMac/       macOS Spotify AppleScript playback adapter
Sources/LyricXUnitTests/ Executable test target for Command Line Tools environments
scripts/build-app.sh     Release app bundle builder
scripts/package-release.sh Release zip and checksum packager
.github/workflows/      CI and GitHub Release automation
```

## Troubleshooting

- Spotify must be installed, running, and playing a track for live playback state.
- macOS Automation permission is required before LyricX can read Spotify state.
- Some tracks do not have synced lyrics in LRCLIB; LyricX falls back to track text in that case.
- The app bundle in `dist/` is generated output and is intentionally not committed.
