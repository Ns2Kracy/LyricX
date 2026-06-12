# Spotify Menu Bar Lyrics Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a SwiftUI macOS menu-bar app that displays Spotify synced lyrics in a floating desktop overlay.

**Architecture:** A Swift Package contains one core library target, one executable app target, and one executable unit-test runner target. Pure lyric parsing/timeline code is unit-tested first, while macOS integration code stays thin: AppleScript polling for Spotify, LRCLIB lookup/cache for synced lyrics, SwiftUI `MenuBarExtra` for controls, and an AppKit `NSPanel` hosting SwiftUI for the floating overlay.

**Tech Stack:** Swift 6.2, SwiftUI, Observation, AppKit, Foundation networking, Swift Package Manager, macOS 26 SDK. This Command Line Tools environment does not expose Swift Testing or XCTest, so verification uses a lightweight executable unit-test target: `swift run LyricXUnitTests`.

---

### Task 1: Package Scaffold

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/LyricXCore/LyricXCore.swift`
- Create: `Sources/LyricX/App/LyricXApp.swift`
- Create: `Sources/LyricX/Resources/Info.plist`
- Create: `Sources/LyricXUnitTests/main.swift`

**Step 1: Create the package manifest**

Add a library product named `LyricXCore`, an executable product named `LyricX`, and an executable product named `LyricXUnitTests`.

**Step 2: Add a minimal SwiftUI app**

Create `LyricXApp` with a `MenuBarExtra("LyricX", systemImage: "music.note")` containing a `Text("LyricX")` placeholder and `Button("Quit") { NSApplication.shared.terminate(nil) }`.

**Step 3: Add the first failing test placeholder**

Create `LyricXUnitTests` with a test referencing `LRCParser.parse`, which does not exist yet.

**Step 4: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL because `LRCParser` is not defined.

**Step 5: Commit**

Run: `git add Package.swift .gitignore Sources docs/plans && git commit -m "chore: scaffold LyricX package"`

---

### Task 2: Lyric Parsing and Timeline

**Files:**
- Create: `Sources/LyricXCore/Lyrics/LyricLine.swift`
- Create: `Sources/LyricXCore/Lyrics/LRCParser.swift`
- Create: `Sources/LyricXCore/Lyrics/LyricTimeline.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

**Step 1: Write parser tests**

Cover single timestamp lines, multiple timestamp tags on one line, centisecond parsing, metadata tags, blank lines, and sorted output.

**Step 2: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL because parser implementation is missing or incomplete.

**Step 3: Implement parser and model**

Implement `LyricLine` as `Identifiable`, `Equatable`, `Sendable`; implement `LRCParser.parse(_:)`; implement `LyricTimeline.currentLine(at:)` and `nextLine(after:)`.

**Step 4: Add timeline tests**

Cover times before the first line, exactly on a line, between lines, and after the final line.

**Step 5: Run tests**

Run: `swift run LyricXUnitTests`

Expected: PASS.

**Step 6: Commit**

Run: `git add Sources/LyricXCore Sources/LyricXUnitTests && git commit -m "feat: parse synced lyric timelines"`

---

### Task 3: Playback and Lyrics Services

**Files:**
- Create: `Sources/LyricXCore/Playback/PlaybackSnapshot.swift`
- Create: `Sources/LyricXCore/Playback/SpotifyPlaybackService.swift`
- Create: `Sources/LyricXCore/Lyrics/LyricsRepository.swift`
- Create: `Sources/LyricXCore/Lyrics/LRCLIBClient.swift`
- Create: `Sources/LyricXCore/Lyrics/LyricsCache.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

**Step 1: Write LRCLIB URL test**

Verify the search URL contains encoded `track_name`, `artist_name`, optional `album_name`, and optional `duration` query items.

**Step 2: Run test to verify it fails**

Run: `swift run LyricXUnitTests`

Expected: FAIL because `LRCLIBClient` is not defined.

**Step 3: Implement playback snapshot and Spotify service**

Use `/usr/bin/osascript` through `Process` to query Spotify for player state, track name, artist, album, duration, and player position. Return a typed snapshot or a waiting/error state.

**Step 4: Implement LRCLIB client, repository, and cache**

Use `URLSession` for lookup, decode LRCLIB responses, parse synced lyrics, and cache raw LRC text under Application Support.

**Step 5: Run tests**

Run: `swift run LyricXUnitTests`

Expected: PASS.

**Step 6: Commit**

Run: `git add Sources/LyricXCore Sources/LyricXUnitTests && git commit -m "feat: add spotify playback and lyrics services"`

---

### Task 4: App Model and Menu Bar UI

**Files:**
- Create: `Sources/LyricX/App/AppModel.swift`
- Create: `Sources/LyricX/App/AppSettings.swift`
- Create: `Sources/LyricX/Menu/MenuBarContentView.swift`
- Modify: `Sources/LyricX/App/LyricXApp.swift`

**Step 1: Implement observable app state**

Create `@Observable @MainActor final class AppModel` that owns playback service, lyric repository, current playback snapshot, current timeline, current/next lyric lines, visibility, lock, click-through, and polling task lifecycle.

**Step 2: Implement menu content**

Create a compact SwiftUI menu with status text, current track, show/hide lyrics toggle, lock toggle, click-through toggle, refresh lyrics, and quit.

**Step 3: Wire app entry**

Instantiate the model with `@State`, start polling in the menu view task, and use native `MenuBarExtra`.

**Step 4: Run build and tests**

Run: `swift run LyricXUnitTests`

Expected: PASS.

**Step 5: Commit**

Run: `git add Sources/LyricX/App Sources/LyricX/Menu && git commit -m "feat: add menu bar app state"`

---

### Task 5: Floating Lyrics Panel

**Files:**
- Create: `Sources/LyricX/Floating/FloatingLyricsController.swift`
- Create: `Sources/LyricX/Floating/FloatingLyricsPanel.swift`
- Create: `Sources/LyricX/Floating/FloatingLyricsView.swift`
- Modify: `Sources/LyricX/App/LyricXApp.swift`

**Step 1: Implement panel controller**

Create an `NSPanel` wrapper that is borderless, non-activating, floating, draggable by background, translucent, and hidden from the app switcher where appropriate.

**Step 2: Implement SwiftUI overlay view**

Show current line, next line, track metadata, and waiting/error states. Keep dimensions stable and use accessible contrast.

**Step 3: Wire visibility and behavior**

Have the controller react to app model state for visible/hidden, locked/unlocked, and click-through behavior.

**Step 4: Run build and tests**

Run: `swift run LyricXUnitTests`

Expected: PASS.

**Step 5: Commit**

Run: `git add Sources/LyricX/Floating Sources/LyricX/App && git commit -m "feat: add floating lyric overlay"`

---

### Task 6: App Bundle Script and Final Verification

**Files:**
- Create: `scripts/build-app.sh`
- Create: `README.md`

**Step 1: Create bundle script**

Build release binary with `swift build -c release`, create `dist/LyricX.app`, copy executable into `Contents/MacOS`, copy `Info.plist`, and write a `PkgInfo` file.

**Step 2: Document usage**

Explain build, run, Spotify requirement, LRCLIB lookup, and macOS automation permission prompt.

**Step 3: Run verification**

Run: `swift run LyricXUnitTests`

Run: `swift build`

Run: `bash scripts/build-app.sh`

Expected: all exit 0 and `dist/LyricX.app` exists.

**Step 4: Commit**

Run: `git add scripts README.md Sources Package.swift && git commit -m "chore: package LyricX app bundle"`
