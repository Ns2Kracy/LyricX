# Menu Bar Timeline FPS Design

## Status

Accepted on 2026-06-17.

## Context

LyricX previously had a smoother menu-bar lyric animation in `6064a6f fix: smooth menu bar lyric display`. That implementation used `TimelineView` at 30 fps and moved text by time-based pixel offsets. It was later removed in `05ca3da fix: stop menu bar marquee memory growth` because the menu-bar label did high-frequency SwiftUI layout work, especially `GeometryReader` and preference-key width measurement inside the animated label.

The current implementation avoids that memory growth, but synced lyrics are still less smooth than the old Timeline-based version. The latest smooth-marquee attempt also reintroduced `GeometryReader` in `MenuBarLabelView`, which is the same class of risk as the old memory issue.

## Decision

Restore a Timeline-driven menu-bar animation model, but keep the menu-bar label free of high-frequency SwiftUI layout measurement.

The menu-bar label should be driven by `TimelineView(.periodic(...))`, with a configurable frame rate. The frame-rate setting belongs in a dedicated Menu Bar settings section because it controls menu-bar rendering smoothness and power use, not lyric style presets.

Supported frame rates are:

- 15 fps
- 30 fps
- 60 fps
- 120 fps

The default is 30 fps.

## Menu Bar Settings

Add a `Menu Bar` section to `SettingsView`.

The section should include an `Animation Frame Rate` segmented picker with the four supported values. This setting is global for the menu-bar label and should not vary per `LyricStylePreset`.

Existing style presets remain unchanged for this feature. Moving `menuBarWidth` out of presets is out of scope.

## Animation Architecture

`LyricXApp` should wrap the `MenuBarLabelView` label in `TimelineView` using the selected frame-rate interval:

```swift
TimelineView(.periodic(from: Date(timeIntervalSinceReferenceDate: 0), by: model.settings.menuBarFrameRate.frameInterval)) { context in
    MenuBarLabelView(
        presentation: model.menuBarPresentation(at: context.date),
        date: context.date
    )
}
```

`MenuBarLabelView` should become stateless for continuous marquee rendering. It should not use `GeometryReader`, `PreferenceKey`, or `@State` for text measurement. Those APIs create a feedback loop between layout, state mutation, and high-frequency timeline ticks in a `MenuBarExtra` label.

Text width should be measured outside SwiftUI layout using a pure helper. The helper can use AppKit text measurement, for example `NSFont` and `NSString.size(withAttributes:)`, based on the menu-bar font size and weight already used by the label. The measured width should be passed into a pure offset function.

## Data Flow

`AppSettings` gains a `menuBarFrameRate` value. It should be persisted through a small JSON store under Application Support, following the same style as `LyricStylePresetStore`.

`AppModel` loads the app settings store at startup, exposes the selected frame rate to `LyricXApp` and `SettingsView`, and persists changes when the setting changes.

`MenuBarPresentation` can continue to carry behavior metadata, but continuous marquee behavior should use enough data for a stateless view to render the current frame from `date` and precomputed measurements.

## Memory and Performance Guardrails

Do not put `GeometryReader`, `PreferenceKey`, or `@State` width measurement in the `MenuBarExtra` label animation path.

A short runtime memory check should be part of verification. The check does not need to prove long-term memory behavior, but it should catch obvious immediate growth or crashes when the app is run briefly with the Timeline label active.

Higher frame rates increase CPU/GPU work. The UI should expose all requested values, but 30 fps stays the default because it balances smoothness and power use.

## Testing

Unit tests should cover pure logic:

- `MenuBarAnimationFrameRate` supported values and frame intervals.
- Codable round-trip for the frame-rate setting.
- App settings store defaults and persistence.
- Timeline marquee offset calculation, including pause, wraparound, and non-overflowing text.
- Existing lyric timing and fallback marquee tests should continue to pass.

Build verification should include:

- `swift run LyricXUnitTests`
- `swift build`
- `bash scripts/build-app.sh`

Runtime verification should include a brief app launch and RSS sampling where possible.

## Out of Scope

- Moving `menuBarWidth` out of style presets.
- Adding per-preset frame rates.
- Building a floating lyric window.
- Reworking lyric timing semantics.
- Adding advanced animation easing controls.
