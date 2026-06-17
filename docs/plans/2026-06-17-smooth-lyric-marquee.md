# Smooth Lyric Marquee Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace synced-lyric character-step marquee with a smooth pixel-level horizontal scroll in the macOS menu-bar label.

**Architecture:** Keep `AppModel` as the presentation decision layer, but pass full synced lyric text plus progress to SwiftUI instead of pre-slicing lyric text. Add a small pure offset helper in `LyricXCore` so scroll math is unit-tested. Render continuous lyric marquee in `MenuBarLabelView` with a fixed-width clipped viewport, measured text width, and animated horizontal offset.

**Tech Stack:** Swift 6.2, SwiftUI, Observation, Swift Package Manager, lightweight executable unit-test target via `swift run LyricXUnitTests`.

---

### Task 1: Add Tested Continuous Offset Math

**Files:**
- Modify: `Sources/LyricXCore/Display/MenuBarMarquee.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

**Step 1: Write failing tests**

Add test calls in `LyricXUnitTests.main()` after the existing marquee tests:

```swift
try testMenuBarMarqueeCalculatesContinuousScrollOffset()
try testMenuBarMarqueeClampsContinuousScrollProgress()
```

Add test functions:

```swift
private static func testMenuBarMarqueeCalculatesContinuousScrollOffset() throws {
    try expectEqual(MenuBarMarquee.scrollOffset(progress: 0.0, contentWidth: 300, visibleWidth: 220), 0)
    try expectEqual(MenuBarMarquee.scrollOffset(progress: 0.5, contentWidth: 300, visibleWidth: 220), -40)
    try expectEqual(MenuBarMarquee.scrollOffset(progress: 1.0, contentWidth: 300, visibleWidth: 220), -80)
    try expectEqual(MenuBarMarquee.scrollOffset(progress: 1.0, contentWidth: 200, visibleWidth: 220), 0)
}

private static func testMenuBarMarqueeClampsContinuousScrollProgress() throws {
    try expectEqual(MenuBarMarquee.scrollOffset(progress: -1.0, contentWidth: 300, visibleWidth: 220), 0)
    try expectEqual(MenuBarMarquee.scrollOffset(progress: 2.0, contentWidth: 300, visibleWidth: 220), -80)
}
```

**Step 2: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL because `MenuBarMarquee.scrollOffset(progress:contentWidth:visibleWidth:)` does not exist.

**Step 3: Implement minimal offset helper**

Add this public static method to `MenuBarMarquee`:

```swift
public static func scrollOffset(progress: Double, contentWidth: Double, visibleWidth: Double) -> Double {
    let overflow = max(contentWidth - visibleWidth, 0)
    let clampedProgress = min(max(progress, 0), 1)
    return -overflow * clampedProgress
}
```

**Step 4: Run test to verify it passes**

Run: `swift run LyricXUnitTests`

Expected: PASS with `LyricXUnitTests passed`.

**Step 5: Commit**

```bash
git add Sources/LyricXCore/Display/MenuBarMarquee.swift Sources/LyricXUnitTests/main.swift
git commit -m "test: cover continuous marquee offset"
```

### Task 2: Carry Continuous Lyric Marquee Metadata

**Files:**
- Modify: `Sources/LyricX/App/MenuBarPresentation.swift`
- Modify: `Sources/LyricX/App/AppModel.swift`

**Step 1: Extend presentation behavior**

Change `MenuBarTextBehavior` to include a continuous lyric marquee case:

```swift
enum MenuBarTextBehavior: Equatable {
    case staticText
    case marquee
    case continuousMarquee(progress: Double)
}
```

**Step 2: Route long synced lyrics through the new behavior**

In `AppModel.menuBarPresentation(at:)`, change the synced lyric branch so it always passes the full lyric text:

```swift
if let line = timeline?.currentLine(at: position), let lyric = nonBlank(line.text) {
    let isMarquee = lyric.count > marquee.visibleCharacters
    return MenuBarPresentation(
        text: lyric,
        accessibilityText: lyric,
        symbol: nil,
        behavior: isMarquee ? .continuousMarquee(progress: lyricProgress(for: line, at: position)) : .staticText
    )
}
```

Leave the fallback track-title and status branches unchanged so they still use `marquee.displayText(..., offset:)` and `.marquee`.

**Step 3: Build to verify app target compiles**

Run: `swift build`

Expected: FAIL until `MenuBarLabelView` handles `.continuousMarquee(progress:)` exhaustively.

**Step 4: Commit after Task 3 instead of here**

This task intentionally leaves the app target incomplete until the view rendering path is added in Task 3. Do not commit a non-building intermediate state.

### Task 3: Render Smooth Lyric Marquee in SwiftUI

**Files:**
- Modify: `Sources/LyricX/Menu/MenuBarLabelView.swift`

**Step 1: Add width measurement state and preference key**

Inside `MenuBarLabelView`, add state for measured text width:

```swift
@State private var continuousTextWidth: CGFloat = 0
```

Add helper types at file scope:

```swift
private struct TextWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct TextWidthReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: TextWidthPreferenceKey.self, value: proxy.size.width)
        }
    }
}
```

**Step 2: Split label text rendering by behavior**

Replace the inline `Text(presentation.text)` block with a `labelText` view builder:

```swift
@ViewBuilder
private var labelText: some View {
    switch presentation.behavior {
    case .continuousMarquee(let progress):
        continuousMarqueeText(progress: progress)
    case .staticText, .marquee:
        Text(presentation.text)
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .frame(width: usesFixedTextWidth ? fixedTextWidth : nil, alignment: .leading)
            .fixedSize(horizontal: !usesFixedTextWidth, vertical: false)
            .clipped()
    }
}
```

Use `labelText` in the `HStack` after the optional symbol.

**Step 3: Add continuous marquee view**

Add this helper to `MenuBarLabelView`:

```swift
private func continuousMarqueeText(progress: Double) -> some View {
    let offset = MenuBarMarquee.scrollOffset(
        progress: progress,
        contentWidth: Double(continuousTextWidth),
        visibleWidth: Double(fixedTextWidth)
    )

    return ZStack(alignment: .leading) {
        Text(presentation.text)
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .background(TextWidthReader())
            .offset(x: offset)
    }
    .frame(width: fixedTextWidth, alignment: .leading)
    .clipped()
    .onPreferenceChange(TextWidthPreferenceKey.self) { width in
        continuousTextWidth = width
    }
    .onChange(of: presentation.text) { _, _ in
        continuousTextWidth = 0
    }
    .animation(.linear(duration: 0.18), value: offset)
}
```

**Step 4: Confirm fixed-width logic still covers continuous marquee**

`usesFixedTextWidth` can remain as-is because synced lyrics have `symbol == nil`, but it is acceptable to make the behavior explicit:

```swift
private var usesFixedTextWidth: Bool {
    if case .continuousMarquee = presentation.behavior {
        return true
    }
    return presentation.symbol == nil || presentation.behavior == .marquee
}
```

**Step 5: Run verification**

Run: `swift run LyricXUnitTests`

Expected: PASS with `LyricXUnitTests passed`.

Run: `swift build`

Expected: PASS with `Build complete!`.

**Step 6: Commit**

```bash
git add Sources/LyricX/App/MenuBarPresentation.swift Sources/LyricX/App/AppModel.swift Sources/LyricX/Menu/MenuBarLabelView.swift
git commit -m "fix: render synced lyrics with smooth marquee"
```

### Task 4: Runtime Check and Final Review

**Files:**
- Review: `Sources/LyricXCore/Display/MenuBarMarquee.swift`
- Review: `Sources/LyricX/App/MenuBarPresentation.swift`
- Review: `Sources/LyricX/App/AppModel.swift`
- Review: `Sources/LyricX/Menu/MenuBarLabelView.swift`
- Review: `Sources/LyricXUnitTests/main.swift`

**Step 1: Inspect final diff**

Run: `git diff HEAD~2..HEAD -- Sources/LyricXCore/Display/MenuBarMarquee.swift Sources/LyricX/App/MenuBarPresentation.swift Sources/LyricX/App/AppModel.swift Sources/LyricX/Menu/MenuBarLabelView.swift Sources/LyricXUnitTests/main.swift`

Expected: Diff only touches continuous marquee math, presentation metadata, synced lyric presentation, SwiftUI rendering, and tests.

**Step 2: Run final verification**

Run: `swift run LyricXUnitTests`

Expected: PASS with `LyricXUnitTests passed`.

Run: `swift build`

Expected: PASS with `Build complete!`.

**Step 3: Manual runtime check**

Run the app from the existing developer flow, play a track with a long synced lyric line, and observe the menu-bar label.

Expected:
- Short synced lyrics remain static.
- Long synced lyrics move smoothly left across the fixed menu-bar width.
- The trailing end of a long lyric is visible before the next lyric timestamp.
- Track-title fallback still uses the existing character marquee behavior.

**Step 4: Commit any small follow-up fix separately**

If the runtime check reveals a minor UI adjustment, make the smallest scoped change, rerun `swift run LyricXUnitTests` and `swift build`, then commit with a focused `fix:` message.
