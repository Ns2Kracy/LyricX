# Lyrics Translation and Romaji Design

## Context

LyricX currently centers the app around the macOS menu bar. `LyricTimeline` and `LyricLine` model synced source lyrics from LRCLIB. `AppModel.menuBarPresentation(at:)` converts the current lyric line into a single-line `MenuBarPresentation`, and `MenuBarStatusItemView` draws that presentation inside a fixed-width `NSStatusItem` with optional marquee behavior.

The feature adds optional translated lyrics, target-language selection, and optional Japanese romaji display without changing the existing source lyric timing path or reintroducing floating lyric surfaces.

## Goals

- Let the user enable lyric translation and select a target language.
- Support Japanese romaji as a separate optional display layer.
- Keep source lyrics reliable if translation or romaji generation fails.
- Preserve the current native-feeling menu bar experience: fixed status-item width, single-line drawing, stable popover anchor, low visual density.
- Show full source + translation context in popover and main window where there is enough space.

## Non-goals

- Do not add floating lyric windows or Dynamic Island surfaces.
- Do not make the menu bar item two lines tall.
- Do not block lyric display while translations are loading.
- Do not require a translation service when translation is disabled.
- Do not treat romaji as a target translation language; it is a Japanese-source pronunciation aid.

## Recommended approach

Use the hybrid approach selected by the user:

1. Keep source LRC as the primary timeline.
2. Add a separate translation timeline keyed by source lyric line identity and timestamp.
3. Prefer cached or source-provided translation data when available.
4. If missing and translation is enabled, translate the whole song into the selected target language and cache the result.
5. If source lyrics are Japanese and romaji is enabled, generate romaji into a separate optional field.
6. Fall back to source lyrics whenever translation or romaji data is missing.

## Data model

Add translation-specific model types in `LyricXCore/Lyrics`:

```swift
public struct LyricTranslationLine: Identifiable, Equatable, Sendable {
    public let sourceLineID: String
    public let time: TimeInterval
    public let translatedText: String?
    public let romajiText: String?

    public var id: String { sourceLineID }
}

public struct LyricTranslationTimeline: Equatable, Sendable {
    public let targetLanguage: TranslationLanguage
    public let lines: [LyricTranslationLine]

    public func line(for sourceLine: LyricLine) -> LyricTranslationLine?
}
```

Add `TranslationLanguage` as a small explicit enum first, not an open string bag:

```swift
public enum TranslationLanguage: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case system
    case english
    case simplifiedChinese
    case traditionalChinese
    case japanese
    case korean

    public var id: String { rawValue }
}
```

Rationale:

- A typed enum makes settings Codable migration safe and UI pickers straightforward.
- `system` lets the app follow user locale without exposing a blank configuration state.
- More languages can be added later without changing the storage shape.

## Settings

Extend `AppSettings` with backward-compatible defaults:

```swift
public var translationEnabled: Bool
public var translationTargetLanguage: TranslationLanguage
public var japaneseRomajiEnabled: Bool
public var menuBarLyricDisplayMode: MenuBarLyricDisplayMode
```

Add:

```swift
public enum MenuBarLyricDisplayMode: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case original
    case translation
    case alternateOriginalTranslation
    case alternateOriginalRomaji

    public var id: String { rawValue }
}
```

Defaults:

- `translationEnabled = false`
- `translationTargetLanguage = .system`
- `japaneseRomajiEnabled = false`
- `menuBarLyricDisplayMode = .original`

Settings UI changes:

- In `SettingsView`, add a `Translation` section.
- Include an enable toggle, target language picker, Japanese romaji toggle, and menu bar display mode picker.
- Disable target language and menu bar translation modes when translation is disabled, but preserve the chosen values.

## Translation service boundary

Add a protocol so the app can support multiple providers without tying core timing logic to one service:

```swift
public protocol LyricTranslationService: Sendable {
    func translationTimeline(
        for sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage
    ) async throws -> LyricTranslationTimeline
}
```

First implementation plan should include the boundary, cache, state handling, and a deterministic in-memory test provider that never ships as the default production provider. A real provider can then be added behind the protocol. If using Apple's Translation framework later, gate it by macOS availability. If using an external provider, store credentials outside source-controlled settings and make failures visible in settings/main-window state, not in the menu bar.

Translation strategy:

- Translate the whole song as a batch.
- Preserve source line order and count.
- Map translated results back to `LyricLine.id` and `time`.
- If the provider returns fewer lines, keep missing translations as `nil` rather than shifting lines.

## Cache

Add `LyricTranslationCache` beside `LyricsCache`.

Cache key inputs:

- artist
- title
- album when present
- duration when present
- target language
- source timeline fingerprint
- romaji enabled flag only if romaji is stored in the same payload

Storage format should be JSON, not LRC, because translation lines carry optional translation and romaji fields.

Failure policy:

- Cache writes are best-effort, matching existing `LyricsCache` behavior.
- Cache reads that fail to decode are ignored.
- A bad translation cache must never suppress source lyrics.

## Romaji

Romaji is separate from translation.

Behavior:

- Generate romaji only when `japaneseRomajiEnabled` is true and source text appears Japanese.
- Store romaji per source line as `romajiText`.
- Non-Japanese lyrics return `nil` romaji and fall back to source text for romaji display modes.

Implementation constraint:

- Swift/Foundation does not provide high-quality kanji reading. A local first version can reliably romanize kana but not infer kanji pronunciations.
- Full Japanese romaji requires either an external Japanese reading provider, a dictionary-backed morphological analyzer, or a translation provider that returns romanization.
- The UI should not promise complete kanji romanization unless the chosen implementation provides it.

## App state flow

Extend `AppModel`:

- Add `translationTimeline: LyricTranslationTimeline?`.
- Add `translationStatus` with states such as disabled, loading, available, failed.
- Trigger translation load after source lyrics load and when translation settings change.
- Cancel or ignore stale translation loads using the same track-scoping pattern as source lyric loading.
- `refreshLyrics()` should refresh source lyrics and then refresh translation if enabled.

State invariant:

- `timeline` remains the source of truth for current/next lyric timing.
- `translationTimeline` is only an enrichment layer.
- `currentLine` and `nextLine` continue to be source lyric lines.

## Menu bar presentation

Do not draw two rows in the menu bar item.

Add a pure function to choose display text:

```swift
public struct MenuBarLyricDisplayText: Equatable, Sendable {
    public let text: String
    public let accessibilityText: String
}
```

Inputs:

- source `LyricLine`
- matching `LyricTranslationLine?`
- `MenuBarLyricDisplayMode`
- line start date / target duration or current progress

Modes:

- `.original`: source lyric text.
- `.translation`: translated text if available, otherwise source lyric text.
- `.alternateOriginalTranslation`: source first, translation second when available; source only when unavailable.
- `.alternateOriginalRomaji`: source first, romaji second for Japanese when available; source only when unavailable.

The existing marquee behavior remains unchanged after the chosen text is computed. This preserves fixed width and the current long-lyric timing behavior.

## Popover design

`MenuBarContentView` stays compact and avoids dense blocks.

Current lyric area:

- Source lyric: primary text.
- Romaji: optional caption, lower contrast, displayed only when available and enabled.
- Translation: optional secondary text, at most two lines.

Controls/artwork remain the mini-player focus. Translation text must not force the popover into a crowded layout. If needed, make the lyric context a small collapsible area or show only the current bilingual line.

## Main window design

`MainWindowView` lyric context expands the `Current` row:

- Source current line remains primary.
- Romaji appears below source when available.
- Translation appears below romaji/source when available.
- Translation status appears near lyrics controls: Disabled, Translating, Available, Failed.

Previous and next rows can remain source-only in the first implementation to avoid UI density.

## Error handling

- Translation disabled: no service call.
- Translation loading: source lyrics continue displaying.
- Translation failure: source lyrics continue displaying; status records failure.
- Romaji unsupported or incomplete: source lyrics continue displaying; no warning in menu bar.
- Cache decode failure: ignore cache and retry provider when enabled.

No silent failure for user-visible translation state: failures should be represented in `translationStatus`, even though the menu bar remains clean.

## Tests

Add unit tests for:

- `AppSettings` decoding old settings without translation fields.
- `MenuBarLyricDisplayMode` Codable round trip.
- Translation cache key differs by target language and source fingerprint.
- `LyricTranslationTimeline.line(for:)` matches source lines by ID/time.
- Menu bar display text falls back to source when translation is unavailable.
- Alternate source/translation mode chooses source then translation within a line.
- Alternate source/romaji mode falls back to source for non-Japanese or missing romaji.
- Translation failure does not change source `MenuBarPresentation` text.

## Acceptance criteria

- User can enable translation and select a target language in settings.
- User can enable Japanese romaji separately.
- Menu bar can display original, translation, original/translation alternating, or original/romaji alternating without changing status-item height.
- Popover can show current source lyric plus translation and optional romaji without reintroducing dense lyric-heavy layout.
- Source lyric display continues to work when translation is disabled, loading, unavailable, or failed.
- Old settings files decode successfully with translation defaults.
