# LyricX

LyricX is a macOS menu-bar app that shows synced Spotify lyrics directly in the macOS menu bar, similar to desktop lyric modes in NetEase or QQ Music.

## Requirements

- macOS 14 or newer
- Apple Swift 6.2 or newer
- Spotify for macOS installed
- Internet access for LRCLIB synced lyric lookup

This repo is set up for a Command Line Tools-only environment. It does not require a full Xcode project to build.

## Build

```bash
swift build
```

Create a runnable app bundle:

```bash
bash scripts/build-app.sh
```

The bundle is written to `dist/LyricX.app`.

## Run

```bash
open dist/LyricX.app
```

LyricX runs as a menu-bar-only app. The menu-bar item itself displays the current lyric line when synced lyrics are available. Use the menu to show or hide lyric text, show the track name when lyrics are missing, refresh lyrics, or quit.

## Spotify Permissions

LyricX reads the local Spotify desktop app with AppleScript through `/usr/bin/osascript`. On first launch, macOS may ask for Automation permission to control Spotify or System Events. Approve that permission for playback sync to work.

## Lyrics

Spotify playback state comes from the local Spotify app. Synced lyrics come from LRCLIB and are cached under Application Support. LyricX tries LRCLIB exact lookup first, then LRCLIB search. If LRCLIB does not have synced lyrics for the current track, LyricX keeps polling Spotify and shows the track name or a visible `No synced lyrics for <track>` state.

## Test

This Command Line Tools install does not expose Swift Testing or XCTest to SwiftPM, so pure logic tests run through a small executable test target:

```bash
swift run LyricXUnitTests
```
