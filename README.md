# LyricX

LyricX is a macOS menu-bar app with a companion SwiftUI window for synced Spotify lyrics, similar to the desktop lyric modes in NetEase Cloud Music or QQ Music.

It is built with SwiftUI and Swift Package Manager. The repository does not require a generated Xcode project for normal build, test, or packaging tasks.

## Features

- Shows the current synced lyric line in the macOS menu bar.
- Provides a main LyricX window with track status, lyric preview, artwork, playback controls, and settings.
- Includes settings for lyric style presets, menu-bar width, font size, color, alignment, and missing-lyrics fallback behavior.
- Supports true KTV-style highlighting when the lyric source provides timed word or segment data, with line-level fallback otherwise.
- Falls back to the current Spotify track name when synced lyrics are missing.
- Hides the menu-bar icon when lyric or track text is available, and shows the icon only as the empty-state fallback.
- Connects to Spotify with Authorization Code + PKCE and reads any active Spotify Connect device.
- Lets Spotify Premium users transfer audio to an in-app Web Playback SDK player.
- Falls back to local Spotify AppleScript playback when no Spotify account is connected.
- Fetches synced lyrics from LRCLIB, retries normalized metadata, and uses ISRC-based MusicBrainz metadata on misses.
- Checks GitHub Releases manually from the app UI when you want to look for an update.

## Requirements

- macOS 14 or newer
- Apple Swift 6.2 or newer
- A Spotify account added to the app allowlist while the Spotify app is in Development Mode
- Spotify Premium for in-app audio playback
- A Spotify Developer app Client ID for OAuth features
- Internet access for Spotify, LRCLIB, MusicBrainz metadata fallback, and update checks

Spotify for macOS is optional after OAuth is configured. It remains useful as the disconnected fallback.

## Quick Start

Build the Swift package:

```bash
swift build
```

Run LyricX with Spotify OAuth enabled:

```bash
SPOTIFY_CLIENT_ID='<your-client-id>' swift run LyricX
```

Run the logic test executable:

```bash
swift run LyricXUnitTests
```

Create a runnable app bundle with the Client ID embedded as public configuration:

```bash
SPOTIFY_CLIENT_ID='<your-client-id>' bash scripts/build-app.sh
```

Launch the app:

```bash
open dist/LyricX.app
```

LyricX opens a main window and also keeps the lyric line in the menu bar. Open the menu-bar item to show the main window, control Spotify playback, refresh lyrics, toggle lyric text, show the track name when lyrics are missing, or quit. Settings live in the main window's Settings tab.

## Spotify Beta Setup

1. Create an app in the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
2. Register `http://127.0.0.1/callback` as a redirect URI. Do not add a port; Spotify permits the authorization request to add a dynamic port for a loopback IP literal.
3. While the app is in Development Mode, add each test user to its allowlist.
4. Build or run LyricX with `SPOTIFY_CLIENT_ID` as shown above. A Client Secret is neither needed nor accepted.
5. Open Settings > Spotify Beta, choose Connect Spotify, and complete authorization in the browser.

LyricX stores only the refresh token in macOS Keychain. Access tokens remain in memory. Connecting does not move playback. Choose Listen in LyricX explicitly to transfer the current Spotify playback to the in-app player.

For GitHub-built artifacts, set the repository Actions variable `SPOTIFY_CLIENT_ID`; it is public application configuration, not a secret.

## Main Window

The main window has a Now Playing tab and a Settings tab. Now Playing shows the current Spotify track, active Connect device, playback state, previous/current/next lyric context, the active style preset, update status, playback controls, and an explicit Listen in LyricX action when Spotify is connected.

Spotify artwork is loaded when the current track exposes an artwork URL. LyricX falls back to a compact placeholder when artwork is unavailable.

## Settings

Open the main LyricX window and choose the Settings tab. Settings currently include:

- Lyric style preset selection and editing.
- Menu-bar width, font size, font weight, text color, alignment, and missing-lyrics fallback behavior.
- Spotify OAuth status, active Connect device, and in-app Premium player status.
- Disabled entries for future music-app support.
- Manual GitHub Release update checking and an Open Release link when an update is available.

Preset edits are saved as JSON under Application Support.

## Commands

| Command | Description |
| --- | --- |
| `swift build` | Build all SwiftPM targets in debug mode. |
| `swift run LyricXUnitTests` | Run the executable unit test suite. |
| `bash scripts/build-app.sh` | Build `dist/LyricX.app` in release mode. |
| `bash scripts/package-release.sh` | Package `dist/LyricX.app` as `dist/LyricX.zip` and write `dist/LyricX.zip.sha256`. |

## Packaging

Create a local release package with:

```bash
SPOTIFY_CLIENT_ID='<your-client-id>' bash scripts/build-app.sh
bash scripts/package-release.sh
```

The packaged files are written to:

- `dist/LyricX.zip`
- `dist/LyricX.zip.sha256`

The app is currently unsigned. If macOS Gatekeeper blocks a downloaded build, users may need to remove quarantine manually or open it through Finder's context menu. Code signing and notarization can be added later once a Developer ID certificate is available.

## GitHub CI/CD

The repository includes two GitHub Actions workflows:

- `.github/workflows/ci.yml` runs on pull requests and pushes to `main`.
- `.github/workflows/release.yml` runs when a tag matching `v*` is pushed.

CI runs these gates on the macOS runner:

1. `swift run LyricXUnitTests`
2. `swift build`
3. `bash scripts/build-app.sh`
4. `bash scripts/package-release.sh`

The CI workflow uploads `LyricX.zip` and `LyricX.zip.sha256` as a build artifact.

## Release

Create and publish a GitHub release by pushing a version tag:

```bash
git tag v0.1.3
git push origin v0.1.3
```

The release workflow builds the app, packages the zip and checksum, then creates a GitHub Release with generated notes.

The workflow uses the default `GITHUB_TOKEN` with `contents: write` permission. No additional repository secrets are required for unsigned releases.

## Spotify Permissions

OAuth requests only `streaming`, `user-read-playback-state`, and `user-modify-playback-state`. The first scope powers the Premium Web Playback SDK; the other two read and control the active Spotify Connect device.

When disconnected, LyricX falls back to the local Spotify desktop app through `/usr/bin/osascript`. macOS may ask for Automation permission to control Spotify or System Events. OAuth/Connect playback does not require that permission or require Spotify for macOS to remain open.

Spotify is the only enabled music service in this phase. Apple Music, NetEase Cloud Music, QQ Music, and browser players remain disabled future entries.

## Lyrics

When connected, playback metadata comes from the Spotify Web API, including album, duration, stable track identifiers, and ISRC when available. Spotify does not expose its own lyrics through the supported API. Synced lyrics still come from LRCLIB and are cached under Application Support.

LyricX tries an LRCLIB exact lookup, a scored search, and a normalized title/primary-artist variant. If those miss and Spotify supplied an ISRC, LyricX resolves canonical recording metadata through MusicBrainz at its documented one-request-per-second limit, then retries LRCLIB once. If no synchronized lyrics match confidently, LyricX shows the track name or `No synced lyrics for <track>`.

LyricX displays lyrics in the menu bar and in the main window lyric context. KTV mode uses only source-provided timed word or segment timestamps. When the active lyric has only ordinary line-level LRC timestamps, LyricX shows line-level lyric context without fabricating per-word timing.

## Project Layout

```text
Sources/LyricX/          SwiftUI menu-bar app target
Sources/LyricXCore/      Playback contracts, lyric lookup, parsing, caching, style, artwork, and update logic
Sources/LyricXMac/       Spotify OAuth, Web API/Playback SDK, and AppleScript adapters
Sources/LyricXUnitTests/ Executable test target for Command Line Tools environments
scripts/build-app.sh     Release app bundle builder
scripts/package-release.sh Release zip and checksum packager
.github/workflows/      CI and GitHub Release automation
```

## Troubleshooting

- If Spotify Beta says Unavailable, rebuild with `SPOTIFY_CLIENT_ID` or inject it into the app bundle.
- Development Mode rejects accounts not added to the Spotify app allowlist.
- In-app playback requires a supported Spotify Premium plan; account errors are shown in Spotify Beta settings.
- If OAuth is disconnected, Spotify for macOS must be installed and Automation permission granted for the AppleScript fallback.
- Some tracks do not have synchronized lyrics in LRCLIB; LyricX falls back to track text in that case.
- The app bundle in `dist/` is generated output and is intentionally not committed.
