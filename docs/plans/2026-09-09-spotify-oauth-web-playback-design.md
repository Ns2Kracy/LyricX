# Spotify OAuth and Web Playback Design

## Scope

Add an opt-in Spotify Beta integration while preserving the existing local AppleScript path.

- Authenticate with Spotify using Authorization Code with PKCE.
- Read and control playback on any Spotify Connect device through the Web API.
- Let Premium users explicitly transfer playback to an embedded Web Playback SDK player.
- Improve LRCLIB lookup reliability and leave a thin provider boundary for future lyric sources.
- Keep OAuth limited to allowlisted accounts while the Spotify app remains in Development Mode.

## Non-goals

- Access Spotify's first-party lyrics; Spotify does not expose them through the supported Web API.
- Support embedded playback for non-Premium accounts.
- Transfer playback automatically at app launch.
- Implement NetEase Cloud Music or QQ Music lyric providers in this release.
- Add Chromium or use undocumented Spotify endpoints if WebKit playback is not viable.
- Advertise OAuth to unrestricted public accounts before Extended Quota approval.

## Architecture

Use the existing native Swift application with a small WebKit playback host.

- A Spotify authorization actor owns PKCE, the loopback callback, token exchange, refresh, and sign-out.
- The Client ID is public application configuration. No Client Secret is shipped.
- Refresh tokens are stored in macOS Keychain. Access tokens and PKCE state remain in memory.
- A Spotify Web API client reads playback and sends remote control and transfer commands.
- A main-actor Web Playback controller owns a retained `WKWebView`, loads the local player page and Spotify SDK, and bridges state and commands between JavaScript and Swift.
- A Spotify playback coordinator routes state and controls between Web Playback, Web API, and the existing AppleScript adapter.
- `AppModel` depends on an async playback boundary instead of the concrete AppleScript service.

The first implementation slice is a WebKit feasibility gate. Embedded playback ships only if a real Premium-account probe proves SDK readiness, device transfer, audible playback, controls, background-window playback, and clean shutdown. Failure leaves OAuth Connect state and remote controls enabled without adding a Chromium runtime.

## OAuth Flow

1. The user selects Connect Spotify in Settings.
2. LyricX creates a cryptographically random PKCE verifier, S256 challenge, and CSRF state.
3. A loopback listener binds to `127.0.0.1` on an available port.
4. LyricX opens the Spotify authorization page in the system browser.
5. The callback must use the expected host and path and contain the expected state.
6. LyricX exchanges the code with the same redirect URI and verifier.
7. The listener closes after one valid callback, denial, or timeout.
8. The refresh token is stored in Keychain and the access token is kept in memory.

Request only the scopes needed for account identification, SDK streaming, playback state, and playback modification. Token refresh retries the failed request once. If Spotify omits a new refresh token, LyricX preserves the existing one.

## Playback Flow

- Signed-in playback state comes from the Spotify Web API, including the active device and stable Spotify metadata.
- Signed-out or unavailable OAuth state uses the existing AppleScript adapter without changing its behavior.
- UI lyric timing continues to interpolate from the last playback position and timestamp.
- Web API reads are throttled independently from the one-second UI timeline tick and honor `Retry-After`.
- A transient API failure keeps the last known snapshot while retrying with backoff instead of immediately blanking the lyric display.
- Controls target the embedded SDK when LyricX is active, the Web API for another Connect device, and AppleScript when signed out.

The user must select Play in LyricX before embedded playback is initialized. LyricX waits for the SDK `ready` event, activates the playback element from that user action, and only then transfers playback to the returned device ID. Starting LyricX never transfers playback.

## Lyrics

Introduce a small async lyric-provider protocol. LRCLIB remains the only implementation in this release.

Lookup attempts use bounded metadata variants:

- Original Spotify title, artist, album, and duration.
- Normalized title with edition markers such as remaster, live, radio edit, and parenthetical suffixes removed when appropriate.
- Primary artist variants when a multi-artist string prevents a match.
- Search candidates ranked by normalized title, artist, album, and duration distance.

Only candidates above a confidence threshold are accepted. Exact results still win. Requests remain bounded, transient network failures receive limited retry, successful lyrics are cached, and a stale response cannot replace lyrics for a newer track. The protocol permits a later official provider without implementing unofficial NetEase or QQ endpoints now.

## Interface

Settings > Player gains a Spotify Beta section with:

- Connection and account status.
- Connect and Disconnect actions.
- Current Spotify Connect device.
- A Development Mode allowlist notice.
- Clear Premium, authorization, and SDK error states.

Now Playing shows the active device when signed in. Play in LyricX appears only when the account can use embedded playback and LyricX is not already active.

The WebKit host remains owned while audio is active so closing the main window does not stop playback. Quitting LyricX stops its embedded player.

## Security

- Use Authorization Code with PKCE and never bundle a Client Secret.
- Generate verifier and state with secure randomness and compare callback state exactly.
- Bind the callback listener only to loopback and accept only the expected callback path.
- Store refresh tokens only in Keychain and never persist or log access tokens.
- Pass only short-lived access tokens to the SDK token callback; never expose refresh tokens to JavaScript.
- Load only the bundled player page and Spotify SDK in `WKWebView`; reject arbitrary navigation.
- Redact OAuth response bodies and authorization headers from user-facing errors and logs.

## Error Handling

- Authorization denial and callback timeout leave the user signed out without affecting AppleScript playback.
- A `401` triggers one refresh and retry; refresh failure clears the invalid session and returns to AppleScript.
- A `429` observes `Retry-After`; server and network failures use bounded backoff.
- SDK initialization, authentication, account, and playback errors are surfaced separately.
- Transfer occurs only after SDK readiness, so a failed initialization cannot strand playback on a nonexistent device.
- Non-Premium users may use supported account and playback-state features, but embedded playback remains disabled with an explanation.

## Delivery Strategy

Implement directly on `main` in small, reviewable slices. Favor rapid vertical progress over test-first development:

1. Add configuration, PKCE, loopback callback, Keychain session storage, and sign-in UI.
2. Add Web API playback reads and remote controls behind the signed-in path.
3. Add the WebKit feasibility slice and verify it manually with an allowlisted Premium account.
4. Add explicit transfer to LyricX and embedded controls only if the feasibility gate passes.
5. Add LRCLIB normalization, candidate scoring, retries, and the provider boundary.
6. Run targeted tests, regression tests, release build, packaging, and manual Premium acceptance at the end.

Small compile and smoke checks may run between slices, but comprehensive testing is intentionally deferred until integration is complete.

## Final Verification

- PKCE, callback validation, refresh-token preservation, and authorization failures are covered.
- Keychain save, load, and delete behavior is checked without exposing token values.
- Web API decoding covers playing, paused, no active device, `204`, `401`, and `429` responses.
- Routing covers embedded SDK, remote Connect, and signed-out AppleScript paths.
- Application launch never transfers playback.
- Lyrics tests cover title normalization, primary artists, ranking, low-confidence rejection, retry, cache, and stale-load protection.
- `swift run LyricXUnitTests` passes.
- The release product builds and `scripts/build-app.sh` packages the app.
- A real allowlisted Premium account passes OAuth, SDK ready, explicit transfer, audible playback, controls, closed-main-window playback, and quit behavior.
