# Menu Bar Timeline FPS Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restore Timeline-driven smooth menu-bar lyric animation while adding a Menu Bar frame-rate setting for 15, 30, 60, and 120 fps.

**Architecture:** Add app-level menu-bar animation settings with JSON persistence, wire the selected frame interval into `LyricXApp`'s `TimelineView`, and replace SwiftUI layout-based text measurement in `MenuBarLabelView` with pure AppKit/Core helper calculations. Keep menu-bar animation stateless so `MenuBarExtra` does not mutate `@State` or run `GeometryReader` on every frame.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit text measurement, Observation, Swift Package Manager, executable unit-test target via `swift run LyricXUnitTests`.

---

### Task 1: Add Menu-Bar Frame-Rate Model

**Files:**
- Create: `Sources/LyricXCore/Display/MenuBarAnimationFrameRate.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

**Step 1: Write failing tests**

Add calls near the existing menu-bar tests in `Sources/LyricXUnitTests/main.swift`:

```swift
try testMenuBarAnimationFrameRatesExposeSupportedValues()
try testMenuBarAnimationFrameRateIntervals()
try testMenuBarAnimationFrameRateCodableRoundTrip()
```

Add tests:

```swift
private static func testMenuBarAnimationFrameRatesExposeSupportedValues() throws {
    try expectEqual(MenuBarAnimationFrameRate.allCases, [.fps15, .fps30, .fps60, .fps120])
    try expectEqual(MenuBarAnimationFrameRate.default, .fps30)
}

private static func testMenuBarAnimationFrameRateIntervals() throws {
    try expectEqual(MenuBarAnimationFrameRate.fps15.frameInterval, 1.0 / 15.0)
    try expectEqual(MenuBarAnimationFrameRate.fps30.frameInterval, 1.0 / 30.0)
    try expectEqual(MenuBarAnimationFrameRate.fps60.frameInterval, 1.0 / 60.0)
    try expectEqual(MenuBarAnimationFrameRate.fps120.frameInterval, 1.0 / 120.0)
}

private static func testMenuBarAnimationFrameRateCodableRoundTrip() throws {
    let data = try JSONEncoder().encode(MenuBarAnimationFrameRate.fps120)
    let decoded = try JSONDecoder().decode(MenuBarAnimationFrameRate.self, from: data)

    try expectEqual(decoded, .fps120)
}
```

**Step 2: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL because `MenuBarAnimationFrameRate` does not exist.

**Step 3: Implement model**

Create `Sources/LyricXCore/Display/MenuBarAnimationFrameRate.swift`:

```swift
import Foundation

public enum MenuBarAnimationFrameRate: Int, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case fps15 = 15
    case fps30 = 30
    case fps60 = 60
    case fps120 = 120

    public var id: Int { rawValue }

    public var label: String {
        "\(rawValue) fps"
    }

    public var frameInterval: TimeInterval {
        1.0 / TimeInterval(rawValue)
    }

    public static let `default` = MenuBarAnimationFrameRate.fps30
}
```

**Step 4: Run test to verify it passes**

Run: `swift run LyricXUnitTests`

Expected: PASS with `LyricXUnitTests passed`.

**Step 5: Commit**

```bash
git add Sources/LyricXCore/Display/MenuBarAnimationFrameRate.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: add menu bar animation frame rates"
```

### Task 2: Add App Settings Persistence

**Files:**
- Modify: `Sources/LyricX/App/AppSettings.swift`
- Create: `Sources/LyricX/App/AppSettingsStore.swift`
- Modify: `Sources/LyricX/App/AppModel.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

**Step 1: Write failing tests**

Add calls in `Sources/LyricXUnitTests/main.swift` near the style preset store tests:

```swift
try testAppSettingsDefaultFrameRateIsThirtyFPS()
try testAppSettingsStoreSavesAndLoadsFrameRate()
```

Add tests:

```swift
private static func testAppSettingsDefaultFrameRateIsThirtyFPS() throws {
    try expectEqual(AppSettings.default.menuBarFrameRate, .fps30)
}

private static func testAppSettingsStoreSavesAndLoadsFrameRate() throws {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    let store = AppSettingsStore(fileURL: url)
    var settings = AppSettings.default
    settings.menuBarFrameRate = .fps120

    try store.save(settings)
    let loaded = try store.load()

    try? FileManager.default.removeItem(at: url)
    try expectEqual(loaded, settings)
}
```

**Step 2: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL because `AppSettings` is not public/available to the test target and `AppSettingsStore` does not exist.

**Step 3: Move app settings model into core**

Create `Sources/LyricXCore/Settings/AppSettings.swift`:

```swift
import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var showsLyrics: Bool
    public var showsTrackWhenLyricsMissing: Bool
    public var menuBarFrameRate: MenuBarAnimationFrameRate

    public init(
        showsLyrics: Bool = true,
        showsTrackWhenLyricsMissing: Bool = true,
        menuBarFrameRate: MenuBarAnimationFrameRate = .default
    ) {
        self.showsLyrics = showsLyrics
        self.showsTrackWhenLyricsMissing = showsTrackWhenLyricsMissing
        self.menuBarFrameRate = menuBarFrameRate
    }
}

public extension AppSettings {
    static let `default` = AppSettings()
}
```

Delete or empty the old app-target-only `Sources/LyricX/App/AppSettings.swift` so there is only one `AppSettings` type visible to `LyricX`.

**Step 4: Add app settings store**

Create `Sources/LyricXCore/Settings/AppSettingsStore.swift`:

```swift
import Foundation

public struct AppSettingsStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .default
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(AppSettings.self, from: data)
    }

    public func save(_ settings: AppSettings) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }
}
```

**Step 5: Wire store into AppModel**

In `Sources/LyricX/App/AppModel.swift`:

- Add `@ObservationIgnored private let settingsStore: AppSettingsStore`.
- Add an initializer parameter with default `AppSettingsStore(fileURL: AppModel.defaultSettingsStoreURL())`.
- Initialize `settings` from `(try? settingsStore.load()) ?? .default` before style presets are loaded.
- Persist settings when `isLyricsVisible`, `showsTrackWhenLyricsMissing`, or `menuBarFrameRate` changes.
- Add:

```swift
var menuBarFrameRate: MenuBarAnimationFrameRate {
    get { settings.menuBarFrameRate }
    set {
        settings.menuBarFrameRate = newValue
        persistSettings()
    }
}
```

- Add `persistSettings()` and `defaultSettingsStoreURL()` following the existing preset store URL pattern, using `app-settings.json`.

**Step 6: Run test to verify it passes**

Run: `swift run LyricXUnitTests`

Expected: PASS with `LyricXUnitTests passed`.

**Step 7: Commit**

```bash
git add Sources/LyricXCore/Settings Sources/LyricX/App/AppSettings.swift Sources/LyricX/App/AppModel.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: persist menu bar animation settings"
```

### Task 3: Add Menu Bar FPS Control to Settings UI

**Files:**
- Modify: `Sources/LyricX/Settings/SettingsView.swift`

**Step 1: Add Menu Bar section**

In `SettingsView.body`, add a new section after `Lyrics` and before `Player`:

```swift
Section("Menu Bar") {
    Picker("Animation Frame Rate", selection: $model.menuBarFrameRate) {
        ForEach(MenuBarAnimationFrameRate.allCases) { frameRate in
            Text(frameRate.label).tag(frameRate)
        }
    }
    .pickerStyle(.segmented)
}
```

**Step 2: Run build**

Run: `swift build`

Expected: PASS with `Build complete!`.

**Step 3: Commit**

```bash
git add Sources/LyricX/Settings/SettingsView.swift
git commit -m "feat: add menu bar frame rate setting"
```

### Task 4: Add Stateless Timeline Marquee Math

**Files:**
- Create: `Sources/LyricXCore/Display/MenuBarTimelineMarquee.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

**Step 1: Write failing tests**

Add calls near existing marquee tests:

```swift
try testTimelineMarqueeOffsetPausesBeforeMoving()
try testTimelineMarqueeOffsetMovesAtConfiguredSpeed()
try testTimelineMarqueeOffsetWrapsAfterCycle()
try testTimelineMarqueeOffsetStaysZeroWithoutOverflow()
```

Add tests:

```swift
private static func testTimelineMarqueeOffsetPausesBeforeMoving() throws {
    let marquee = MenuBarTimelineMarquee(viewportWidth: 220, gap: 36, speed: 34, startPause: 0.8)

    try expectEqual(marquee.offset(elapsedTime: 0.4, contentWidth: 320), 0)
}

private static func testTimelineMarqueeOffsetMovesAtConfiguredSpeed() throws {
    let marquee = MenuBarTimelineMarquee(viewportWidth: 220, gap: 36, speed: 34, startPause: 0.8)

    try expectEqual(marquee.offset(elapsedTime: 1.8, contentWidth: 320), -34)
}

private static func testTimelineMarqueeOffsetWrapsAfterCycle() throws {
    let marquee = MenuBarTimelineMarquee(viewportWidth: 220, gap: 36, speed: 34, startPause: 0.8)
    let cycleDuration = marquee.cycleDuration(contentWidth: 320)

    try expectEqual(marquee.offset(elapsedTime: cycleDuration + 0.4, contentWidth: 320), 0)
}

private static func testTimelineMarqueeOffsetStaysZeroWithoutOverflow() throws {
    let marquee = MenuBarTimelineMarquee(viewportWidth: 220, gap: 36, speed: 34, startPause: 0.8)

    try expectEqual(marquee.offset(elapsedTime: 10, contentWidth: 200), 0)
}
```

**Step 2: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL because `MenuBarTimelineMarquee` does not exist.

**Step 3: Implement pure marquee math**

Create `Sources/LyricXCore/Display/MenuBarTimelineMarquee.swift`:

```swift
import Foundation

public struct MenuBarTimelineMarquee: Equatable, Sendable {
    public let viewportWidth: Double
    public let gap: Double
    public let speed: Double
    public let startPause: TimeInterval

    public init(viewportWidth: Double, gap: Double = 36, speed: Double = 34, startPause: TimeInterval = 0.8) {
        self.viewportWidth = max(viewportWidth, 1)
        self.gap = max(gap, 0)
        self.speed = max(speed, 1)
        self.startPause = max(startPause, 0)
    }

    public func cycleDuration(contentWidth: Double) -> TimeInterval {
        guard contentWidth > viewportWidth else {
            return startPause
        }
        return startPause + TimeInterval((contentWidth + gap) / speed)
    }

    public func offset(elapsedTime: TimeInterval, contentWidth: Double) -> Double {
        guard contentWidth > viewportWidth else {
            return 0
        }

        let cycle = cycleDuration(contentWidth: contentWidth)
        let cycleTime = elapsedTime.truncatingRemainder(dividingBy: cycle)
        guard cycleTime > startPause else {
            return 0
        }

        let movingTime = cycleTime - startPause
        let travel = contentWidth + gap
        return -min(travel, movingTime * speed)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `swift run LyricXUnitTests`

Expected: PASS with `LyricXUnitTests passed`.

**Step 5: Commit**

```bash
git add Sources/LyricXCore/Display/MenuBarTimelineMarquee.swift Sources/LyricXUnitTests/main.swift
git commit -m "test: cover timeline marquee offsets"
```

### Task 5: Replace Layout Measurement with AppKit Text Measurement

**Files:**
- Create: `Sources/LyricX/Menu/MenuBarTextMetrics.swift`
- Modify: `Sources/LyricX/Menu/MenuBarLabelView.swift`
- Modify: `Sources/LyricX/App/MenuBarPresentation.swift`
- Modify: `Sources/LyricX/App/AppModel.swift`

**Step 1: Add text metrics helper**

Create `Sources/LyricX/Menu/MenuBarTextMetrics.swift`:

```swift
import AppKit
import Foundation

struct MenuBarTextMetrics {
    let fontSize: CGFloat
    let fontWeight: NSFont.Weight

    init(fontSize: CGFloat = 13, fontWeight: NSFont.Weight = .medium) {
        self.fontSize = fontSize
        self.fontWeight = fontWeight
    }

    func width(for text: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
        return (text as NSString).size(withAttributes: [.font: font]).width
    }
}
```

**Step 2: Update presentation behavior**

In `MenuBarPresentation.swift`, change continuous marquee behavior to carry content width and stable start time:

```swift
case continuousMarquee(contentWidth: Double, startedAt: Date)
```

**Step 3: Provide width and start time from AppModel**

In `AppModel`, add:

```swift
@ObservationIgnored private let menuBarTextMetrics = MenuBarTextMetrics()
```

For synced lyrics, compute:

```swift
let contentWidth = Double(menuBarTextMetrics.width(for: lyric))
let startedAt = playbackUpdatedAt.addingTimeInterval(line.time - playback.position)
```

Return `.continuousMarquee(contentWidth: contentWidth, startedAt: startedAt)` for long lyrics.

Preserve fallback title/status behavior for now unless the plan is expanded later.

**Step 4: Make MenuBarLabelView stateless**

In `MenuBarLabelView`:

- Remove `@State private var continuousTextWidth`.
- Remove `TextWidthPreferenceKey`.
- Remove `TextWidthReader`.
- Add `let date: Date`.
- Add a `MenuBarTimelineMarquee(viewportWidth: Double(fixedTextWidth))` helper.
- For `.continuousMarquee(contentWidth: startedAt:)`, compute elapsed time from `date.timeIntervalSince(startedAt)`.
- Render a primary text offset by `offset` and, when overflowing, a second copy offset by `offset + contentWidth + gap`.

Use this shape:

```swift
private func continuousMarqueeText(contentWidth: Double, startedAt: Date) -> some View {
    let marquee = MenuBarTimelineMarquee(viewportWidth: Double(fixedTextWidth))
    let offset = CGFloat(marquee.offset(elapsedTime: date.timeIntervalSince(startedAt), contentWidth: contentWidth))
    let gap = CGFloat(marquee.gap)

    return ZStack(alignment: .leading) {
        marqueeText.offset(x: offset)

        if contentWidth > Double(fixedTextWidth) {
            marqueeText.offset(x: offset + CGFloat(contentWidth) + gap)
        }
    }
    .frame(width: fixedTextWidth, height: 18, alignment: .leading)
    .clipped()
}
```

Keep `marqueeText` as a reusable `Text(presentation.text)` with the same font, line limit, and fixed horizontal size.

**Step 5: Run build to find call-site errors**

Run: `swift build`

Expected: FAIL until `LyricXApp` passes `date` in Task 6. Do not commit a non-building state.

### Task 6: Restore TimelineView with Configurable FPS

**Files:**
- Modify: `Sources/LyricX/App/LyricXApp.swift`

**Step 1: Wire TimelineView**

In `LyricXApp`, change the menu-bar label to:

```swift
TimelineView(.periodic(
    from: Date(timeIntervalSinceReferenceDate: 0),
    by: container.model.menuBarFrameRate.frameInterval
)) { context in
    MenuBarLabelView(
        presentation: container.model.menuBarPresentation(at: context.date),
        date: context.date
    )
}
```

**Step 2: Run verification**

Run: `swift run LyricXUnitTests`

Expected: PASS with `LyricXUnitTests passed`.

Run: `swift build`

Expected: PASS with `Build complete!`.

**Step 3: Commit Tasks 5-6 together**

```bash
git add Sources/LyricX/Menu/MenuBarTextMetrics.swift Sources/LyricX/Menu/MenuBarLabelView.swift Sources/LyricX/App/MenuBarPresentation.swift Sources/LyricX/App/AppModel.swift Sources/LyricX/App/LyricXApp.swift
git commit -m "fix: restore timeline menu bar marquee safely"
```

### Task 7: Final Verification and Runtime Memory Check

**Files:**
- Review: `Sources/LyricXCore/Display/MenuBarAnimationFrameRate.swift`
- Review: `Sources/LyricXCore/Display/MenuBarTimelineMarquee.swift`
- Review: `Sources/LyricXCore/Settings/AppSettings.swift`
- Review: `Sources/LyricXCore/Settings/AppSettingsStore.swift`
- Review: `Sources/LyricX/App/AppModel.swift`
- Review: `Sources/LyricX/App/LyricXApp.swift`
- Review: `Sources/LyricX/Menu/MenuBarLabelView.swift`
- Review: `Sources/LyricX/Menu/MenuBarTextMetrics.swift`
- Review: `Sources/LyricX/Settings/SettingsView.swift`
- Review: `Sources/LyricXUnitTests/main.swift`

**Step 1: Inspect final diff**

Run: `git diff origin/main..HEAD -- Sources/LyricXCore Sources/LyricX Sources/LyricXUnitTests docs/plans`

Expected: Diff matches the design: FPS setting, app settings persistence, TimelineView wiring, stateless menu-bar text measurement, tests, and docs.

**Step 2: Run full verification**

Run: `swift run LyricXUnitTests`

Expected: PASS with `LyricXUnitTests passed`.

Run: `swift build`

Expected: PASS with `Build complete!`.

Run: `bash scripts/build-app.sh`

Expected: PASS and `dist/LyricX.app` exists.

**Step 3: Runtime launch check**

Run the app briefly with `swift run LyricX`, sample RSS several times with `ps`, then stop the process.

Expected: App launches without immediate crash. RSS should not climb aggressively during the short sample window.

**Step 4: Manual UI check**

Open Settings, verify the `Menu Bar` section has the four frame-rate choices, and play a long synced lyric line.

Expected:
- 15 fps is visibly lower refresh.
- 30 fps is the default.
- 60 and 120 fps update more smoothly.
- Menu-bar memory does not show obvious rapid growth during brief use.

**Step 5: Commit any follow-up fix separately**

If runtime inspection reveals a small issue, make the smallest scoped fix, rerun `swift run LyricXUnitTests`, `swift build`, and `bash scripts/build-app.sh`, then commit with a focused `fix:` message.
