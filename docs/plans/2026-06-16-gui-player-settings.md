# GUI Player Settings Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a full LyricX GUI with Spotify playback controls, artwork, lyric preview, style presets, and GitHub Release update checks while keeping the menu-bar lyric behavior stable.

**Architecture:** Introduce protocol boundaries in `LyricXCore` first, then refactor the app layer to consume those boundaries. Keep Spotify as the only concrete player in phase one, keep updates manual through GitHub Releases, and keep floating lyrics disabled as a future entry.

**Tech Stack:** Swift 6.2, SwiftUI, Observation, Swift Package Manager, AppleScript through `/usr/bin/osascript`, Foundation networking, executable test runner `swift run LyricXUnitTests`.

---

## Implementation Rules

- Use @superpowers:test-driven-development for each behavioral task.
- Use @superpowers:verification-before-completion before completion claims or commits.
- Keep commits small. Each task below should be one commit unless a task explicitly says otherwise.
- Do not add Apple Music, NetEase Cloud Music, QQ Music, browser players, Sparkle, or floating lyric behavior in this phase.
- Keep `dist/` uncommitted.

## Task 1: Add Player Protocols and Command Model

**Files:**
- Create: `Sources/LyricXCore/Playback/PlayerService.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

**Step 1: Write failing tests for command script generation**

Add tests to `Sources/LyricXUnitTests/main.swift`:

```swift
try testSpotifyControlScriptForPlayPause()
try testSpotifyControlScriptForNextTrack()
try testSpotifyControlScriptForPreviousTrack()
```

Test bodies:

```swift
private static func testSpotifyControlScriptForPlayPause() throws {
    try expectEqual(SpotifyPlayerCommand.playPause.appleScript, "tell application \"Spotify\" to playpause")
}

private static func testSpotifyControlScriptForNextTrack() throws {
    try expectEqual(SpotifyPlayerCommand.nextTrack.appleScript, "tell application \"Spotify\" to next track")
}

private static func testSpotifyControlScriptForPreviousTrack() throws {
    try expectEqual(SpotifyPlayerCommand.previousTrack.appleScript, "tell application \"Spotify\" to previous track")
}
```

**Step 2: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL because `SpotifyPlayerCommand` does not exist.

**Step 3: Add protocol and command model**

Create `Sources/LyricXCore/Playback/PlayerService.swift`:

```swift
import Foundation

public protocol PlayerService: Sendable {
    func currentSnapshot() -> PlaybackSnapshot
    func playPause()
    func nextTrack()
    func previousTrack()
}

public enum SpotifyPlayerCommand: Equatable, Sendable {
    case playPause
    case nextTrack
    case previousTrack

    public var appleScript: String {
        switch self {
        case .playPause:
            return "tell application \"Spotify\" to playpause"
        case .nextTrack:
            return "tell application \"Spotify\" to next track"
        case .previousTrack:
            return "tell application \"Spotify\" to previous track"
        }
    }
}
```

**Step 4: Run tests**

Run: `swift run LyricXUnitTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/LyricXCore/Playback/PlayerService.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: add player service command boundary"
```

## Task 2: Refactor Spotify Service Behind PlayerService

**Files:**
- Modify: `Sources/LyricXCore/Playback/SpotifyPlaybackService.swift`
- Modify: `Sources/LyricX/App/AppModel.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

**Step 1: Write failing tests for command execution injection**

Make the Spotify service accept a script runner closure so command behavior can be tested without running `osascript`.

Add a test like:

```swift
private static func testSpotifyServiceRunsControlCommand() throws {
    var scripts: [String] = []
    let service = SpotifyPlaybackService(runScript: { script in
        scripts.append(script)
        return ""
    })

    service.nextTrack()

    try expectEqual(scripts, [SpotifyPlayerCommand.nextTrack.appleScript])
}
```

**Step 2: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL because `SpotifyPlaybackService` has no injectable runner and no player control methods.

**Step 3: Implement minimal refactor**

In `SpotifyPlaybackService`, add:

```swift
private let runScript: @Sendable (String) throws -> String

public init(runScript: @escaping @Sendable (String) throws -> String = Self.defaultRunAppleScript) {
    self.runScript = runScript
}
```

Move the current process-running logic into:

```swift
private static func defaultRunAppleScript(_ script: String) throws -> String { ... }
```

Then conform to `PlayerService`:

```swift
extension SpotifyPlaybackService: PlayerService {
    public func playPause() { runCommand(.playPause) }
    public func nextTrack() { runCommand(.nextTrack) }
    public func previousTrack() { runCommand(.previousTrack) }

    private func runCommand(_ command: SpotifyPlayerCommand) {
        _ = try? runScript(command.appleScript)
    }
}
```

**Step 4: Update AppModel dependency type**

Change `AppModel` to store a `SpotifyPlaybackService` only if protocol existential sendability causes friction. Prefer `any PlayerService` only if Swift 6.2 accepts it cleanly in this codebase. Keep the change minimal.

**Step 5: Run tests and build**

Run:

```bash
swift run LyricXUnitTests
swift build
```

Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/LyricXCore/Playback/SpotifyPlaybackService.swift Sources/LyricX/App/AppModel.swift Sources/LyricXUnitTests/main.swift
git commit -m "refactor: route Spotify through player service"
```

## Task 3: Add Artwork Model and Placeholder Path

**Files:**
- Create: `Sources/LyricXCore/Artwork/TrackArtwork.swift`
- Modify: `Sources/LyricXCore/Playback/SpotifyPlaybackService.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

**Step 1: Write failing tests for artwork model**

Add:

```swift
private static func testTrackArtworkStoresPNGData() throws {
    let data = Data([0x89, 0x50, 0x4E, 0x47])
    let artwork = TrackArtwork(data: data, mimeType: "image/png")

    try expectEqual(artwork.data, data)
    try expectEqual(artwork.mimeType, "image/png")
}
```

**Step 2: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL because `TrackArtwork` does not exist.

**Step 3: Add artwork types**

Create:

```swift
import Foundation

public struct TrackArtwork: Equatable, Sendable {
    public let data: Data
    public let mimeType: String

    public init(data: Data, mimeType: String) {
        self.data = data
        self.mimeType = mimeType
    }
}

public protocol ArtworkProvider: Sendable {
    func artwork(for track: PlaybackTrack) async -> TrackArtwork?
}
```

**Step 4: Add Spotify placeholder conformance**

For phase one, `SpotifyPlaybackService.artwork(for:)` may return `nil`. The GUI will use a placeholder.

**Step 5: Run tests**

Run: `swift run LyricXUnitTests`

Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/LyricXCore/Artwork/TrackArtwork.swift Sources/LyricXCore/Playback/SpotifyPlaybackService.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: add track artwork boundary"
```

## Task 4: Add Lyric Style Preset Model and Defaults

**Files:**
- Create: `Sources/LyricXCore/Styles/LyricStylePreset.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

**Step 1: Write failing tests for defaults and Codable**

Add tests:

```swift
private static func testDefaultStylePresetsIncludeMenuBarCompact() throws {
    let presets = LyricStylePreset.defaults
    try expectEqual(presets.first?.name, "Menu Bar Compact")
}

private static func testStylePresetCodableRoundTrip() throws {
    let preset = LyricStylePreset.defaults[0]
    let data = try JSONEncoder().encode(preset)
    let decoded = try JSONDecoder().decode(LyricStylePreset.self, from: data)
    try expectEqual(decoded, preset)
}
```

**Step 2: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL because preset model does not exist.

**Step 3: Add model**

Create `LyricStylePreset.swift` with:

```swift
import Foundation

public enum LyricAlignment: String, Codable, Equatable, Sendable {
    case leading
    case center
    case trailing
}

public struct LyricStylePreset: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var menuBarWidth: Double
    public var fontSize: Double
    public var fontWeight: String
    public var textColorHex: String
    public var alignment: LyricAlignment
    public var showsTrackWhenLyricsMissing: Bool
}

public extension LyricStylePreset {
    static let defaults: [LyricStylePreset] = [
        LyricStylePreset(id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!, name: "Menu Bar Compact", menuBarWidth: 220, fontSize: 13, fontWeight: "medium", textColorHex: "#FFFFFF", alignment: .leading, showsTrackWhenLyricsMissing: true),
        LyricStylePreset(id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!, name: "Menu Bar Wide", menuBarWidth: 320, fontSize: 13, fontWeight: "medium", textColorHex: "#FFFFFF", alignment: .leading, showsTrackWhenLyricsMissing: true),
        LyricStylePreset(id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!, name: "Window Preview", menuBarWidth: 260, fontSize: 18, fontWeight: "semibold", textColorHex: "#FFFFFF", alignment: .center, showsTrackWhenLyricsMissing: true)
    ]
}
```

**Step 4: Run tests**

Run: `swift run LyricXUnitTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/LyricXCore/Styles/LyricStylePreset.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: add lyric style presets"
```

## Task 5: Add Preset Store

**Files:**
- Create: `Sources/LyricXCore/Styles/LyricStylePresetStore.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

**Step 1: Write failing test for load/save**

Use a temporary URL in the executable tests:

```swift
private static func testStylePresetStoreSavesAndLoadsSelection() throws {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    let store = LyricStylePresetStore(fileURL: url)
    let preset = LyricStylePreset.defaults[1]

    try store.save(presets: LyricStylePreset.defaults, activePresetID: preset.id)
    let loaded = try store.load()

    try expectEqual(loaded.activePresetID, preset.id)
    try expectEqual(loaded.presets, LyricStylePreset.defaults)
}
```

**Step 2: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL because store does not exist.

**Step 3: Implement store**

Add a small JSON store with:

```swift
public struct LyricStylePresetState: Codable, Equatable, Sendable {
    public var presets: [LyricStylePreset]
    public var activePresetID: UUID
}
```

`LyricStylePresetStore.load()` should return defaults when the file does not exist.

**Step 4: Run tests**

Run: `swift run LyricXUnitTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/LyricXCore/Styles/LyricStylePresetStore.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: persist lyric style presets"
```

## Task 6: Add GitHub Release Update Service

**Files:**
- Create: `Sources/LyricXCore/Updates/AppUpdate.swift`
- Create: `Sources/LyricXCore/Updates/GitHubReleaseUpdateService.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

**Step 1: Write failing tests for version comparison**

Add:

```swift
private static func testAppVersionComparisonFindsNewerPatch() throws {
    try expectEqual(AppVersion("0.1.2") > AppVersion("0.1.1"), true)
}

private static func testAppVersionIgnoresLeadingV() throws {
    try expectEqual(AppVersion("v0.1.2"), AppVersion("0.1.2"))
}
```

**Step 2: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL because update types do not exist.

**Step 3: Implement update models**

Add:

```swift
public struct AppVersion: Comparable, Codable, Sendable { ... }
public struct AppUpdate: Equatable, Sendable { ... }
public protocol UpdateService: Sendable { func latestVersion() async throws -> AppUpdate? }
```

Keep `AppVersion` small: parse dot-separated integers after trimming a leading `v`.

**Step 4: Add GitHub response decoder tests**

Add a test for a minimal JSON payload containing `tag_name`, `html_url`, and assets.

**Step 5: Implement GitHub service**

`GitHubReleaseUpdateService` should use `URLSession.shared.data(from:)` in production. For tests, expose a decoder or initializer that accepts fetched data.

**Step 6: Run tests**

Run: `swift run LyricXUnitTests`

Expected: PASS.

**Step 7: Commit**

```bash
git add Sources/LyricXCore/Updates Sources/LyricXUnitTests/main.swift
git commit -m "feat: add GitHub release update check"
```

## Task 7: Extend AppModel With Commands and GUI State

**Files:**
- Modify: `Sources/LyricX/App/AppModel.swift`
- Modify: `Sources/LyricX/App/AppSettings.swift`
- Modify: `Sources/LyricXUnitTests/main.swift` if new pure helper logic is added

**Step 1: Add UI state fields**

Add app-facing state:

```swift
var stylePresets: [LyricStylePreset]
var activeStylePresetID: UUID
var latestUpdate: AppUpdate?
var updateStatus: String
var isMainWindowRequested: Bool
```

**Step 2: Add commands**

Add methods:

```swift
func playPause()
func nextTrack()
func previousTrack()
func checkForUpdates()
func selectPreset(_ preset: LyricStylePreset)
```

**Step 3: Keep current menu-bar behavior**

Menu-bar display should still use `MenuBarMarquee` and the active preset width when wired in a later task.

**Step 4: Run build and tests**

Run:

```bash
swift run LyricXUnitTests
swift build
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/LyricX/App/AppModel.swift Sources/LyricX/App/AppSettings.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: add GUI state to app model"
```

## Task 8: Add Main Window Scene and View

**Files:**
- Modify: `Sources/LyricX/App/LyricXApp.swift`
- Create: `Sources/LyricX/Window/MainWindowView.swift`
- Create: `Sources/LyricX/Window/ArtworkView.swift`

**Step 1: Add a WindowGroup**

In `LyricXApp`, add a normal app window scene next to `MenuBarExtra`:

```swift
WindowGroup("LyricX") {
    MainWindowView(model: container.model)
}
```

Keep `LSUIElement` as-is for now unless the window cannot be summoned. If macOS prevents expected window behavior with `LSUIElement`, document that finding and make the smallest Info.plist adjustment in a separate commit.

**Step 2: Build a functional main window**

Create `MainWindowView` with:

- Artwork or placeholder.
- Track title and artist.
- Playback status.
- Current lyric, previous lyric, next lyric.
- Previous, play/pause, next, refresh buttons.
- Active preset name.
- Update status line.

Use SF Symbols for playback controls.

**Step 3: Run build**

Run: `swift build`

Expected: PASS.

**Step 4: Build app bundle and smoke test**

Run:

```bash
bash scripts/build-app.sh
open dist/LyricX.app
```

Expected: app opens, menu-bar item remains visible, main window can be opened by app launch or menu action.

**Step 5: Commit**

```bash
git add Sources/LyricX/App/LyricXApp.swift Sources/LyricX/Window
git commit -m "feat: add LyricX main window"
```

## Task 9: Add Settings View With Presets and Update Entry

**Files:**
- Modify: `Sources/LyricX/Menu/MenuBarContentView.swift`
- Create: `Sources/LyricX/Settings/SettingsView.swift`
- Create: `Sources/LyricX/Settings/PresetEditorView.swift`

**Step 1: Add settings entry points**

Menu-bar menu should include:

- Open LyricX.
- Settings.
- Refresh lyrics.
- Playback controls.
- Quit.

**Step 2: Add settings view**

`SettingsView` should include:

- Preset picker.
- Basic preset fields: name, menu-bar width, font size, text color hex, alignment, show track when missing.
- Player section: Spotify selected, other players disabled.
- Updates section: check button and open release page if available.
- Floating lyrics section: disabled, "Coming later".

**Step 3: Run build**

Run: `swift build`

Expected: PASS.

**Step 4: Smoke test app**

Run:

```bash
bash scripts/build-app.sh
open dist/LyricX.app
```

Expected: settings can open, preset picker displays defaults, disabled future rows are visibly disabled.

**Step 5: Commit**

```bash
git add Sources/LyricX/Menu/MenuBarContentView.swift Sources/LyricX/Settings
git commit -m "feat: add settings UI for presets and updates"
```

## Task 10: Final Verification and Release Preparation

**Files:**
- Modify: `README.md` if usage changes need documentation.

**Step 1: Run full local gate**

Run:

```bash
swift run LyricXUnitTests
swift build
bash scripts/build-app.sh
bash scripts/package-release.sh
```

Expected: all commands exit 0.

**Step 2: Smoke test running app**

Run:

```bash
killall LyricX || true
open dist/LyricX.app
```

Expected:

- Menu-bar item appears.
- Main window opens or can be opened from the menu.
- Spotify controls do not crash when Spotify is unavailable.
- Memory does not show rapid growth over a 30 second RSS sample.

**Step 3: Update README**

Document:

- Main window.
- Settings and presets.
- Spotify-only phase-one scope.
- GitHub Release update check.

**Step 4: Final commit**

```bash
git add README.md
git commit -m "docs: update GUI usage notes"
```

**Step 5: Push**

```bash
git push origin main
```

Expected: GitHub CI succeeds.

**Step 6: Release tag if requested**

Only after user approval:

```bash
git tag v0.1.2
git push origin v0.1.2
```

Expected: Release workflow creates `LyricX.zip` and `LyricX.zip.sha256`.

## Notes For Executors

- The menu-bar memory leak was caused by high-frequency SwiftUI layout work inside `MenuBarExtra` label. Do not reintroduce `TimelineView` or `GeometryReader` there.
- Keep menu-bar text fixed-width and model-driven.
- Prefer pure `LyricXCore` tests before touching SwiftUI.
- Avoid changing app signing, notarization, or release workflow in this feature unless a build failure requires it.
