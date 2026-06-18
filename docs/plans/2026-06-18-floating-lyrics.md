# Floating Lyrics Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the accepted floating lyric overlay with lock, click-through, background opacity, true source-timed KTV highlighting, and millisecond offsets.

**Architecture:** Keep playback polling in `AppModel`, add pure lyric/timing presentation logic to `LyricXCore`, and render the overlay through an AppKit `NSPanel` hosted by SwiftUI. Persist all user controls through `AppSettingsStore`, and make KTV mode depend only on source-provided timed segments.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit `NSPanel`, Swift Package Manager, executable unit test runner `LyricXUnitTests`.

---

### Task 1: Add Failing Tests for Floating Lyric Settings

**Files:**
- Modify: `Sources/LyricXUnitTests/main.swift`
- Later modify: `Sources/LyricXCore/Settings/AppSettings.swift`

**Step 1: Add test calls**

In `LyricXUnitTests.main()`, after `testAppSettingsStoreSavesAndLoadsFrameRate()`, add:

```swift
try testAppSettingsDefaultsIncludeFloatingLyrics()
try testAppSettingsDecodesLegacyJSONWithFloatingDefaults()
try testAppSettingsStoreSavesAndLoadsFloatingLyrics()
```

**Step 2: Add failing tests**

Near the existing app settings tests, add:

```swift
private static func testAppSettingsDefaultsIncludeFloatingLyrics() throws {
    let settings = AppSettings.default

    try expectEqual(settings.showsFloatingLyrics, false)
    try expectEqual(settings.floatingLyricsLocked, false)
    try expectEqual(settings.floatingLyricsClickThrough, false)
    try expectEqual(settings.floatingLyricsKTVEnabled, true)
    try expectEqual(settings.floatingLyricsBackgroundOpacity, 0.68)
    try expectEqual(settings.floatingLyricsLyricOffsetMs, 0)
    try expectEqual(settings.floatingLyricsLineOffsetMs, 0)
    try expectEqual(settings.floatingLyricsSegmentOffsetMs, 0)
    try expectNil(settings.floatingLyricsWindowFrame)
}

private static func testAppSettingsDecodesLegacyJSONWithFloatingDefaults() throws {
    let data = Data("""
    {
      "showsLyrics" : true,
      "showsTrackWhenLyricsMissing" : true,
      "menuBarFrameRate" : "fps60"
    }
    """.utf8)

    let settings = try JSONDecoder().decode(AppSettings.self, from: data)

    try expectEqual(settings.menuBarFrameRate, .fps60)
    try expectEqual(settings.showsFloatingLyrics, false)
    try expectEqual(settings.floatingLyricsKTVEnabled, true)
    try expectEqual(settings.floatingLyricsBackgroundOpacity, 0.68)
    try expectEqual(settings.floatingLyricsLyricOffsetMs, 0)
    try expectNil(settings.floatingLyricsWindowFrame)
}

private static func testAppSettingsStoreSavesAndLoadsFloatingLyrics() throws {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    let store = AppSettingsStore(fileURL: url)
    var settings = AppSettings.default
    settings.showsFloatingLyrics = true
    settings.floatingLyricsLocked = true
    settings.floatingLyricsClickThrough = true
    settings.floatingLyricsKTVEnabled = false
    settings.floatingLyricsBackgroundOpacity = 0.42
    settings.floatingLyricsLyricOffsetMs = 120
    settings.floatingLyricsLineOffsetMs = -80
    settings.floatingLyricsSegmentOffsetMs = 35
    settings.floatingLyricsWindowFrame = FloatingLyricsWindowFrame(x: 100, y: 200, width: 720, height: 120)

    try store.save(settings)
    let loaded = try store.load()

    try? FileManager.default.removeItem(at: url)
    try expectEqual(loaded, settings)
}
```

**Step 3: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL to compile because `AppSettings` has no floating lyric fields and `FloatingLyricsWindowFrame` does not exist.

**Step 4: Commit is not allowed yet**

Do not commit the failing test alone unless you need a WIP checkpoint. Continue to Task 2.

---

### Task 2: Implement Floating Lyric Settings Persistence

**Files:**
- Modify: `Sources/LyricXCore/Settings/AppSettings.swift`
- Test: `Sources/LyricXUnitTests/main.swift`

**Step 1: Add the frame model and settings fields**

Replace the current synthesized `Codable` implementation in `AppSettings.swift` with an explicit backward-compatible model:

```swift
public struct FloatingLyricsWindowFrame: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var showsLyrics: Bool
    public var showsTrackWhenLyricsMissing: Bool
    public var menuBarFrameRate: MenuBarAnimationFrameRate
    public var showsFloatingLyrics: Bool
    public var floatingLyricsLocked: Bool
    public var floatingLyricsClickThrough: Bool
    public var floatingLyricsKTVEnabled: Bool
    public var floatingLyricsBackgroundOpacity: Double
    public var floatingLyricsLyricOffsetMs: Int
    public var floatingLyricsLineOffsetMs: Int
    public var floatingLyricsSegmentOffsetMs: Int
    public var floatingLyricsWindowFrame: FloatingLyricsWindowFrame?

    public init(
        showsLyrics: Bool = true,
        showsTrackWhenLyricsMissing: Bool = true,
        menuBarFrameRate: MenuBarAnimationFrameRate = .default,
        showsFloatingLyrics: Bool = false,
        floatingLyricsLocked: Bool = false,
        floatingLyricsClickThrough: Bool = false,
        floatingLyricsKTVEnabled: Bool = true,
        floatingLyricsBackgroundOpacity: Double = 0.68,
        floatingLyricsLyricOffsetMs: Int = 0,
        floatingLyricsLineOffsetMs: Int = 0,
        floatingLyricsSegmentOffsetMs: Int = 0,
        floatingLyricsWindowFrame: FloatingLyricsWindowFrame? = nil
    ) {
        self.showsLyrics = showsLyrics
        self.showsTrackWhenLyricsMissing = showsTrackWhenLyricsMissing
        self.menuBarFrameRate = menuBarFrameRate
        self.showsFloatingLyrics = showsFloatingLyrics
        self.floatingLyricsLocked = floatingLyricsLocked
        self.floatingLyricsClickThrough = floatingLyricsClickThrough
        self.floatingLyricsKTVEnabled = floatingLyricsKTVEnabled
        self.floatingLyricsBackgroundOpacity = floatingLyricsBackgroundOpacity
        self.floatingLyricsLyricOffsetMs = floatingLyricsLyricOffsetMs
        self.floatingLyricsLineOffsetMs = floatingLyricsLineOffsetMs
        self.floatingLyricsSegmentOffsetMs = floatingLyricsSegmentOffsetMs
        self.floatingLyricsWindowFrame = floatingLyricsWindowFrame
    }
}
```

Add a custom decoder using `decodeIfPresent` and `.default` values for every new key. Preserve synthesized encoding by implementing `CodingKeys` and `encode(to:)`, or let synthesis work if all stored fields remain in the struct and only `init(from:)` is custom.

**Step 2: Run tests**

Run: `swift run LyricXUnitTests`

Expected: PASS for the new settings tests and all existing tests.

**Step 3: Commit**

```bash
git add Sources/LyricXCore/Settings/AppSettings.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: persist floating lyric settings"
```

---

### Task 3: Add Failing Tests for Source-Timed Lyric Segments

**Files:**
- Modify: `Sources/LyricXUnitTests/main.swift`
- Later modify: `Sources/LyricXCore/Lyrics/LyricLine.swift`
- Later modify: `Sources/LyricXCore/Lyrics/LRCParser.swift`

**Step 1: Add test calls**

After the existing parser tests in `main()`, add:

```swift
try testParsesEnhancedInlineSegmentTimestamps()
try testNormalTimestampedLineHasNoSegments()
```

**Step 2: Add failing tests**

Near the LRC parser tests, add:

```swift
private static func testParsesEnhancedInlineSegmentTimestamps() throws {
    let lines = LRCParser.parse("[00:10.00]<00:10.00>Hello <00:10.50>world")

    try expectEqual(lines, [
        LyricLine(
            time: 10.0,
            text: "Hello world",
            segments: [
                LyricSegment(time: 10.0, text: "Hello "),
                LyricSegment(time: 10.5, text: "world")
            ]
        )
    ])
}

private static func testNormalTimestampedLineHasNoSegments() throws {
    let lines = LRCParser.parse("[00:12.34]First line")

    try expectEqual(lines, [LyricLine(time: 12.34, text: "First line")])
    try expectEqual(lines[0].segments, [])
}
```

**Step 3: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL to compile because `LyricSegment` and the `LyricLine(time:text:segments:)` initializer do not exist.

---

### Task 4: Implement Timed Segment Parsing Without Breaking Normal LRC

**Files:**
- Modify: `Sources/LyricXCore/Lyrics/LyricLine.swift`
- Modify: `Sources/LyricXCore/Lyrics/LRCParser.swift`
- Test: `Sources/LyricXUnitTests/main.swift`

**Step 1: Add `LyricSegment`**

In `LyricLine.swift`, add:

```swift
public struct LyricSegment: Equatable, Sendable {
    public let time: TimeInterval
    public let text: String

    public init(time: TimeInterval, text: String) {
        self.time = time
        self.text = text
    }
}
```

Then add `public let segments: [LyricSegment]` to `LyricLine` and change its initializer to:

```swift
public init(time: TimeInterval, text: String, segments: [LyricSegment] = []) {
    self.time = time
    self.text = text
    self.segments = segments
}
```

**Step 2: Parse enhanced inline timestamps**

In `LRCParser.parseLine`, after extracting leading `[mm:ss.xx]` timestamps, parse the remainder for `<mm:ss.xx>` segment markers. Keep normal lines unchanged.

Use a helper shape like:

```swift
private static func parseSegments(_ rawText: String) -> (text: String, segments: [LyricSegment]) {
    var displayText = ""
    var segments: [LyricSegment] = []
    var remainder = rawText[...]

    while let markerStart = remainder.firstIndex(of: "<"),
          let markerEnd = remainder[markerStart...].firstIndex(of: ">") {
        displayText += remainder[..<markerStart]
        let tagStart = remainder.index(after: markerStart)
        let tag = String(remainder[tagStart..<markerEnd])
        guard let timestamp = parseTimestamp(tag) else {
            displayText += remainder[markerStart...]
            return (displayText, segments)
        }

        let segmentTextStart = remainder.index(after: markerEnd)
        let nextMarker = remainder[segmentTextStart...].firstIndex(of: "<") ?? remainder.endIndex
        let segmentText = String(remainder[segmentTextStart..<nextMarker])
        displayText += segmentText
        if !segmentText.isEmpty {
            segments.append(LyricSegment(time: timestamp, text: segmentText))
        }
        remainder = remainder[nextMarker...]
    }

    displayText += remainder
    return (displayText, segments)
}
```

Trim only the final display text in the same way current parsing does. Do not trim segment text because spaces can be significant for reconstructing the display line.

**Step 3: Run tests**

Run: `swift run LyricXUnitTests`

Expected: PASS.

**Step 4: Commit**

```bash
git add Sources/LyricXCore/Lyrics/LyricLine.swift Sources/LyricXCore/Lyrics/LRCParser.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: parse timed lyric segments"
```

---

### Task 5: Add Failing Tests for Floating Lyric Presentation and Offsets

**Files:**
- Create: `Sources/LyricXCore/Display/FloatingLyricsPresentation.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

**Step 1: Add test calls**

After the timeline context tests in `main()`, add:

```swift
try testFloatingPresentationUsesOffsetsForLineSelection()
try testFloatingPresentationBuildsKTVSegmentsWhenTimedSegmentsExist()
try testFloatingPresentationFallsBackWithoutTimedSegments()
```

**Step 2: Add failing tests**

Near timeline or display tests, add:

```swift
private static func testFloatingPresentationUsesOffsetsForLineSelection() throws {
    let timeline = LyricTimeline(lines: [
        LyricLine(time: 10.0, text: "First"),
        LyricLine(time: 12.0, text: "Second")
    ])
    var settings = AppSettings.default
    settings.floatingLyricsLyricOffsetMs = 500
    settings.floatingLyricsLineOffsetMs = 600

    let presentation = FloatingLyricsPresentation.make(
        timeline: timeline,
        playbackPosition: 10.95,
        statusText: "Lyrics synced",
        trackText: nil,
        showsTrackWhenLyricsMissing: true,
        settings: settings
    )

    try expectEqual(presentation.currentText, "Second")
    try expectEqual(presentation.nextText, nil)
}

private static func testFloatingPresentationBuildsKTVSegmentsWhenTimedSegmentsExist() throws {
    let timeline = LyricTimeline(lines: [
        LyricLine(
            time: 10,
            text: "Hello world",
            segments: [
                LyricSegment(time: 10.0, text: "Hello "),
                LyricSegment(time: 10.5, text: "world")
            ]
        )
    ])
    var settings = AppSettings.default
    settings.floatingLyricsKTVEnabled = true
    settings.floatingLyricsSegmentOffsetMs = 100

    let presentation = FloatingLyricsPresentation.make(
        timeline: timeline,
        playbackPosition: 10.45,
        statusText: "Lyrics synced",
        trackText: nil,
        showsTrackWhenLyricsMissing: true,
        settings: settings
    )

    try expectEqual(presentation.usesKTV, true)
    try expectEqual(presentation.segments.map(\.text), ["Hello ", "world"])
    try expectEqual(presentation.segments.map(\.isHighlighted), [true, true])
}

private static func testFloatingPresentationFallsBackWithoutTimedSegments() throws {
    let timeline = LyricTimeline(lines: [LyricLine(time: 10, text: "Line only")])
    var settings = AppSettings.default
    settings.floatingLyricsKTVEnabled = true

    let presentation = FloatingLyricsPresentation.make(
        timeline: timeline,
        playbackPosition: 10.2,
        statusText: "Lyrics synced",
        trackText: nil,
        showsTrackWhenLyricsMissing: true,
        settings: settings
    )

    try expectEqual(presentation.usesKTV, false)
    try expectEqual(presentation.currentText, "Line only")
    try expectEqual(presentation.segments, [])
}
```

**Step 3: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL to compile because `FloatingLyricsPresentation` does not exist.

---

### Task 6: Implement Pure Floating Lyric Presentation

**Files:**
- Create: `Sources/LyricXCore/Display/FloatingLyricsPresentation.swift`
- Test: `Sources/LyricXUnitTests/main.swift`

**Step 1: Add presentation structs**

Create `FloatingLyricsPresentation.swift`:

```swift
import Foundation

public struct FloatingLyricsSegmentPresentation: Equatable, Sendable {
    public let text: String
    public let isHighlighted: Bool

    public init(text: String, isHighlighted: Bool) {
        self.text = text
        self.isHighlighted = isHighlighted
    }
}

public struct FloatingLyricsPresentation: Equatable, Sendable {
    public let currentText: String
    public let nextText: String?
    public let segments: [FloatingLyricsSegmentPresentation]
    public let usesKTV: Bool
    public let backgroundOpacity: Double

    public init(
        currentText: String,
        nextText: String?,
        segments: [FloatingLyricsSegmentPresentation],
        usesKTV: Bool,
        backgroundOpacity: Double
    ) {
        self.currentText = currentText
        self.nextText = nextText
        self.segments = segments
        self.usesKTV = usesKTV
        self.backgroundOpacity = min(max(backgroundOpacity, 0), 1)
    }
}
```

**Step 2: Add the factory**

Add a static `make(...)` that computes:

```swift
let basePosition = playbackPosition + Double(settings.floatingLyricsLyricOffsetMs) / 1000
let linePosition = basePosition + Double(settings.floatingLyricsLineOffsetMs) / 1000
let segmentPosition = basePosition + Double(settings.floatingLyricsSegmentOffsetMs) / 1000
```

Use `linePosition` to choose `timeline.context(at:)`. Use `segmentPosition` only to mark timed segments highlighted. If no current line exists, use `trackText` when available and fallback is enabled; otherwise use `statusText`.

For KTV:

```swift
let ktvSegments = currentLine.segments.map {
    FloatingLyricsSegmentPresentation(text: $0.text, isHighlighted: $0.time <= segmentPosition)
}
let usesKTV = settings.floatingLyricsKTVEnabled && !ktvSegments.isEmpty
```

If `usesKTV` is false, return `segments: []`.

**Step 3: Run tests**

Run: `swift run LyricXUnitTests`

Expected: PASS.

**Step 4: Commit**

```bash
git add Sources/LyricXCore/Display/FloatingLyricsPresentation.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: add floating lyric presentation logic"
```

---

### Task 7: Expose Floating Lyric Settings and Presentation from AppModel

**Files:**
- Modify: `Sources/LyricX/App/AppModel.swift`
- Modify if needed: `Sources/LyricXCore/Settings/AppSettings.swift`

**Step 1: Add computed bindings**

In `AppModel`, add computed properties matching the existing `isLyricsVisible` style:

```swift
var showsFloatingLyrics: Bool {
    get { settings.showsFloatingLyrics }
    set {
        settings.showsFloatingLyrics = newValue
        persistSettings()
    }
}
```

Repeat for `floatingLyricsLocked`, `floatingLyricsClickThrough`, `floatingLyricsKTVEnabled`, `floatingLyricsBackgroundOpacity`, `floatingLyricsLyricOffsetMs`, `floatingLyricsLineOffsetMs`, and `floatingLyricsSegmentOffsetMs`. Clamp opacity to `0...1` on set.

**Step 2: Add frame persistence**

Add:

```swift
func updateFloatingLyricsWindowFrame(_ frame: FloatingLyricsWindowFrame) {
    guard settings.floatingLyricsWindowFrame != frame else {
        return
    }
    settings.floatingLyricsWindowFrame = frame
    persistSettings()
}
```

**Step 3: Add presentation method**

Add:

```swift
func floatingLyricsPresentation(at date: Date = Date()) -> FloatingLyricsPresentation {
    FloatingLyricsPresentation.make(
        timeline: timeline,
        playbackPosition: estimatedPlaybackPosition(at: date),
        statusText: lyricsStatus,
        trackText: playback.track.map { "\($0.title) - \($0.artist)" },
        showsTrackWhenLyricsMissing: showsTrackWhenLyricsMissing,
        settings: settings
    )
}
```

**Step 4: Build**

Run: `swift build`

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/LyricX/App/AppModel.swift
git commit -m "feat: expose floating lyric app state"
```

---

### Task 8: Replace Disabled Settings Row with Real Controls

**Files:**
- Modify: `Sources/LyricX/Settings/SettingsView.swift`
- Build check: `swift build`

**Step 1: Replace the Floating Lyrics section**

Replace the disabled section with controls:

```swift
Section("Floating Lyrics") {
    Toggle("Show Floating Lyrics", isOn: $model.showsFloatingLyrics)
    Toggle("Lock Position", isOn: $model.floatingLyricsLocked)
    Toggle("Click Through", isOn: $model.floatingLyricsClickThrough)
    Toggle("KTV Mode", isOn: $model.floatingLyricsKTVEnabled)

    HStack(spacing: 12) {
        Text("Background Opacity")
            .frame(width: 150, alignment: .leading)
        Slider(value: $model.floatingLyricsBackgroundOpacity, in: 0...1, step: 0.05)
        Text("\(Int(model.floatingLyricsBackgroundOpacity * 100))%")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 42, alignment: .trailing)
    }

    offsetStepper("Lyric Offset", value: $model.floatingLyricsLyricOffsetMs)
    offsetStepper("Line Offset", value: $model.floatingLyricsLineOffsetMs)
    offsetStepper("KTV Segment Offset", value: $model.floatingLyricsSegmentOffsetMs)
}
```

Add helper:

```swift
private func offsetStepper(_ title: String, value: Binding<Int>) -> some View {
    Stepper(value: value, in: -5000...5000, step: 10) {
        HStack {
            Text(title)
            Spacer()
            Text("\(value.wrappedValue) ms")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
```

**Step 2: Build**

Run: `swift build`

Expected: PASS.

**Step 3: Commit**

```bash
git add Sources/LyricX/Settings/SettingsView.swift
git commit -m "feat: add floating lyric settings controls"
```

---

### Task 9: Add Menu-Bar Quick Toggles

**Files:**
- Modify: `Sources/LyricX/Menu/MenuBarContentView.swift`
- Build check: `swift build`

**Step 1: Add quick toggles**

In `utilityMenu`, after the existing lyric toggles, add:

```swift
Toggle(isOn: boolBinding(\.showsFloatingLyrics)) {
    Label("Floating Lyrics", systemImage: "macwindow")
}

Toggle(isOn: boolBinding(\.floatingLyricsLocked)) {
    Label("Lock Floating Lyrics", systemImage: "lock")
}

Toggle(isOn: boolBinding(\.floatingLyricsClickThrough)) {
    Label("Click Through", systemImage: "cursorarrow.rays")
}

Toggle(isOn: boolBinding(\.floatingLyricsKTVEnabled)) {
    Label("KTV Mode", systemImage: "textformat")
}
```

**Step 2: Build**

Run: `swift build`

Expected: PASS.

**Step 3: Commit**

```bash
git add Sources/LyricX/Menu/MenuBarContentView.swift
git commit -m "feat: add floating lyric menu controls"
```

---

### Task 10: Build the SwiftUI Floating Lyrics View

**Files:**
- Create: `Sources/LyricX/Floating/FloatingLyricsView.swift`
- Build check: `swift build`

**Step 1: Create the folder and view**

Create `Sources/LyricX/Floating/FloatingLyricsView.swift` with:

```swift
import LyricXCore
import SwiftUI

struct FloatingLyricsView: View {
    let presentation: FloatingLyricsPresentation

    var body: some View {
        VStack(spacing: 6) {
            if presentation.usesKTV {
                ktvLine
            } else {
                Text(presentation.currentText)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            if let nextText = presentation.nextText {
                Text(nextText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .frame(width: 720, height: 112)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(presentation.backgroundOpacity))
        )
    }

    private var ktvLine: some View {
        HStack(spacing: 0) {
            ForEach(Array(presentation.segments.enumerated()), id: \.offset) { _, segment in
                Text(segment.text)
                    .foregroundStyle(segment.isHighlighted ? Color.white : Color.white.opacity(0.35))
            }
        }
        .font(.system(size: 28, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}
```

Keep the view simple. Do not add simulated KTV progress or per-character splitting.

**Step 2: Build**

Run: `swift build`

Expected: PASS.

**Step 3: Commit**

```bash
git add Sources/LyricX/Floating/FloatingLyricsView.swift
git commit -m "feat: add floating lyrics view"
```

---

### Task 11: Add AppKit Floating Lyrics Controller

**Files:**
- Create: `Sources/LyricX/Floating/FloatingLyricsController.swift`
- Modify: `Sources/LyricX/App/AppContainer.swift`
- Build check: `swift build`

**Step 1: Create the controller**

Create `FloatingLyricsController` as a `@MainActor final class` that owns:

```swift
private let model: AppModel
private var panel: NSPanel?
private var hostingController: NSHostingController<FloatingLyricsView>?
private var timer: Timer?
private var lastSettingsSnapshot: AppSettings?
```

**Step 2: Start a timer**

In `init(model:)`, start a `.common` run-loop timer using `model.menuBarFrameRate.frameInterval`. On each tick:

```swift
if model.showsFloatingLyrics {
    showOrUpdatePanel(date: Date())
} else {
    panel?.orderOut(nil)
}
```

**Step 3: Create the panel**

Use AppKit properties:

```swift
let panel = NSPanel(
    contentRect: restoredOrDefaultFrame(),
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)
panel.level = .floating
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
panel.isOpaque = false
panel.backgroundColor = .clear
panel.hasShadow = true
panel.hidesOnDeactivate = false
panel.isReleasedWhenClosed = false
panel.isMovableByWindowBackground = !model.floatingLyricsLocked && !model.floatingLyricsClickThrough
panel.ignoresMouseEvents = model.floatingLyricsClickThrough
```

Set `contentViewController` to `NSHostingController(rootView: FloatingLyricsView(presentation: model.floatingLyricsPresentation(at: date)))`.

**Step 4: Update panel behavior on each tick**

Update the root view and the panel properties:

```swift
hostingController?.rootView = FloatingLyricsView(presentation: model.floatingLyricsPresentation(at: date))
panel.isMovableByWindowBackground = !model.floatingLyricsLocked && !model.floatingLyricsClickThrough
panel.ignoresMouseEvents = model.floatingLyricsClickThrough
panel.orderFrontRegardless()
```

**Step 5: Persist the frame**

Make the controller an `NSWindowDelegate`. In `windowDidMove` and `windowDidResize`, persist:

```swift
let frame = panel.frame
model.updateFloatingLyricsWindowFrame(
    FloatingLyricsWindowFrame(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height)
)
```

Avoid persisting while click-through is on if it causes noisy movement events.

**Step 6: Wire into AppContainer**

Add a stored property:

```swift
let floatingLyricsController: FloatingLyricsController
```

Initialize it after `model`:

```swift
self.floatingLyricsController = FloatingLyricsController(model: model)
```

**Step 7: Build**

Run: `swift build`

Expected: PASS.

**Step 8: Commit**

```bash
git add Sources/LyricX/Floating/FloatingLyricsController.swift Sources/LyricX/App/AppContainer.swift
git commit -m "feat: add floating lyrics panel"
```

---

### Task 12: Update README and Final Verification

**Files:**
- Modify: `README.md`
- Verify: full build/test/package commands

**Step 1: Update README features and settings**

Replace the disabled floating lyrics mention with the implemented behavior. Mention that KTV mode requires source-provided timed segments and falls back to line-level lyrics when unavailable.

**Step 2: Run unit tests**

Run: `swift run LyricXUnitTests`

Expected: `LyricXUnitTests passed`.

**Step 3: Run package build**

Run: `swift build`

Expected: exit 0.

**Step 4: Build app bundle**

Run: `bash scripts/build-app.sh`

Expected: `dist/LyricX.app` is created.

**Step 5: Brief runtime launch check**

Run the app briefly with the existing local pattern:

```bash
swift run LyricX
```

If launched manually, quit it after confirming the app starts. If using an automated timeout, treat a timeout/termination after launch as acceptable only if there was no crash before termination.

**Step 6: Commit docs and any final polish**

```bash
git add README.md
git commit -m "docs: document floating lyrics"
```

**Step 7: Final status check**

Run: `git status --short`

Expected: no tracked files modified. Unrelated pre-existing untracked files, such as `.vscode/`, should remain untouched.
