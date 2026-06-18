# Floating Lyrics Design

## Status

Accepted on 2026-06-18.

## Context

LyricX already shows synced Spotify lyrics in the menu bar and in the main window. Earlier design work called out a desktop floating lyric window as a product direction, but the first GUI phase intentionally left the settings entry disabled.

The next step is to implement floating lyrics as a first-class desktop overlay. The requested scope includes lock and click-through behavior, configurable background opacity, true KTV-style lyric following, and manual timing offsets in milliseconds.

The current lyric pipeline stores LRCLIB `syncedLyrics` text and parses line-level LRC timestamps into `LyricLine`. That supports line-level lyric display today. True KTV mode must only run when the lyric data contains source-provided word or segment timestamps; LyricX should not fabricate per-word timings from ordinary line-level LRC.

## Decisions

### Floating Window

Add a desktop floating lyric window managed by an AppKit `NSPanel` controller.

The panel should be borderless, non-activating, always on top, and hosted with SwiftUI content. It should show the current lyric line prominently and the next line as secondary context. The panel should remain stable in size when lyrics change so the overlay does not jump during playback.

The panel should be draggable when unlocked. When locked, it should keep its current position and avoid accidental movement. When click-through is enabled, it should ignore mouse events so the user can interact with windows underneath it.

### Settings Surface

Replace the disabled Floating Lyrics settings row with real controls:

- Show Floating Lyrics.
- Lock Position.
- Click Through.
- Background Opacity.
- KTV Mode.
- Lyric Offset in milliseconds.
- Line Offset in milliseconds.
- KTV Segment Offset in milliseconds.

The menu-bar popover should also expose the high-frequency controls users need while listening: show floating lyrics, lock, click-through, and KTV mode. More detailed numeric controls can live in Settings.

### Timing Offsets

Store offsets as integer milliseconds in `AppSettings`.

Use the offsets as additive display calibration rather than changing Spotify playback state:

- `lyricOffsetMs` adjusts the base timeline position used by floating lyric display.
- `lineOffsetMs` adjusts line selection for floating lyric display.
- `segmentOffsetMs` adjusts timed segment progress inside KTV mode.

The existing menu-bar lyric timing should stay unchanged unless a later feature intentionally shares these offsets across display surfaces.

### True KTV Mode

KTV mode means timed segment highlighting driven by lyric-source timing data.

Extend the core lyric model with timed segments that can represent source-provided word, syllable, or character timing. The renderer should highlight completed/current segments based on playback position plus the segment offset.

When KTV mode is enabled but the active lyric line has no timed segments, the floating window should fall back to normal line-level rendering. It should not estimate word timing by splitting the line interval evenly.

### Lyric Parsing

Keep the existing LRC parser behavior for normal line-level lyrics.

Add support for enhanced LRC-style inline segment timestamps where the source includes them. The parser should preserve the plain display text while attaching segment timing to the relevant line. Unsupported or malformed inline timestamps should not crash parsing; the line should still display as normal text when possible.

### Persistence

Persist all floating lyric settings through the existing `AppSettingsStore` JSON file under Application Support.

Defaults should keep floating lyrics off, click-through off, lock off, KTV mode on but inert without timed segments, a moderate background opacity, and zero offsets. Existing settings JSON files should continue to decode by receiving default values for newly added fields.

### Architecture

`AppModel` remains the single UI-facing composition layer. It exposes floating lyric settings, calculates floating lyric presentation from the current playback snapshot and lyric timeline, and persists settings changes.

Add a `FloatingLyricsController` in the app target. `AppContainer` owns it beside the main window and menu-bar controller. The controller observes the model through a lightweight timer, shows or hides the `NSPanel`, and applies panel properties when settings change.

Add `FloatingLyricsView` for SwiftUI rendering. It receives a presentation value rather than reaching directly into playback services.

Core lyric parsing and timing logic belongs in `LyricXCore`, where it can be unit tested without AppKit.

## Error Handling

- If Spotify is not running, the floating panel should show the same concise status used elsewhere.
- If synced lyrics are missing and track fallback is enabled, show track text.
- If KTV mode is enabled but no timed segments exist, render the normal current line.
- If stored opacity or offsets are outside supported ranges, clamp them in UI-facing logic.
- If the panel cannot restore a previous position, center it on the active screen.

## Testing Strategy

Use `swift run LyricXUnitTests` for pure behavior coverage:

- App settings defaults include floating lyric options and zero offsets.
- Existing settings JSON decodes with default floating lyric values.
- Settings store saves and loads floating lyric options.
- Enhanced LRC inline timestamps parse into timed segments while preserving display text.
- Normal LRC lines have no timed segments and still parse as before.
- Floating lyric timing applies lyric, line, and segment offsets in milliseconds.
- KTV presentation falls back to line-level display when segments are unavailable.

Use `swift build` and `bash scripts/build-app.sh` as build gates because the feature adds AppKit window code.

Manual runtime verification should include toggling the panel, dragging it, locking it, enabling click-through, adjusting opacity, and checking that ordinary LRCLIB lyrics fall back cleanly when timed segments are absent.

## Out of Scope

- Adding a new lyric provider solely to obtain word-level timings.
- Fabricating KTV timings from line-level LRC.
- Applying floating lyric offsets to the menu-bar display.
- Importing or exporting style presets.
- Per-display multi-monitor placement rules beyond restoring the panel frame when possible.

## Risks

True KTV depends on source-provided inline timing. Most current LRCLIB responses may only contain line-level synced lyrics, so users should expect fallback behavior on many songs until a timed-segment lyric source is available.

Click-through can make the panel hard to interact with. The menu-bar popover and Settings view must always provide a way to turn click-through off.
