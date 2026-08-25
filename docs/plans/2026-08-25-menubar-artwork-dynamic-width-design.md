# Menu Bar Artwork and Dynamic Width Design

## Goal

Make the menu bar item use only the space its current text needs, cap the default compact lyric width at 180 points, and optionally show the current track artwork on the right.

## Behavior

- Short lyrics and status text shrink to their measured content width instead of occupying the full configured maximum width.
- Long text remains capped by the active preset's menu bar width and continues to use the existing marquee behavior.
- The built-in **Menu Bar Compact** preset changes from 220 points to 180 points. Persisted, unmodified copies of the old built-in compact preset migrate from 220 to 180 points; user-customized widths remain unchanged.
- A **Show track artwork** toggle appears in Menu Bar settings and defaults to enabled, including when older settings JSON does not contain the new key.
- When enabled and artwork data is available, a 16×16-point rounded artwork thumbnail appears after the lyric text.
- When artwork is disabled, unavailable, or invalid, no fallback icon and no empty artwork space are shown.
- Existing leading playback/status symbols remain supported.

## Architecture

`AppSettings` owns the persisted artwork preference, and `AppModel` exposes the same persisted computed-property pattern used by the existing menu bar settings. `MenuBarStatusItemController` resolves whether artwork should be supplied and invalidates rendering when either the presentation or artwork changes.

`MenuBarStatusItemView` decodes and caches the AppKit image when artwork changes. The core `MenuBarStatusItemLayout` remains image-agnostic: it receives leading and trailing accessory widths and computes the effective text viewport as `min(contentWidth, maxViewportWidth)`. This keeps the layout math unit-testable without importing AppKit into `LyricXCore`.

## Layout

The item is laid out as:

`horizontal padding + optional leading symbol + text viewport + optional artwork spacing/artwork + horizontal padding`

The text viewport width is the smaller of measured content width and the configured maximum. The artwork's trailing accessory width includes its spacing, so it is added only when a valid image is actually drawable.

## Error Handling

Invalid artwork data is treated exactly like missing artwork: the thumbnail is omitted and the item does not reserve trailing space. Artwork loading continues to use the existing asynchronous playback artwork path; this change adds no new network request or dependency.

## Testing

- Update layout tests to prove short text shrinks, long text caps, and optional leading/trailing accessories contribute only when present.
- Add settings tests for the enabled default, backward-compatible decoding, and persistence.
- Add preset migration coverage for an untouched 220-point built-in compact preset and preservation of customized widths.
- Run the executable unit-test target and a debug build.
