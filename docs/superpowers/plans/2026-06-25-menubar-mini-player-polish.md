# Menubar Mini Player Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make LyricX's menu-bar-only experience feel like a polished mini player with smoother long-lyric marquee behavior and lower redraw overhead.

**Architecture:** Keep the menubar as the only lyric surface. Add pure, unit-tested marquee timing behavior in `LyricXCore`, then update the AppKit status-item view/controller to consume it without reintroducing any removed desktop lyric surfaces. The popover remains SwiftUI but is organized as a compact now-playing controller.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit `NSStatusItem`/`NSControl`, Swift Package Manager, executable test runner `LyricXUnitTests`.

---

## Files

- Modify: `Sources/LyricXCore/Display/MenuBarTimelineMarquee.swift`
  - Add end pause and reset/cycle behavior for long lyrics.
- Modify: `Sources/LyricX/Menu/MenuBarStatusItemView.swift`
  - Cache attributed text and use the updated marquee offset model.
- Modify: `Sources/LyricX/Menu/MenuBarStatusItemController.swift`
  - Skip high-frequency rendering when presentation is static and unchanged; keep animated marquee ticking.
- Modify: `Sources/LyricX/Menu/MenuBarContentView.swift`
  - Keep popover structured as a now-playing mini player: track/status, lyric context, progress, playback toolbar, utilities.
- Modify: `Sources/LyricXUnitTests/main.swift`
  - Add unit coverage for marquee end pause/reset behavior.

---

### Task 1: Marquee End Pause and Reset

**Files:**
- Modify: `Sources/LyricXCore/Display/MenuBarTimelineMarquee.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

- [ ] Add failing tests:
  - `testTimelineMarqueeOffsetPausesAtEndBeforeReset()`
  - `testTimelineMarqueeOffsetResetsAfterEndPause()`
- [ ] Run `swift run LyricXUnitTests` and confirm the new tests fail because current marquee clamps at the end forever.
- [ ] Add `endPause` to `MenuBarTimelineMarquee` with default `0.9` seconds.
- [ ] Change `cycleDuration(contentWidth:)` to include `startPause + travel/speed + endPause`.
- [ ] Change `offset(elapsedTime:contentWidth:)` to wrap elapsed time by cycle duration after overflow content reaches the end.
- [ ] Run `swift run LyricXUnitTests` and confirm all tests pass.

### Task 2: Status Item Draw Cache

**Files:**
- Modify: `Sources/LyricX/Menu/MenuBarStatusItemView.swift`

- [ ] Add cached attributed text state keyed by presentation text/style.
- [ ] Recompute the attributed string only when presentation text, font size, font weight, or color changes.
- [ ] Keep drawing behavior identical except for using the cached attributed string.
- [ ] Run `swift run LyricXUnitTests && swift build`.

### Task 3: Popover Mini Player Review

**Files:**
- Modify if needed: `Sources/LyricX/Menu/MenuBarContentView.swift`

- [ ] Confirm the popover remains a mini-player layout: now-playing panel, lyric context/progress, playback toolbar, utility actions.
- [ ] Remove any obsolete toggle-style controls if present.
- [ ] Keep settings/main-window access and quit controls available.
- [ ] Run `swift build`.

### Task 4: Full Verification

**Files:**
- No source edits unless verification exposes an issue.

- [ ] Search tracked source/docs for removed desktop lyric surface names; expected no matches.
- [ ] Run `swift run LyricXUnitTests`.
- [ ] Run `swift build`.
- [ ] Run `bash scripts/build-app.sh`.
- [ ] Commit the code and plan once verified.
