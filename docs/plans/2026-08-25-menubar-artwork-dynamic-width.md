# Menu Bar Artwork and Dynamic Width Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an enabled-by-default menu bar artwork option while making short menu bar content dynamically sized and reducing the compact preset maximum to 180 points.

**Architecture:** Keep pure width calculations in `LyricXCore` by extending `MenuBarStatusItemLayout` with a trailing accessory width. Persist the artwork preference in `AppSettings`, expose it through `AppModel`, and let the AppKit status-item view cache and draw only valid artwork supplied by the controller.

**Tech Stack:** Swift 6.2, AppKit, SwiftUI, Observation, Swift Package Manager, existing executable test harness.

---

### Task 1: Make menu bar layout content-sized

**Files:**

- Modify: `Sources/LyricXUnitTests/main.swift:59-62,549-581`
- Modify: `Sources/LyricXCore/Display/MenuBarPresentation.swift:39-70`

**Step 1: Write the failing layout tests**

Replace the fixed-width assertions with cases proving:

```swift
let short = MenuBarStatusItemLayout(
    maxViewportWidth: 180,
    contentWidth: 120,
    horizontalPadding: 8,
    leadingAccessoryWidth: 0,
    trailingAccessoryWidth: 0
)
try expectEqual(short.statusItemWidth, 136)
try expectEqual(short.textViewportWidth, 120)

let long = MenuBarStatusItemLayout(
    maxViewportWidth: 180,
    contentWidth: 320,
    horizontalPadding: 8,
    leadingAccessoryWidth: 18,
    trailingAccessoryWidth: 20
)
try expectEqual(long.statusItemWidth, 234)
try expectEqual(long.textViewportMinX, 26)
try expectEqual(long.textViewportWidth, 180)
```

Also cover a trailing accessory with short text and no leading accessory.

**Step 2: Run the test target to verify RED**

Run: `swift run LyricXUnitTests`
Expected: compilation failure because `trailingAccessoryWidth` does not exist, or assertion failures under the fixed-width implementation.

**Step 3: Implement the minimal layout calculation**

Add `trailingAccessoryWidth`, clamp it to zero, and calculate:

```swift
public var textViewportWidth: Double {
    min(contentWidth, maxViewportWidth)
}

public var statusItemWidth: Double {
    horizontalPadding * 2 + leadingAccessoryWidth + textViewportWidth + trailingAccessoryWidth
}

public var textViewportMinX: Double {
    horizontalPadding + leadingAccessoryWidth
}
```

**Step 4: Run tests to verify GREEN**

Run: `swift run LyricXUnitTests`
Expected: all tests pass.

**Step 5: Commit**

```bash
git add Sources/LyricXCore/Display/MenuBarPresentation.swift Sources/LyricXUnitTests/main.swift
git commit -m "fix: size menu bar lyrics to content"
```

### Task 2: Persist the artwork setting and shorten the compact default

**Files:**

- Modify: `Sources/LyricXCore/Settings/AppSettings.swift:91-175`
- Modify: `Sources/LyricX/App/AppModel.swift:35-65`
- Modify: `Sources/LyricX/Settings/SettingsView.swift:151-163`
- Modify: `Sources/LyricXCore/Styles/LyricStylePreset.swift:39-49`
- Modify: `Sources/LyricX/App/AppModel.swift:659-665`
- Modify: `Sources/LyricXUnitTests/main.swift:83-86,923-990`

**Step 1: Write failing settings and migration tests**

Add tests proving:

```swift
try expectEqual(AppSettings.default.showsMenuBarArtwork, true)
```

Older JSON without `showsMenuBarArtwork` decodes it as `true`, saving/loading preserves `false`, the built-in compact default is 180, an old untouched built-in compact preset at 220 migrates to 180, and a customized compact preset remains unchanged.

**Step 2: Run tests to verify RED**

Run: `swift run LyricXUnitTests`
Expected: compilation failures for the missing property and migration behavior.

**Step 3: Implement settings persistence**

Add `showsMenuBarArtwork: Bool = true` to `AppSettings`, its initializer assignment, coding key, and backward-compatible `decodeIfPresent` fallback. Add the matching `AppModel` getter/setter that calls `persistSettings()`. Add:

```swift
Toggle("Show track artwork", isOn: $model.showsMenuBarArtwork)
```

to the Menu Bar section.

**Step 4: Implement the compact width update and narrow migration**

Change only the built-in compact default from 220 to 180. During preset-state loading, migrate only the preset whose ID is the built-in compact ID and whose width is exactly 220; leave all other widths untouched, then persist only if migration occurred.

**Step 5: Run tests to verify GREEN**

Run: `swift run LyricXUnitTests`
Expected: all tests pass.

**Step 6: Commit**

```bash
git add Sources/LyricXCore/Settings/AppSettings.swift Sources/LyricX/App/AppModel.swift Sources/LyricX/Settings/SettingsView.swift Sources/LyricXCore/Styles/LyricStylePreset.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: configure menu bar track artwork"
```

### Task 3: Draw valid artwork on the right

**Files:**

- Modify: `Sources/LyricX/Menu/MenuBarStatusItemView.swift:5-240`
- Modify: `Sources/LyricX/Menu/MenuBarStatusItemController.swift:34-207`
- Modify: `Sources/LyricXUnitTests/main.swift`

**Step 1: Add a failing pure state-selection test**

Introduce the smallest core/app helper needed to prove artwork is selected only when the setting is enabled and valid data exists. Test enabled, disabled, and missing-data cases without testing AppKit drawing internals.

**Step 2: Run tests to verify RED**

Run: `swift run LyricXUnitTests`
Expected: compilation failure for the missing helper or failing selection assertion.

**Step 3: Pass and cache artwork in the status view**

Extend `MenuBarStatusItemView.update` to accept optional `TrackArtwork`. Decode `NSImage(data:)` only when artwork changes, cache the image, and expose no trailing accessory width when decoding fails. Use a 16-point image and 4-point spacing.

**Step 4: Include trailing artwork in layout and drawing**

Pass `trailingAccessoryWidth` into `MenuBarStatusItemLayout`. Draw the cached image at the right of the text viewport, vertically centered, clipped to a small rounded rectangle. Do not tint the artwork and do not draw a fallback symbol.

**Step 5: Make controller invalidation artwork-aware**

Resolve artwork as `model.showsMenuBarArtwork ? model.artwork : nil`. Track the last artwork alongside `lastPresentation` so artwork arrival/removal or a setting toggle redraws the status item even when lyric presentation is unchanged.

**Step 6: Run tests to verify GREEN**

Run: `swift run LyricXUnitTests`
Expected: all tests pass.

**Step 7: Commit**

```bash
git add Sources/LyricX/Menu/MenuBarStatusItemView.swift Sources/LyricX/Menu/MenuBarStatusItemController.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: show artwork beside menu bar lyrics"
```

### Task 4: Verify the complete behavior

**Files:**

- Review: all files changed above

**Step 1: Run the full executable test harness**

Run: `swift run LyricXUnitTests`
Expected: exit 0 with all tests passing and no skipped tests.

**Step 2: Build every package target**

Run: `swift build`
Expected: exit 0 without compiler errors.

**Step 3: Mechanically inspect the requested integration points**

Confirm that `showsMenuBarArtwork` exists in `AppSettings`, `AppModel`, and `SettingsView`; `trailingAccessoryWidth` is used by both layout and status-item rendering; the built-in compact width is 180; and no fallback artwork icon is introduced.

**Step 4: Review the diff for scope and secrets**

Run: `git diff --check && git diff HEAD~3 --stat && git status --short`
Expected: no whitespace errors, only planned source/test/docs changes, and pre-existing untracked `.omp/`, `.pi-glla/`, `.pi/` remain untouched.

**Step 5: Commit any verification-only correction if needed**

If corrections were required, rerun the affected checks and create one atomic fix commit. Otherwise, do not create an empty commit.
