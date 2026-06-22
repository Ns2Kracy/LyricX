# Island and Floating Lyrics Design

## Status

Accepted on 2026-06-22.

## Context

LyricX currently has a menu-bar lyric display and a first-pass desktop overlay called floating lyrics. That overlay is a normal floating panel: it is large, always prominent, not resizable, and has no in-panel close control. It should not be treated as Dynamic Island lyrics.

The requested product direction is to support two distinct lyric shapes:

- Floating Lyrics: a movable desktop lyric panel for users who want a visible overlay.
- Island Lyrics: a top-center, low-presence Dynamic Island-style lyric surface inspired by Alcove's Mac island behavior.

These should share lyric timing and presentation logic but must not share window behavior or visual structure. A floating desktop panel and a top-attached island have different constraints.

## Product Model

### Floating Lyrics

Floating Lyrics remains a desktop overlay. It should be useful when the user wants lyrics visible away from the menu bar.

It should be:

- Movable when unlocked.
- Resizable.
- Directly closable from its own UI.
- Visually quieter than the current thick black pill.
- Able to show current lyric, next lyric, and source-timed KTV highlighting.
- Configurable from Settings and quick menu controls.

Floating Lyrics should not pretend to be a Dynamic Island. It can live anywhere on screen and its interaction model is closer to a small lyrics window.

### Island Lyrics

Island Lyrics is a new display shape.

It should be:

- Anchored to the active screen's top center by default.
- Small by default, with a collapsed width that adapts to content within a constrained range.
- Low presence: translucent material, off-black tint, subtle border and shadow, compact typography.
- Expandable on hover or click into a larger island panel.
- Directly closable from the expanded UI.
- Non-resizable in the floating-window sense; it uses collapsed and expanded intrinsic sizes instead.
- Separate from Floating Lyrics in settings and menu controls.

The island should visually read as part of the top system area rather than a draggable desktop object. It should default back to top-center instead of encouraging arbitrary placement.

## UX States

### Island Collapsed

Collapsed is the default listening state.

- Height: about 34-42 px.
- Width: content-adaptive, about 180-420 px.
- Position: top center of the active screen, just below the menu bar / notch-safe visible frame.
- Content: current lyric if available, otherwise short track or status text.
- Long text: clamp to one line with fade/truncation or existing smooth marquee logic if it can be reused without adding layout instability.
- Interaction: hover or click expands.

### Island Expanded

Expanded appears on hover or click.

- Width: about 520-680 px.
- Height: about 92-140 px depending on content.
- Content: current lyric, next lyric, small playback/status context, and compact icon controls.
- Controls: hide island, lock/pin, click-through, open Settings.
- KTV: source-timed segments highlight when available; ordinary LRC falls back to line-level display.
- Dismissal: mouse leaves after a short delay, Escape if focused, or close button hides Island Lyrics.

### Floating Panel

The floating panel should gain:

- A close button in the panel chrome/content.
- Resize support with a minimum size.
- Persisted user frame after moves and resizes.
- A quieter visual style than the current large black capsule.

The existing lock and click-through settings still apply to Floating Lyrics. Click-through must remain recoverable from the menu bar and Settings.

## Settings

Replace the single "Floating Lyrics" settings bucket with separate sections:

### Floating Lyrics

- Show Floating Lyrics.
- Lock Position.
- Click Through.
- Background Opacity.
- KTV Mode.
- Lyric Offset in milliseconds.
- Line Offset in milliseconds.
- KTV Segment Offset in milliseconds.

### Island Lyrics

- Show Island Lyrics.
- Auto Expand on Hover.
- Click Through.
- KTV Mode.
- Background Opacity.
- Width preference or compact/comfortable density, if needed after implementation.

Island Lyrics can share timing offsets with Floating Lyrics in the first revision to avoid duplicate calibration settings. If user testing shows the island needs separate timing, add separate offsets later.

The menu-bar popover should expose high-frequency toggles:

- Show Floating Lyrics.
- Show Island Lyrics.
- Floating click-through.
- Island click-through.

## Architecture

### Core

Rename or generalize `FloatingLyricsPresentation` to `LyricOverlayPresentation` if it reduces confusion. It should remain pure Core logic and continue to compute:

- current text.
- next text.
- KTV segments.
- KTV availability.
- clamped background opacity.

Do not couple presentation logic to AppKit windows.

### App Model

`AppModel` remains the UI-facing composition layer. It should expose independent settings and bindings for:

- Floating Lyrics visibility and behavior.
- Island Lyrics visibility and behavior.
- Shared lyric overlay presentation at a given date.

Settings persistence must remain backward-compatible with existing JSON. Existing floating settings should continue decoding as before.

### Floating Lyrics

Keep `FloatingLyricsController` and `FloatingLyricsView`, but revise them so their naming and behavior match the floating panel:

- resizable `NSPanel`.
- movable when allowed.
- in-panel close action that sets `showsFloatingLyrics = false`.
- persisted frame after move/resize.
- calmer panel styling.

### Island Lyrics

Add `IslandLyricsController` and `IslandLyricsView`.

The controller owns a non-activating borderless `NSPanel` that:

- stays at top-center of the active or main screen.
- joins all spaces and works above full-screen windows when allowed by AppKit.
- updates size and position when collapsed/expanded state changes.
- does not persist arbitrary desktop position by default.

The view owns local interaction state:

- collapsed vs expanded.
- hover-driven expansion if enabled.
- close/hide action.
- compact icon controls.

Use simple SwiftUI transitions first. Prefer opacity, scale, and frame changes over complex custom animation. The island should feel fluid, but correctness and low layout instability matter more than ornamental motion.

## Error Handling

- If Spotify is not running, Island Lyrics shows a short status in collapsed mode and a clearer status in expanded mode.
- If synced lyrics are missing and track fallback is enabled, both overlays show track text.
- If KTV mode is enabled but no timed segments exist, both overlays render normal line-level lyrics.
- If click-through prevents interaction, Settings and menu-bar toggles must always provide a way to disable click-through.
- If the active screen cannot be identified, place Island Lyrics on `NSScreen.main`.

## Testing Strategy

Use `swift run LyricXUnitTests` for pure behavior:

- Legacy settings decode with defaults for new island settings.
- Settings store saves and loads island settings.
- Shared overlay presentation still handles offsets, fallback text, and KTV fallback.
- Island layout calculations produce constrained collapsed and expanded sizes.
- Top-center frame calculation stays within the visible screen.

Use `swift build` for AppKit/SwiftUI compile validation.

Use `bash scripts/build-app.sh` for bundle validation.

Manual runtime checks:

- Floating Lyrics can be shown, resized, closed from UI, moved, locked, and restored.
- Island Lyrics appears at top center, collapsed by default, expands on hover/click, and closes from UI.
- Menu-bar and Settings toggles can recover from click-through.
- Ordinary LRCLIB line-level lyrics do not fabricate KTV timing.

## Out of Scope

- Importing a new lyric provider solely for word-level timings.
- Recreating Alcove's full live-activities system.
- Screen-notch detection beyond reasonable top-center placement.
- Complex gesture systems beyond click/hover in this revision.
- Applying overlay timing offsets to the menu-bar lyric display.

## Risks

AppKit top-level panel behavior varies across Spaces, full-screen windows, and multi-monitor setups. The first implementation should keep placement conservative and recoverable through Settings/menu controls.

KTV remains limited by lyric source data. Most ordinary LRCLIB synced lyrics are line-timed only, so KTV will often fall back.

The existing Floating Lyrics implementation was already merged as a feature. This redesign should migrate it forward without breaking users who enabled it.
