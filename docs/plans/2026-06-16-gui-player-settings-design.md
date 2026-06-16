# GUI, Player, Style Preset, and Update Design

## Status

Accepted on 2026-06-16.

## Context

LyricX is currently a macOS menu-bar-only SwiftUI app. It reads Spotify playback through AppleScript, fetches synced lyrics from LRCLIB, and renders lyric or track text directly in the menu bar.

The next product direction is broader than the current menu-bar label:

- A full GUI for cover art, lyrics, playback controls, settings, and update status.
- A lightweight menu-bar control surface that stays useful for quick actions.
- A style preset system for different lyric display formats.
- Future support for music apps beyond Spotify.
- A future desktop floating lyric window, but not in the first implementation phase.
- A practical update path that works before code signing and notarization are available.

## Decisions

### GUI Shape

Build both a full main window and a lightweight menu-bar interface.

The main window is the primary management surface. It should show artwork, track metadata, synced lyrics, playback controls, the active lyric style preset, settings access, and update status.

The menu-bar UI stays focused on fast controls and lyric display. It should not become a dense settings panel.

### First Player Scope

The first implementation supports Spotify only.

Even though Spotify is the only first player, the app should introduce a player abstraction now so future Apple Music, NetEase Cloud Music, QQ Music, or browser-based players can be added without rewriting the GUI.

The initial player abstraction should cover:

- Current playback snapshot.
- Play or pause.
- Next track.
- Previous track.
- Optional artwork lookup.

### Lyric Style Presets

Use an advanced preset model rather than only one global style setting.

The first implementation should include preset storage and a small set of built-in presets. It should not attempt a full style marketplace, import/export, or complex template management in phase one.

Preset fields should include menu-bar width, font size, font weight, text color, alignment, and whether to show track text when synced lyrics are missing. Later phases can add outline, shadow, current-line and next-line styles, and floating lyric specific settings.

### Lyrics and Artwork

LRCLIB remains the synced lyric source.

The main window should display full current lyric context instead of the constrained menu-bar marquee. Cover art should come from Spotify when available. If Spotify artwork is not available through the first AppleScript implementation, the GUI should show a stable placeholder rather than blocking the rest of the feature.

### Floating Lyrics

The first implementation should not build a desktop floating lyric window.

The settings UI may show a disabled or "coming later" entry so the product direction is visible, but no window level, drag, lock, click-through, or screen-position persistence behavior should be implemented yet.

### Updates

Use a GitHub Release check first, with a service boundary that can later be replaced by Sparkle.

The first update service checks the latest GitHub Release, compares it with the app bundle version, and opens the release page when an update is available. It should not automatically download, install, replace, or restart the app.

Sparkle should wait until the app has a signing and notarization story.

## Proposed Architecture

### Player Services

Introduce protocol boundaries in `LyricXCore`:

```swift
public protocol PlayerService: Sendable {
    func currentSnapshot() -> PlaybackSnapshot
    func playPause()
    func nextTrack()
    func previousTrack()
}

public protocol ArtworkProvider: Sendable {
    func artwork(for track: PlaybackTrack) async -> TrackArtwork?
}
```

Rename or wrap the current `SpotifyPlaybackService` as the Spotify implementation of those protocols. Keep the AppleScript parsing tests close to the service.

### Style Presets

Add a preset model and store in `LyricXCore`:

```swift
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
```

The store should persist presets and active preset selection in Application Support or user defaults. The first implementation can use JSON in Application Support to keep the model portable and testable.

### Update Service

Add a GitHub update service:

```swift
public protocol UpdateService: Sendable {
    func latestVersion() async throws -> AppUpdate?
}
```

`GitHubReleaseUpdateService` should fetch latest release metadata from `Ns2Kracy/LyricX`, compare semantic versions, and return release URL and asset metadata.

### App Model

`AppModel` should become the composition layer for player, lyrics, style presets, artwork, and update state.

The model should expose simple UI-facing state:

- Current track.
- Playback state.
- Artwork image or placeholder state.
- Current lyric and surrounding lyrics.
- Active style preset.
- Update availability.
- Commands for play/pause, next, previous, refresh lyrics, open settings, and check updates.

### SwiftUI GUI

Add a main window scene with a work-focused layout:

- Header: artwork, track name, artist, playback state.
- Center: current lyric with previous and next context.
- Controls: previous, play/pause, next, refresh lyrics.
- Settings access: active preset and update status.

Add a settings view or sheet with:

- Preset list and active selection.
- Basic editable preset fields.
- Player section showing Spotify as the active provider.
- Update section with check button and release link.
- Disabled floating lyric row marked as planned later.

## Testing Strategy

Add tests for pure behavior first:

- Spotify playback parsing and AppleScript command generation.
- Player control command construction.
- Preset default values, Codable round trip, and store load/save behavior.
- Update version comparison and GitHub response decoding.
- Existing menu-bar marquee behavior.

Use `swift run LyricXUnitTests` as the local test gate. Use `swift build`, `bash scripts/build-app.sh`, and `bash scripts/package-release.sh` before completing implementation slices that affect app packaging.

## Non-Goals For Phase One

- No Apple Music, NetEase Cloud Music, QQ Music, or browser player implementation.
- No floating desktop lyrics behavior.
- No Sparkle integration.
- No automatic app replacement or restart.
- No style preset import/export.
- No plugin system.

## Release Notes

This feature should land incrementally. The first user-visible release should keep the menu-bar behavior stable while adding the main window and settings entry points.
