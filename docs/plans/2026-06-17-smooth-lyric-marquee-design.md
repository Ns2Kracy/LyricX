# Smooth Lyric Marquee Design

## Status

Accepted on 2026-06-17.

## Context

LyricX currently displays long synced lyric lines in the menu bar by slicing a fixed-width substring from the full lyric. `AppModel` computes lyric progress from the current playback position and the next lyric start time, then `MenuBarMarquee.displayText(_:progress:)` maps that progress to a character-window start index.

This keeps the menu-bar label stable, but it produces visible jumps because the displayed text changes by whole characters. The refresh task runs every 180 ms, so a long lyric appears to step through the sentence rather than glide. The previous fix made the final character window visible before the next line starts, but it did not change the character-step rendering model.

## Decision

Replace synced-lyric marquee rendering with pixel-level continuous horizontal scrolling.

The menu-bar label should keep a fixed-width lyric viewport. For synced lyrics that exceed the viewport width, SwiftUI should render the complete lyric text and shift it horizontally according to playback progress. Short lyric lines should remain static. Non-lyric fallback text, such as track title or status text, can continue using the existing character-window marquee for now.

This keeps the behavioral change narrow while addressing the user-visible roughness in synced lyrics.

## User Experience

When a long synced lyric line starts, the text begins aligned to the leading edge of the fixed menu-bar lyric width. As playback progresses toward the next lyric start time, the full text moves left continuously. Near the end of the line interval, the trailing end of the lyric is visible before the next lyric replaces it.

The next lyric starts exactly at its timestamp. At that point the text and offset reset for the new line.

## Architecture

`AppModel` remains responsible for choosing the display content and calculating lyric progress. Instead of pre-slicing long lyric text for synced lyrics, it should produce a presentation value that includes the full lyric text and a progress value.

`MenuBarPresentation` should distinguish between static text, character marquee text, and continuous lyric marquee text. This keeps the existing fallback marquee path intact while giving the SwiftUI menu-bar label enough information to render synced lyrics differently.

`MenuBarLabelView` should own the SwiftUI rendering mechanics for continuous lyric marquee. It should place the full lyric `Text` inside a fixed-width clipped viewport and apply a calculated horizontal offset.

The measured overflow distance should come from the rendered text width minus the fixed viewport width. SwiftUI layout should keep the viewport width stable so the menu-bar item does not resize during scrolling.

## Testing

Core unit tests should cover the pure presentation decision: long synced lyrics should produce continuous marquee metadata with full text and progress, while short synced lyrics should remain static. Existing `MenuBarMarquee` tests should continue covering fallback character marquee behavior.

The SwiftUI pixel offset itself is mostly a view-rendering concern. Verification should include `swift run LyricXUnitTests` and `swift build`. Manual runtime inspection in the macOS menu bar is still useful because AppKit menu-bar rendering can differ from pure SwiftUI previews.

## Out of Scope

- Changing lyric timing semantics.
- Adding easing, delayed start, or configurable scroll speed.
- Replacing fallback track-title/status marquee behavior.
- Persisting marquee preferences.

## Risks

SwiftUI text measurement in a menu-bar label can be sensitive to layout timing. If direct measurement makes the label unstable, the fallback should be a conservative fixed-width offset estimate or a small helper view that isolates measurement state from `AppModel`.

The fixed 220-point menu-bar text width is currently hard-coded in `MenuBarLabelView`. This design keeps that width unchanged to avoid coupling the smooth-scroll change to broader style-preset work.
