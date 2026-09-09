# Spotify OAuth and Web Playback Implementation Plan

> **For Codex:** Implement directly on `main` in small vertical slices. The user explicitly requested less test-first work and comprehensive testing at the end.

**Goal:** Add Spotify PKCE sign-in, Connect playback state and controls, opt-in embedded Premium playback, and more reliable LRCLIB matching without breaking the AppleScript fallback.

**Architecture:** Keep the Swift/AppKit application native. Add Spotify authorization and Web API actors in `LyricXMac`, host the JavaScript Web Playback SDK in a retained `WKWebView`, and route all playback through one async coordinator. Keep LRCLIB as the only lyric provider while introducing a thin async provider boundary.

**Tech Stack:** Swift 6.2, SwiftUI/AppKit, Observation, Security/Keychain, CryptoKit, Network, WebKit, URLSession, Spotify Web API, Spotify Web Playback SDK, Swift Package Manager.

**Working constraints:** Work on `main` as requested. Do not commit a Client Secret or token. Use small compile/smoke checks between slices; defer complete unit, release, packaging, and Premium-account tests until Task 7.

---

### Task 1: Make Playback Async and Add Spotify Configuration

**Files:**

- Modify: `Sources/LyricXCore/Playback/PlayerService.swift`
- Modify: `Sources/LyricXCore/Playback/PlaybackSnapshot.swift`
- Modify: `Sources/LyricXMac/Playback/SpotifyAppleScriptPlaybackService.swift`
- Modify: `Sources/LyricX/App/AppModel.swift`
- Create: `Sources/LyricXMac/Spotify/SpotifyConfiguration.swift`
- Modify: `Sources/LyricX/Resources/Info.plist`
- Modify: `scripts/build-app.sh`

**Steps:**

1. Change `PlayerService` control and snapshot methods to `async`. Keep `PlaybackArtworkService` as the shared playback/artwork boundary.
2. Move AppleScript blocking work behind detached tasks inside `SpotifyAppleScriptPlaybackService` so callers can await it without blocking the main actor.
3. Change `AppModel` to depend on `any PlaybackArtworkService`, remove its AppleScript-specific detached wrappers, and preserve the existing one-second lyric timeline update behavior.
4. Extend `PlaybackTrack` with optional stable source metadata needed by Spotify (`sourceID`, `sourceURI`, and `isrc`) while keeping defaults so AppleScript callers remain source-compatible.
5. Add `SpotifyConfiguration` that reads `SPOTIFY_CLIENT_ID` from the environment for `swift run`, then `SpotifyClientID` from the application Info.plist for packaged builds. Treat the Client ID as public configuration and reject blank/placeholder values.
6. Add an empty `SpotifyClientID` Info.plist key. Update `scripts/build-app.sh` to inject the environment value into the copied plist when present; never accept or inject a Client Secret.
7. Run `swift build` and repair only compile errors caused by this boundary change.
8. Review the diff and commit only this slice:

```bash
git add Package.swift Sources/LyricXCore/Playback Sources/LyricXMac/Playback \
  Sources/LyricXMac/Spotify/SpotifyConfiguration.swift Sources/LyricX/App/AppModel.swift \
  Sources/LyricX/Resources/Info.plist scripts/build-app.sh
git commit -m "refactor: make playback services async"
```

Expected: debug build succeeds; AppleScript remains the only runtime source.

### Task 2: Add Secure Spotify PKCE Authorization

**Files:**

- Create: `Sources/LyricXMac/Spotify/SpotifyAuthorizationService.swift`
- Create: `Sources/LyricXMac/Spotify/SpotifyKeychainTokenStore.swift`
- Modify: `Sources/LyricX/App/AppModel.swift`
- Modify: `Sources/LyricX/Settings/SettingsView.swift`

**Steps:**

1. Define minimal session models: authorization status, account summary, access-token expiry, refresh token, granted scopes, and typed OAuth failures.
2. Implement PKCE verifier generation with secure random bytes and an S256 challenge with CryptoKit. Generate an independent CSRF `state` value.
3. Implement a one-shot loopback callback listener bound to `127.0.0.1` on a dynamic port. Accept only `GET /callback`, require the exact state, return a small success/error HTTP page, and close after success, denial, or timeout.
4. Open the authorization URL through `NSWorkspace`. Request only `streaming`, `user-read-private`, `user-read-email`, `user-read-playback-state`, and `user-modify-playback-state`.
5. Exchange the code using Authorization Code with PKCE. Store only the refresh token in a generic-password Keychain item under the LyricX bundle service name; retain access tokens in actor memory.
6. Restore a session by refreshing from Keychain. On refresh responses without a replacement refresh token, preserve the existing token. Redact token-bearing data from all errors.
7. Add `connectSpotify()` and `disconnectSpotify()` actions and observable authorization state to `AppModel`.
8. Add a `Spotify Beta` block to Settings > Player with status, Connect/Disconnect, configuration errors, and the Development Mode allowlist notice.
9. Run `swift build`; use an invalid/missing Client ID only to smoke-check the local UI error path.
10. Commit the authorization slice:

```bash
git add Sources/LyricXMac/Spotify Sources/LyricX/App/AppModel.swift Sources/LyricX/Settings/SettingsView.swift
git commit -m "feat: add Spotify PKCE sign-in"
```

Expected: the app builds, missing configuration is explained, and no credential values appear in source or logs.

### Task 3: Read and Control Spotify Connect Through the Web API

**Files:**

- Create: `Sources/LyricXMac/Spotify/SpotifyWebAPIClient.swift`
- Create: `Sources/LyricXMac/Spotify/SpotifyPlaybackCoordinator.swift`
- Modify: `Sources/LyricX/App/AppModel.swift`
- Modify: `Sources/LyricX/App/AppContainer.swift`
- Modify: `Sources/LyricX/Window/MainWindowView.swift`
- Modify: `Sources/LyricX/Settings/SettingsView.swift`

**Steps:**

1. Implement an injected-`URLSession` Web API client for `/v1/me`, `/v1/me/player`, play, pause, previous, next, and transfer playback.
2. Decode only fields LyricX uses: account product, device ID/name/type, playing state, progress, track ID/URI/name/artists/album/duration/images, and ISRC.
3. Centralize request authorization in the client. On `401`, request one token refresh and retry once. On `429`, capture `Retry-After` and expose a typed backoff result. Treat `204` as no active playback.
4. Add a playback coordinator that prefers authenticated Web API state, throttles network reads independently of the one-second UI tick, extrapolates position using timestamps, and retains the last snapshot across short transient failures.
5. Route signed-out playback and controls to `SpotifyAppleScriptPlaybackService`. Do not launch Spotify as a side effect.
6. Wire the coordinator through `AppContainer` and `AppModel`. Show current Connect device in Settings and Now Playing without changing existing lyric/menu-bar presentation.
7. Run `swift build` and smoke-check that signed-out AppleScript playback still updates.
8. Commit the Connect slice:

```bash
git add Sources/LyricXMac/Spotify Sources/LyricX/App Sources/LyricX/Settings/SettingsView.swift \
  Sources/LyricX/Window/MainWindowView.swift
git commit -m "feat: add Spotify Connect playback"
```

Expected: authenticated accounts use Web API state and remote controls; signed-out accounts remain on AppleScript.

### Task 4: Prove Web Playback SDK Works in WKWebView

**Files:**

- Modify: `Package.swift`
- Create: `Sources/LyricXMac/Resources/SpotifyWebPlayer.html`
- Create: `Sources/LyricXMac/Spotify/SpotifyWebPlaybackController.swift`
- Modify: `Sources/LyricXMac/Spotify/SpotifyPlaybackCoordinator.swift`

**Steps:**

1. Register the LyricXMac HTML resource in `Package.swift` and load it from `Bundle.module`.
2. Keep the page minimal: load `https://sdk.scdn.co/spotify-player.js`, create `Spotify.Player`, forward ready/not-ready/state/error events to Swift, and expose connect, activate, play/pause, previous, next, and disconnect commands.
3. Implement a weak script-message bridge so `WKUserContentController` cannot retain the controller. Never send a refresh token to JavaScript.
4. Supply a valid short-lived access token through the SDK callback and refresh it through the native authorization actor when requested.
5. Restrict WebView navigation to the bundled page and Spotify SDK resources. Retain the WebView in an application-owned audio host after the main window closes.
6. Add a temporary internal `prepareEmbeddedPlayer()` path that connects but does not transfer playback automatically.
7. Build the packaged app with `SPOTIFY_CLIENT_ID` and manually use an allowlisted Premium account to verify SDK `ready` and a device ID.
8. If SDK readiness fails in WKWebView, keep the OAuth and Connect work, record the failure, remove the unusable host, and skip Task 5. Do not add Chromium or undocumented workarounds.
9. If the feasibility gate passes, commit it:

```bash
git add Package.swift Sources/LyricXMac/Resources Sources/LyricXMac/Spotify
git commit -m "feat: host Spotify Web Playback SDK"
```

Expected: the SDK registers a LyricX Connect device in WKWebView without transferring playback at launch.

### Task 5: Add Explicit Play in LyricX

**Files:**

- Modify: `Sources/LyricXMac/Spotify/SpotifyPlaybackCoordinator.swift`
- Modify: `Sources/LyricXMac/Spotify/SpotifyWebPlaybackController.swift`
- Modify: `Sources/LyricX/App/AppModel.swift`
- Modify: `Sources/LyricX/Window/MainWindowView.swift`
- Modify: `Sources/LyricX/Settings/SettingsView.swift`

**Steps:**

1. Expose `playInLyricX()` only for an authenticated Premium account.
2. Invoke Web Playback `activateElement()` from the explicit SwiftUI button action, wait for SDK readiness, then transfer playback with `play: true` to the SDK device ID.
3. Never transfer during startup, session restoration, polling, window open, or SDK reconnect.
4. Once LyricX is active, route controls through the SDK. If another device is active, route them through the Web API.
5. Surface initialization, authentication, account, playback, and transfer errors separately. A failed SDK preparation must occur before transfer and must leave the existing device untouched.
6. Show `Play in LyricX` only when useful. Keep the WebView/audio host alive after the main window closes and disconnect it when the app terminates.
7. Run `swift build` and a short manual transfer/control smoke check.
8. Commit the opt-in playback slice:

```bash
git add Sources/LyricXMac/Spotify Sources/LyricX/App/AppModel.swift \
  Sources/LyricX/Window/MainWindowView.swift Sources/LyricX/Settings/SettingsView.swift
git commit -m "feat: add opt-in Spotify playback"
```

Expected: playback transfers only after a user click and remains audible when the main window closes.

### Task 6: Improve LRCLIB Reliability Behind a Provider Boundary

**Files:**

- Create: `Sources/LyricXCore/Lyrics/LyricsProvider.swift`
- Modify: `Sources/LyricXCore/Lyrics/LRCLIBClient.swift`
- Modify: `Sources/LyricXCore/Lyrics/LyricsRepository.swift`
- Modify: `Sources/LyricXCore/Lyrics/LyricsCache.swift` only if stable source metadata changes its key behavior

**Steps:**

1. Define a single async `LyricsProvider` method that returns synced lyric text or no result. Make `LRCLIBClient` conform and let `LyricsRepository` query an ordered provider list.
2. Preserve the exact LRCLIB lookup first. Generate a small, deduplicated set of fallback queries from the original title, a normalized title, and a primary-artist variant.
3. Normalize case, punctuation, whitespace, featured-artist markers, parenthetical edition suffixes, live/radio/edit/remaster markers, and common dash variants without destroying meaningful title text.
4. Rank search candidates by normalized title and artist equality, album agreement, and duration distance. Require a documented minimum score and reject candidates with a large duration mismatch.
5. Bound total requests and retry only transient transport/5xx failures once. Do not retry `404` or malformed successful responses indefinitely.
6. Keep successful caching and stale-track protection. Do not implement NetEase or QQ providers.
7. Run `swift build`.
8. Commit the lyric slice:

```bash
git add Sources/LyricXCore/Lyrics
git commit -m "fix: improve LRCLIB lyric matching"
```

Expected: common Spotify edition metadata no longer prevents LRCLIB matches, while low-confidence candidates are rejected.

### Task 7: Add Focused Tests and Run Final Verification

**Files:**

- Modify: `Sources/LyricXUnitTests/PlaybackAndMenuBarTests.swift`
- Modify: `Sources/LyricXUnitTests/SettingsAndUpdateTests.swift`
- Modify: `Sources/LyricXUnitTests/CoreTests.swift`
- Modify: `Sources/LyricXUnitTests/TestSupport.swift`
- Modify: `Sources/LyricXUnitTests/TestMain.swift`
- Create if separation helps: `Sources/LyricXUnitTests/SpotifyTests.swift`
- Modify: `README.md`

**Steps:**

1. Add focused tests for PKCE challenge format, authorization URL scopes, callback state/path rejection, refresh-token preservation, and Keychain abstraction behavior. Use injected stores/transports; never use a real token in tests.
2. Add Web API fixture tests for playing, paused, `204`, `401` refresh-and-retry, `429 Retry-After`, account product, metadata, and command endpoints.
3. Add coordinator tests proving Web API versus AppleScript routing and proving initialization alone never transfers playback.
4. Add lyric tests for title/artist variants, normalized scoring, duration rejection, bounded retry, provider order, and URL encoding.
5. Update existing playback test doubles for the async protocol and register every new test in `TestMain.swift`.
6. Update `README.md` with Spotify Beta setup, `SPOTIFY_CLIENT_ID`, the required redirect URI `http://127.0.0.1/callback`, Development Mode allowlisting, Premium requirements, Keychain behavior, fallback behavior, and the fact that Spotify lyrics are unavailable through the supported API.
7. Run the complete checks once integration is ready:

```bash
swift run LyricXUnitTests
swift build -c release
SPOTIFY_CLIENT_ID='<configured-client-id>' bash scripts/build-app.sh
bash scripts/package-release.sh
git diff --check
```

Expected: all tests pass, release build succeeds, the app and zip are produced, and the diff has no whitespace errors.

1. Scan tracked changes for credentials and required public symbols/configuration:

```bash
git diff --cached | rg -i 'client_secret|refresh_token|access_token|authorization:'
rg -n 'SpotifyClientID|SpotifyAuthorizationService|SpotifyPlaybackCoordinator|LyricsProvider' \
  Package.swift scripts Sources README.md
```

Expected: no credential values; all integration points are present.

1. Complete the manual allowlisted Premium checklist:
   - Connect and restore a Spotify session.
   - Read a track playing on another Connect device without Spotify desktop running.
   - Use remote play/pause, previous, and next.
   - Confirm app launch never transfers playback.
   - Select Play in LyricX and hear audio.
   - Confirm pause/resume/previous/next and lyric timing.
   - Close the main window and confirm audio continues.
   - Quit LyricX and confirm its player stops.
   - Disconnect and confirm Keychain session deletion plus AppleScript fallback.

2. Review all changes, update docs for any proven WKWebView limitation, and commit the verification slice:

```bash
git add Sources/LyricXUnitTests README.md
git commit -m "test: cover Spotify integration and lyric matching"
```

Expected: the branch is releasable for Development Mode allowlisted users, with embedded playback advertised only if the manual feasibility gate passes.
