# LyricX

LyricX is a macOS menu-bar app that shows synced Spotify lyrics in a floating desktop overlay, similar to NetEase or QQ Music desktop lyrics.

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

LyricX runs as a menu-bar-only app. The floating lyric panel appears near the lower center of the main display. Use the menu-bar item to show or hide lyrics, lock the panel position, enable click-through mode, refresh lyrics, or quit.

## Spotify Permissions

LyricX reads the local Spotify desktop app with AppleScript through `/usr/bin/osascript`. On first launch, macOS may ask for Automation permission to control Spotify or System Events. Approve that permission for playback sync to work.

## Lyrics

Spotify playback state comes from the local Spotify app. Synced lyrics come from LRCLIB and are cached under Application Support. If LRCLIB does not have synced lyrics for the current track, LyricX keeps polling Spotify and shows a visible `No synced lyrics found` state.

## Test

This Command Line Tools install does not expose Swift Testing or XCTest to SwiftPM, so pure logic tests run through a small executable test target:

```bash
swift run LyricXUnitTests
```
