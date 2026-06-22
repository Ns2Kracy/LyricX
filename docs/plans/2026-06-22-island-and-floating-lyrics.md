# Island and Floating Lyrics Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Split LyricX lyric overlays into two real modes: a repaired desktop Floating Lyrics panel and a new top-attached Dynamic Island-style Island Lyrics surface.

**Architecture:** Keep lyric timing and KTV segment logic in `LyricXCore`, expose separate Floating and Island settings through `AppModel`, and use separate AppKit `NSPanel` controllers for the two window behaviors. Floating Lyrics remains a movable/resizable desktop panel; Island Lyrics is a top-center, collapsed/expanded island with its own UI controls.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit `NSPanel`, Swift Package Manager, executable unit test runner `LyricXUnitTests`.

---

### Task 1: Add Failing Tests for Island Lyrics Settings

**Files:**
- Modify: `Sources/LyricXUnitTests/main.swift`
- Later modify: `Sources/LyricXCore/Settings/AppSettings.swift`

**Step 1: Add test calls**

In `LyricXUnitTests.main()`, after `testAppSettingsStoreSavesAndLoadsFloatingLyrics()`, add:

```swift
try testAppSettingsDefaultsIncludeIslandLyrics()
try testAppSettingsDecodesLegacyJSONWithIslandDefaults()
try testAppSettingsStoreSavesAndLoadsIslandLyrics()
```

**Step 2: Add failing tests**

Near the existing app settings tests, add:

```swift
private static func testAppSettingsDefaultsIncludeIslandLyrics() throws {
    let settings = AppSettings.default

    try expectEqual(settings.showsIslandLyrics, false)
    try expectEqual(settings.islandLyricsAutoExpandOnHover, true)
    try expectEqual(settings.islandLyricsClickThrough, false)
    try expectEqual(settings.islandLyricsKTVEnabled, true)
    try expectEqual(settings.islandLyricsBackgroundOpacity, 0.82)
}

private static func testAppSettingsDecodesLegacyJSONWithIslandDefaults() throws {
    let data = Data("""
    {
      "showsLyrics" : true,
      "showsTrackWhenLyricsMissing" : true,
      "menuBarFrameRate" : 60
    }
    """.utf8)

    let settings = try JSONDecoder().decode(AppSettings.self, from: data)

    try expectEqual(settings.showsIslandLyrics, false)
    try expectEqual(settings.islandLyricsAutoExpandOnHover, true)
    try expectEqual(settings.islandLyricsClickThrough, false)
    try expectEqual(settings.islandLyricsKTVEnabled, true)
    try expectEqual(settings.islandLyricsBackgroundOpacity, 0.82)
}

private static func testAppSettingsStoreSavesAndLoadsIslandLyrics() throws {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    let store = AppSettingsStore(fileURL: url)
    var settings = AppSettings.default
    settings.showsIslandLyrics = true
    settings.islandLyricsAutoExpandOnHover = false
    settings.islandLyricsClickThrough = true
    settings.islandLyricsKTVEnabled = false
    settings.islandLyricsBackgroundOpacity = 0.55

    try store.save(settings)
    let loaded = try store.load()

    try? FileManager.default.removeItem(at: url)
    try expectEqual(loaded, settings)
}
```

**Step 3: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL to compile because `AppSettings` has no Island Lyrics fields.

**Step 4: Commit is not allowed yet**

Do not commit the failing test alone. Continue to Task 2.

---

### Task 2: Implement Island Lyrics Settings Persistence

**Files:**
- Modify: `Sources/LyricXCore/Settings/AppSettings.swift`
- Test: `Sources/LyricXUnitTests/main.swift`

**Step 1: Add stored settings**

In `AppSettings`, add:

```swift
public var showsIslandLyrics: Bool
public var islandLyricsAutoExpandOnHover: Bool
public var islandLyricsClickThrough: Bool
public var islandLyricsKTVEnabled: Bool
public var islandLyricsBackgroundOpacity: Double
```

**Step 2: Update initializer defaults**

Add parameters to `AppSettings.init(...)`:

```swift
showsIslandLyrics: Bool = false,
islandLyricsAutoExpandOnHover: Bool = true,
islandLyricsClickThrough: Bool = false,
islandLyricsKTVEnabled: Bool = true,
islandLyricsBackgroundOpacity: Double = 0.82
```

Assign them to stored properties.

**Step 3: Update decoding**

In `init(from:)`, add `decodeIfPresent` lines:

```swift
showsIslandLyrics = try container.decodeIfPresent(Bool.self, forKey: .showsIslandLyrics) ?? defaults.showsIslandLyrics
islandLyricsAutoExpandOnHover = try container.decodeIfPresent(Bool.self, forKey: .islandLyricsAutoExpandOnHover) ?? defaults.islandLyricsAutoExpandOnHover
islandLyricsClickThrough = try container.decodeIfPresent(Bool.self, forKey: .islandLyricsClickThrough) ?? defaults.islandLyricsClickThrough
islandLyricsKTVEnabled = try container.decodeIfPresent(Bool.self, forKey: .islandLyricsKTVEnabled) ?? defaults.islandLyricsKTVEnabled
islandLyricsBackgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .islandLyricsBackgroundOpacity) ?? defaults.islandLyricsBackgroundOpacity
```

**Step 4: Update `CodingKeys`**

Add all five new keys to `CodingKeys`.

**Step 5: Run tests**

Run: `swift run LyricXUnitTests`

Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/LyricXCore/Settings/AppSettings.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: persist island lyric settings"
```

---

### Task 3: Add Failing Tests for Island Layout Calculations

**Files:**
- Modify: `Sources/LyricXUnitTests/main.swift`
- Later create: `Sources/LyricXCore/Display/IslandLyricsLayout.swift`

**Step 1: Add test calls**

After the floating presentation tests in `main()`, add:

```swift
try testIslandLayoutConstrainsCollapsedSize()
try testIslandLayoutConstrainsExpandedSize()
try testIslandLayoutPlacesFrameAtTopCenter()
```

**Step 2: Add failing tests**

Near display tests, add:

```swift
private static func testIslandLayoutConstrainsCollapsedSize() throws {
    let size = IslandLyricsLayout.size(
        for: .collapsed,
        preferredContentWidth: 900
    )

    try expectEqual(size.width, 420)
    try expectEqual(size.height, 38)
}

private static func testIslandLayoutConstrainsExpandedSize() throws {
    let size = IslandLyricsLayout.size(
        for: .expanded,
        preferredContentWidth: 900
    )

    try expectEqual(size.width, 680)
    try expectEqual(size.height, 128)
}

private static func testIslandLayoutPlacesFrameAtTopCenter() throws {
    let visibleFrame = OverlayScreenFrame(x: 0, y: 0, width: 1440, height: 900)
    let frame = IslandLyricsLayout.frame(
        in: visibleFrame,
        state: .collapsed,
        preferredContentWidth: 260,
        topInset: 8
    )

    try expectEqual(frame.x, 590)
    try expectEqual(frame.y, 854)
    try expectEqual(frame.width, 260)
    try expectEqual(frame.height, 38)
}
```

**Step 3: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL to compile because `IslandLyricsLayout` and `OverlayScreenFrame` do not exist.

---

### Task 4: Implement Pure Island Layout Logic

**Files:**
- Create: `Sources/LyricXCore/Display/IslandLyricsLayout.swift`
- Test: `Sources/LyricXUnitTests/main.swift`

**Step 1: Add pure geometry structs**

Create `IslandLyricsLayout.swift`:

```swift
import Foundation

public enum IslandLyricsDisplayState: Equatable, Sendable {
    case collapsed
    case expanded
}

public struct OverlaySize: Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct OverlayScreenFrame: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
```

**Step 2: Add layout factory**

Add:

```swift
public enum IslandLyricsLayout {
    public static func size(
        for state: IslandLyricsDisplayState,
        preferredContentWidth: Double
    ) -> OverlaySize {
        switch state {
        case .collapsed:
            return OverlaySize(width: min(max(preferredContentWidth, 180), 420), height: 38)
        case .expanded:
            return OverlaySize(width: min(max(preferredContentWidth, 520), 680), height: 128)
        }
    }

    public static func frame(
        in visibleFrame: OverlayScreenFrame,
        state: IslandLyricsDisplayState,
        preferredContentWidth: Double,
        topInset: Double
    ) -> OverlayScreenFrame {
        let size = size(for: state, preferredContentWidth: preferredContentWidth)
        return OverlayScreenFrame(
            x: visibleFrame.x + (visibleFrame.width - size.width) / 2,
            y: visibleFrame.y + visibleFrame.height - size.height - topInset,
            width: size.width,
            height: size.height
        )
    }
}
```

**Step 3: Run tests**

Run: `swift run LyricXUnitTests`

Expected: PASS.

**Step 4: Commit**

```bash
git add Sources/LyricXCore/Display/IslandLyricsLayout.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: add island lyric layout logic"
```

---

### Task 5: Generalize Overlay Presentation Naming

**Files:**
- Modify: `Sources/LyricXCore/Display/FloatingLyricsPresentation.swift`
- Modify: `Sources/LyricX/App/AppModel.swift`
- Modify: `Sources/LyricX/Floating/FloatingLyricsView.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

**Step 1: Rename public structs in place**

In `FloatingLyricsPresentation.swift`, rename:

- `FloatingLyricsSegmentPresentation` to `LyricOverlaySegmentPresentation`.
- `FloatingLyricsPresentation` to `LyricOverlayPresentation`.

Keep backward-compatible typealiases at the bottom:

```swift
public typealias FloatingLyricsSegmentPresentation = LyricOverlaySegmentPresentation
public typealias FloatingLyricsPresentation = LyricOverlayPresentation
```

**Step 2: Update app code to use new names**

In `AppModel`, add:

```swift
func lyricOverlayPresentation(at date: Date = Date()) -> LyricOverlayPresentation {
    LyricOverlayPresentation.make(
        timeline: timeline,
        playbackPosition: estimatedPlaybackPosition(at: date),
        statusText: lyricsStatus,
        trackText: playback.track.map { "\($0.title) - \($0.artist)" },
        showsTrackWhenLyricsMissing: showsTrackWhenLyricsMissing,
        settings: settings,
        ktvEnabled: settings.floatingLyricsKTVEnabled,
        backgroundOpacity: settings.floatingLyricsBackgroundOpacity
    )
}
```

Then keep `floatingLyricsPresentation(at:)` as a wrapper to avoid a large same-commit UI rewrite:

```swift
func floatingLyricsPresentation(at date: Date = Date()) -> LyricOverlayPresentation {
    lyricOverlayPresentation(at: date)
}
```

**Step 3: Adjust factory signature**

Change `make(...)` so KTV and opacity are explicit:

```swift
public static func make(
    timeline: LyricTimeline?,
    playbackPosition: TimeInterval,
    statusText: String,
    trackText: String?,
    showsTrackWhenLyricsMissing: Bool,
    settings: AppSettings,
    ktvEnabled: Bool,
    backgroundOpacity: Double
) -> LyricOverlayPresentation
```

Use `ktvEnabled` instead of `settings.floatingLyricsKTVEnabled`.

Use `backgroundOpacity` instead of `settings.floatingLyricsBackgroundOpacity`.

**Step 4: Update tests**

Replace `FloatingLyricsPresentation.make(...)` test calls with `LyricOverlayPresentation.make(...)`, passing:

```swift
ktvEnabled: settings.floatingLyricsKTVEnabled,
backgroundOpacity: settings.floatingLyricsBackgroundOpacity
```

**Step 5: Run tests**

Run: `swift run LyricXUnitTests`

Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/LyricXCore/Display/FloatingLyricsPresentation.swift Sources/LyricX/App/AppModel.swift Sources/LyricX/Floating/FloatingLyricsView.swift Sources/LyricXUnitTests/main.swift
git commit -m "refactor: generalize lyric overlay presentation"
```

---

### Task 6: Expose Island Lyrics State from AppModel

**Files:**
- Modify: `Sources/LyricX/App/AppModel.swift`

**Step 1: Add computed bindings**

Add properties:

```swift
var showsIslandLyrics: Bool {
    get { settings.showsIslandLyrics }
    set {
        settings.showsIslandLyrics = newValue
        persistSettings()
    }
}

var islandLyricsAutoExpandOnHover: Bool {
    get { settings.islandLyricsAutoExpandOnHover }
    set {
        settings.islandLyricsAutoExpandOnHover = newValue
        persistSettings()
    }
}

var islandLyricsClickThrough: Bool {
    get { settings.islandLyricsClickThrough }
    set {
        settings.islandLyricsClickThrough = newValue
        persistSettings()
    }
}

var islandLyricsKTVEnabled: Bool {
    get { settings.islandLyricsKTVEnabled }
    set {
        settings.islandLyricsKTVEnabled = newValue
        persistSettings()
    }
}

var islandLyricsBackgroundOpacity: Double {
    get { settings.islandLyricsBackgroundOpacity }
    set {
        settings.islandLyricsBackgroundOpacity = min(max(newValue, 0), 1)
        persistSettings()
    }
}
```

**Step 2: Add island presentation method**

Add:

```swift
func islandLyricsPresentation(at date: Date = Date()) -> LyricOverlayPresentation {
    LyricOverlayPresentation.make(
        timeline: timeline,
        playbackPosition: estimatedPlaybackPosition(at: date),
        statusText: lyricsStatus,
        trackText: playback.track.map { "\($0.title) - \($0.artist)" },
        showsTrackWhenLyricsMissing: showsTrackWhenLyricsMissing,
        settings: settings,
        ktvEnabled: settings.islandLyricsKTVEnabled,
        backgroundOpacity: settings.islandLyricsBackgroundOpacity
    )
}
```

**Step 3: Run build**

Run: `swift build`

Expected: PASS.

**Step 4: Commit**

```bash
git add Sources/LyricX/App/AppModel.swift
git commit -m "feat: expose island lyric app state"
```

---

### Task 7: Split Settings and Menu Controls

**Files:**
- Modify: `Sources/LyricX/Settings/SettingsView.swift`
- Modify: `Sources/LyricX/Menu/MenuBarContentView.swift`

**Step 1: Update Settings sections**

Keep the existing `Floating Lyrics` section but add clearer grouping and keep all existing controls.

Add a new section after Floating Lyrics:

```swift
Section("Island Lyrics") {
    Toggle("Show Island Lyrics", isOn: $model.showsIslandLyrics)
    Toggle("Auto Expand on Hover", isOn: $model.islandLyricsAutoExpandOnHover)
    Toggle("Click Through", isOn: $model.islandLyricsClickThrough)
    Toggle("KTV Mode", isOn: $model.islandLyricsKTVEnabled)

    HStack(spacing: 12) {
        Text("Background Opacity")
            .frame(width: 150, alignment: .leading)

        Slider(value: $model.islandLyricsBackgroundOpacity, in: 0...1, step: 0.05)

        Text("\(Int(model.islandLyricsBackgroundOpacity * 100))%")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 42, alignment: .trailing)
    }
}
```

Increase the form frame min height if controls feel clipped:

```swift
.frame(minWidth: 560, idealWidth: 620, minHeight: 620, idealHeight: 680)
```

**Step 2: Update menu-bar quick toggles**

In `MenuBarContentView.utilityMenu`, after `Floating Lyrics`, add:

```swift
Toggle(isOn: boolBinding(\.showsIslandLyrics)) {
    Label("Island Lyrics", systemImage: "capsule")
}
```

After floating click-through, add:

```swift
Toggle(isOn: boolBinding(\.islandLyricsClickThrough)) {
    Label("Island Click Through", systemImage: "cursorarrow.rays")
}
```

Keep KTV toggles distinct:

```swift
Toggle(isOn: boolBinding(\.floatingLyricsKTVEnabled)) {
    Label("Floating KTV Mode", systemImage: "textformat")
}

Toggle(isOn: boolBinding(\.islandLyricsKTVEnabled)) {
    Label("Island KTV Mode", systemImage: "textformat.alt")
}
```

**Step 3: Run build**

Run: `swift build`

Expected: PASS.

**Step 4: Commit**

```bash
git add Sources/LyricX/Settings/SettingsView.swift Sources/LyricX/Menu/MenuBarContentView.swift
git commit -m "feat: split floating and island lyric controls"
```

---

### Task 8: Repair Floating Lyrics UI

**Files:**
- Modify: `Sources/LyricX/Floating/FloatingLyricsView.swift`
- Modify: `Sources/LyricX/Floating/FloatingLyricsController.swift`

**Step 1: Change view API**

Update `FloatingLyricsView` to accept a close action:

```swift
struct FloatingLyricsView: View {
    let presentation: LyricOverlayPresentation
    let onClose: () -> Void
```

**Step 2: Add a quiet header row**

Add a top trailing close button in the view:

```swift
HStack {
    Spacer()
    Button(action: onClose) {
        Image(systemName: "xmark.circle.fill")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white.opacity(0.62))
    }
    .buttonStyle(.plain)
    .help("Hide Floating Lyrics")
}
```

Keep it inside the panel so users can close without opening Settings.

**Step 3: Reduce visual weight**

Replace the current black capsule with a rounded panel:

```swift
.background(.ultraThinMaterial)
.background(Color.black.opacity(presentation.backgroundOpacity * 0.55))
.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
.overlay(
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(Color.white.opacity(0.12), lineWidth: 1)
)
```

Use `.frame(minWidth: 360, idealWidth: 640, minHeight: 92, idealHeight: 132)` instead of hard fixed size.

**Step 4: Update controller hosting**

Where the controller creates or updates `FloatingLyricsView`, pass:

```swift
onClose: { [weak model] in
    model?.showsFloatingLyrics = false
}
```

If weak capture does not compile for `@Observable @MainActor`, use:

```swift
onClose: { self.model.showsFloatingLyrics = false }
```

inside `@MainActor` controller methods.

**Step 5: Run build**

Run: `swift build`

Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/LyricX/Floating/FloatingLyricsView.swift Sources/LyricX/Floating/FloatingLyricsController.swift
git commit -m "fix: make floating lyrics closable and quieter"
```

---

### Task 9: Make Floating Lyrics Resizable

**Files:**
- Modify: `Sources/LyricX/Floating/FloatingLyricsController.swift`

**Step 1: Update panel style mask**

In `makePanel(date:)`, change:

```swift
styleMask: [.borderless, .nonactivatingPanel],
```

to:

```swift
styleMask: [.borderless, .nonactivatingPanel, .resizable],
```

**Step 2: Set size limits**

After panel creation, add:

```swift
panel.minSize = NSSize(width: 360, height: 92)
panel.maxSize = NSSize(width: 980, height: 260)
```

**Step 3: Preserve existing frame persistence**

Do not remove `windowDidResize` or `persistPanelFrameIfNeeded`.

**Step 4: Run build**

Run: `swift build`

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/LyricX/Floating/FloatingLyricsController.swift
git commit -m "fix: allow resizing floating lyrics"
```

---

### Task 10: Build Island Lyrics SwiftUI View

**Files:**
- Create: `Sources/LyricX/Island/IslandLyricsView.swift`

**Step 1: Create folder and view**

Create `Sources/LyricX/Island/IslandLyricsView.swift`:

```swift
import LyricXCore
import SwiftUI

struct IslandLyricsView: View {
    let presentation: LyricOverlayPresentation
    let isExpanded: Bool
    let onClose: () -> Void
    let onToggleClickThrough: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        Group {
            if isExpanded {
                expandedBody
            } else {
                collapsedBody
            }
        }
        .padding(.horizontal, isExpanded ? 18 : 14)
        .padding(.vertical, isExpanded ? 12 : 7)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(presentation.backgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 24 : 19, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isExpanded ? 24 : 19, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 8)
        .animation(.snappy(duration: 0.22), value: isExpanded)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(presentation.currentText)
    }

    private var collapsedBody: some View {
        Text(presentation.currentText)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("LyricX")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))

                Spacer()

                islandButton("cursorarrow.rays", action: onToggleClickThrough, help: "Toggle Click Through")
                islandButton("gearshape", action: onOpenSettings, help: "Open Settings")
                islandButton("xmark", action: onClose, help: "Hide Island Lyrics")
            }

            if presentation.usesKTV {
                ktvLine
            } else {
                Text(presentation.currentText)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            if let nextText = presentation.nextText {
                Text(nextText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private var ktvLine: some View {
        HStack(spacing: 0) {
            ForEach(Array(presentation.segments.enumerated()), id: \.offset) { _, segment in
                Text(segment.text)
                    .foregroundStyle(segment.isHighlighted ? Color.white : Color.white.opacity(0.35))
            }
        }
        .font(.system(size: 22, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.65)
    }

    private func islandButton(_ systemName: String, action: @escaping () -> Void, help: String) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.72))
        .help(help)
    }
}
```

**Step 2: Run build**

Run: `swift build`

Expected: PASS.

**Step 3: Commit**

```bash
git add Sources/LyricX/Island/IslandLyricsView.swift
git commit -m "feat: add island lyrics view"
```

---

### Task 11: Add Island Lyrics Controller

**Files:**
- Create: `Sources/LyricX/Island/IslandLyricsController.swift`
- Modify: `Sources/LyricX/App/AppContainer.swift`
- Modify if needed: `Sources/LyricX/App/MainWindowController.swift`

**Step 1: Create controller skeleton**

Create `IslandLyricsController.swift`:

```swift
import AppKit
import LyricXCore
import SwiftUI

@MainActor
final class IslandLyricsController: NSObject {
    private let model: AppModel
    private let openSettings: () -> Void
    private var panel: NSPanel?
    private var hostingController: NSHostingController<IslandLyricsView>?
    private var timer: Timer?
    private var lastFrameRate: MenuBarAnimationFrameRate?
    private var isExpanded = false

    init(model: AppModel, openSettings: @escaping () -> Void) {
        self.model = model
        self.openSettings = openSettings
        super.init()
        restartTimer()
    }
}
```

**Step 2: Add timer**

Add `restartTimer()` and `tick(date:)` similar to `FloatingLyricsController`.

In `tick(date:)`:

```swift
if model.menuBarFrameRate != lastFrameRate {
    restartTimer()
}

guard model.showsIslandLyrics else {
    panel?.orderOut(nil)
    return
}

showOrUpdatePanel(date: date)
```

**Step 3: Add panel creation**

Use:

```swift
let panel = NSPanel(
    contentRect: islandFrame(state: .collapsed, preferredContentWidth: 260),
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)
panel.title = "LyricX Island Lyrics"
panel.level = .floating
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
panel.isOpaque = false
panel.backgroundColor = .clear
panel.hasShadow = false
panel.hidesOnDeactivate = false
panel.isReleasedWhenClosed = false
panel.ignoresMouseEvents = model.islandLyricsClickThrough
```

**Step 4: Add frame helper**

Add:

```swift
private func islandFrame(state: IslandLyricsDisplayState, preferredContentWidth: Double) -> NSRect {
    let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let frame = IslandLyricsLayout.frame(
        in: OverlayScreenFrame(
            x: visibleFrame.origin.x,
            y: visibleFrame.origin.y,
            width: visibleFrame.width,
            height: visibleFrame.height
        ),
        state: state,
        preferredContentWidth: preferredContentWidth,
        topInset: 8
    )
    return NSRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height)
}
```

**Step 5: Add view factory**

Add:

```swift
private func makeView(date: Date) -> IslandLyricsView {
    IslandLyricsView(
        presentation: model.islandLyricsPresentation(at: date),
        isExpanded: isExpanded,
        onClose: { [weak self] in self?.model.showsIslandLyrics = false },
        onToggleClickThrough: { [weak self] in
            guard let self else { return }
            self.model.islandLyricsClickThrough.toggle()
        },
        onOpenSettings: { [weak self] in self?.openSettings() }
    )
}
```

If weak `self` capture warns under `@MainActor`, rewrite closures without weak capture inside `@MainActor` methods.

**Step 6: Add hover tracking**

Set `panel.contentView` to an `NSHostingView` managed by `NSHostingController` and add a tracking area to the panel content view if straightforward. Simpler first pass is acceptable:

- Click on the island toggles expanded.
- Hover expansion can be added in Task 12 if needed.

For first pass, add a transparent click gesture to `IslandLyricsView` by adding `onToggleExpanded` to the view API if needed.

**Step 7: Wire `AppContainer`**

Add:

```swift
let islandLyricsController: IslandLyricsController
```

Initialize after `mainWindowController`:

```swift
self.islandLyricsController = IslandLyricsController(model: model) {
    mainWindowController.showWindow()
}
```

**Step 8: Run build**

Run: `swift build`

Expected: PASS.

**Step 9: Commit**

```bash
git add Sources/LyricX/Island/IslandLyricsController.swift Sources/LyricX/App/AppContainer.swift Sources/LyricX/App/MainWindowController.swift
git commit -m "feat: add island lyrics panel"
```

---

### Task 12: Add Island Expand/Collapse Interaction

**Files:**
- Modify: `Sources/LyricX/Island/IslandLyricsView.swift`
- Modify: `Sources/LyricX/Island/IslandLyricsController.swift`

**Step 1: Add toggle action to view**

Add to `IslandLyricsView`:

```swift
let onToggleExpanded: () -> Void
```

Apply to the root:

```swift
.contentShape(Rectangle())
.onTapGesture(perform: onToggleExpanded)
```

**Step 2: Update controller view factory**

Pass:

```swift
onToggleExpanded: { [weak self] in
    self?.isExpanded.toggle()
    self?.updatePanelFrame()
}
```

**Step 3: Add frame update**

Add:

```swift
private func updatePanelFrame() {
    guard let panel else { return }
    let state: IslandLyricsDisplayState = isExpanded ? .expanded : .collapsed
    panel.setFrame(islandFrame(state: state, preferredContentWidth: isExpanded ? 620 : 280), display: true, animate: true)
}
```

Call it when `isExpanded` changes and on each render.

**Step 4: Add hover expansion only if low-risk**

If implementing hover with AppKit tracking is small, add it. If not, keep click-to-expand and leave hover for follow-up. Do not destabilize the panel for hover.

**Step 5: Run build**

Run: `swift build`

Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/LyricX/Island/IslandLyricsView.swift Sources/LyricX/Island/IslandLyricsController.swift
git commit -m "feat: add island lyrics expansion"
```

---

### Task 13: Update README and Final Verification

**Files:**
- Modify: `README.md`

**Step 1: Update README**

Document both overlay modes:

- Floating Lyrics: movable/resizable desktop panel.
- Island Lyrics: top-center Dynamic Island-style compact lyric surface.
- KTV still requires source-provided timed segments.

**Step 2: Run unit tests**

Run: `swift run LyricXUnitTests`

Expected: `LyricXUnitTests passed`.

**Step 3: Run package build**

Run: `swift build`

Expected: exit 0.

**Step 4: Build app bundle**

Run: `bash scripts/build-app.sh`

Expected: `Built /Users/ns2kracy/Coding/LyricX/dist/LyricX.app`.

**Step 5: Brief runtime launch check**

Run:

```bash
/bin/zsh -lc 'swift run LyricX & apppid=$!; sleep 8; kill "$apppid"; wait "$apppid"; rc=$?; if [ "$rc" -eq 143 ]; then exit 0; else exit "$rc"; fi'
```

Expected: exit 0 with no crash output before termination.

**Step 6: Commit docs**

```bash
git add README.md
git commit -m "docs: document island and floating lyrics"
```

**Step 7: Final status check**

Run: `git status --short`

Expected: clean working tree.
