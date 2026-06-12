# Spotify Menu Bar Lyrics Design

## Goal

Build a macOS menu-bar lyric app for Spotify that feels similar to NetEase or QQ Music desktop lyrics: a small status item controls a floating, always-on-top synced lyric overlay.

## Scope

- Create a new macOS app in this empty workspace using Swift Package Manager.
- Use modern SwiftUI for the app entry point, menu-bar scene, settings-style controls, and lyric overlay view.
- Use AppKit only where SwiftUI does not provide the necessary system primitive: the floating desktop lyric `NSPanel`.
- Read Spotify desktop playback locally through AppleScript so the first version does not require Spotify OAuth.
- Fetch synced lyrics from LRCLIB and cache them locally.
- Parse LRC timestamps and select the active lyric line from Spotify playback position.

## Architecture

The app is split into small services and views. `PlaybackService` polls Spotify desktop for title, artist, album, duration, play state, and position. `LyricsRepository` searches LRCLIB, stores results in a local cache, and falls back to embedded sample/local misses gracefully. `LRCParser` and `LyricTimeline` are pure Swift types with unit tests.

The SwiftUI `App` owns an observable `AppModel`. A `MenuBarExtra` exposes status, toggles, and app commands. `FloatingLyricsController` manages an AppKit `NSPanel` whose content is a SwiftUI `FloatingLyricsView`, giving the app a real draggable, non-activating, always-on-top lyric window.

## User Experience

- The menu-bar item uses a compact music-note symbol and opens a small menu with playback status, lyric visibility, lock/click-through controls, refresh, and quit.
- The floating lyric panel shows the current lyric line prominently and the next line below it.
- The overlay uses restrained dark translucent styling, strong contrast, and stable dimensions so lyric changes do not cause visible layout jumps.
- When Spotify is closed, paused, or lyrics are unavailable, the overlay shows a concise state rather than failing silently.

## Error Handling

- Spotify scripting failures become a visible `Spotify is not running` or `Waiting for Spotify` state.
- Network and lyric lookup failures are non-fatal and leave playback polling running.
- Empty or invalid LRC data returns no timeline rather than crashing.
- Cache writes are best-effort; failed writes do not block display.

## Testing

- Unit test LRC parsing, including multiple timestamp tags per line.
- Unit test active-line selection before, during, and after timeline bounds.
- Unit test LRCLIB URL construction so query encoding remains correct.

## Build Constraints

The machine currently has Apple Swift 6.2.4 and the macOS 26.2 SDK through Command Line Tools, but no full Xcode app. The project should therefore build with `swift build`, verify pure logic through an executable unit-test runner, and include a small shell script to package the executable into a `.app` bundle.
