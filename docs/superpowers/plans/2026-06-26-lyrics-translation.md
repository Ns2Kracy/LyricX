# Lyrics Translation and Romaji Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional target-language lyric translation and Japanese romaji enrichment while preserving LyricX's native single-line menu bar behavior.

**Architecture:** Keep `LyricTimeline` as the source timing model and add a separate `LyricTranslationTimeline` enrichment layer. Add settings, cache, provider boundary, and pure menu-bar display-text selection before wiring AppModel and UI. First shipping implementation provides deterministic local enrichment hooks and cache/state plumbing; real network/system translation providers can be added behind the protocol without touching presentation code.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit `NSStatusItem`, Foundation Codable/FileManager, existing executable test target `LyricXUnitTests`.

---

## File structure

- Create `Sources/LyricXCore/Lyrics/LyricTranslation.swift`: translation language enum, translation line/timeline, translation status, provider protocol, deterministic provider used for local/test wiring.
- Create `Sources/LyricXCore/Lyrics/LyricTranslationCache.swift`: JSON cache keyed by track metadata, target language, source timeline fingerprint, and romaji flag.
- Create `Sources/LyricXCore/Lyrics/JapaneseRomaji.swift`: Japanese detection and kana-only romanization helper with explicit kanji limitation.
- Create `Sources/LyricXCore/Display/MenuBarLyricDisplayText.swift`: pure display text selector for original/translation/alternate modes.
- Modify `Sources/LyricXCore/Settings/AppSettings.swift`: translation settings and backward-compatible decoding.
- Modify `Sources/LyricX/App/AppModel.swift`: translation state, settings bindings, load lifecycle, menu-bar text selection.
- Modify `Sources/LyricX/Settings/SettingsView.swift`: Translation settings section.
- Modify `Sources/LyricX/Menu/MenuBarContentView.swift`: compact bilingual current lyric area.
- Modify `Sources/LyricX/Window/MainWindowView.swift`: current lyric translation/romaji/status display.
- Modify `Sources/LyricXUnitTests/main.swift`: unit coverage for settings, cache, timeline matching, display fallback/alternation, romaji, and source fallback on failure.

## Task 1: Settings types and Codable migration

**Files:**
- Modify: `Sources/LyricXCore/Settings/AppSettings.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

- [ ] **Step 1: Add failing settings tests**

In `Sources/LyricXUnitTests/main.swift`, add these calls after `testAppSettingsStoreSavesAndLoadsFrameRate()` in `main()`:

```swift
try testAppSettingsDecodesTranslationDefaultsFromOldJSON()
try testMenuBarLyricDisplayModeCodableRoundTrip()
try testTranslationLanguageCodableRoundTrip()
```

Add these test functions near existing AppSettings tests:

```swift
private static func testAppSettingsDecodesTranslationDefaultsFromOldJSON() throws {
    let data = Data(#"{"showsLyrics":true,"showsTrackWhenLyricsMissing":false,"menuBarFrameRate":15}"#.utf8)

    let settings = try JSONDecoder().decode(AppSettings.self, from: data)

    try expectEqual(settings.showsLyrics, true)
    try expectEqual(settings.showsTrackWhenLyricsMissing, false)
    try expectEqual(settings.menuBarFrameRate, .fps15)
    try expectEqual(settings.translationEnabled, false)
    try expectEqual(settings.translationTargetLanguage, .system)
    try expectEqual(settings.japaneseRomajiEnabled, false)
    try expectEqual(settings.menuBarLyricDisplayMode, .original)
}

private static func testMenuBarLyricDisplayModeCodableRoundTrip() throws {
    let encoded = try JSONEncoder().encode(MenuBarLyricDisplayMode.alternateOriginalTranslation)
    let decoded = try JSONDecoder().decode(MenuBarLyricDisplayMode.self, from: encoded)

    try expectEqual(decoded, .alternateOriginalTranslation)
}

private static func testTranslationLanguageCodableRoundTrip() throws {
    let encoded = try JSONEncoder().encode(TranslationLanguage.simplifiedChinese)
    let decoded = try JSONDecoder().decode(TranslationLanguage.self, from: encoded)

    try expectEqual(decoded, .simplifiedChinese)
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `swift run LyricXUnitTests`

Expected: compile failure naming missing `translationEnabled`, `MenuBarLyricDisplayMode`, or `TranslationLanguage`.

- [ ] **Step 3: Implement settings types**

Replace `Sources/LyricXCore/Settings/AppSettings.swift` with:

```swift
import Foundation

public enum TranslationLanguage: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case system
    case english
    case simplifiedChinese
    case traditionalChinese
    case japanese
    case korean

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .system:
            return "System"
        case .english:
            return "English"
        case .simplifiedChinese:
            return "Simplified Chinese"
        case .traditionalChinese:
            return "Traditional Chinese"
        case .japanese:
            return "Japanese"
        case .korean:
            return "Korean"
        }
    }
}

public enum MenuBarLyricDisplayMode: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case original
    case translation
    case alternateOriginalTranslation
    case alternateOriginalRomaji

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .original:
            return "Original"
        case .translation:
            return "Translation"
        case .alternateOriginalTranslation:
            return "Original / Translation"
        case .alternateOriginalRomaji:
            return "Original / Romaji"
        }
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var showsLyrics: Bool
    public var showsTrackWhenLyricsMissing: Bool
    public var menuBarFrameRate: MenuBarAnimationFrameRate
    public var translationEnabled: Bool
    public var translationTargetLanguage: TranslationLanguage
    public var japaneseRomajiEnabled: Bool
    public var menuBarLyricDisplayMode: MenuBarLyricDisplayMode

    public init(
        showsLyrics: Bool = true,
        showsTrackWhenLyricsMissing: Bool = true,
        menuBarFrameRate: MenuBarAnimationFrameRate = .default,
        translationEnabled: Bool = false,
        translationTargetLanguage: TranslationLanguage = .system,
        japaneseRomajiEnabled: Bool = false,
        menuBarLyricDisplayMode: MenuBarLyricDisplayMode = .original
    ) {
        self.showsLyrics = showsLyrics
        self.showsTrackWhenLyricsMissing = showsTrackWhenLyricsMissing
        self.menuBarFrameRate = menuBarFrameRate
        self.translationEnabled = translationEnabled
        self.translationTargetLanguage = translationTargetLanguage
        self.japaneseRomajiEnabled = japaneseRomajiEnabled
        self.menuBarLyricDisplayMode = menuBarLyricDisplayMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.default

        showsLyrics = try container.decodeIfPresent(Bool.self, forKey: .showsLyrics) ?? defaults.showsLyrics
        showsTrackWhenLyricsMissing = try container.decodeIfPresent(Bool.self, forKey: .showsTrackWhenLyricsMissing) ?? defaults.showsTrackWhenLyricsMissing
        menuBarFrameRate = try container.decodeIfPresent(MenuBarAnimationFrameRate.self, forKey: .menuBarFrameRate) ?? defaults.menuBarFrameRate
        translationEnabled = try container.decodeIfPresent(Bool.self, forKey: .translationEnabled) ?? defaults.translationEnabled
        translationTargetLanguage = try container.decodeIfPresent(TranslationLanguage.self, forKey: .translationTargetLanguage) ?? defaults.translationTargetLanguage
        japaneseRomajiEnabled = try container.decodeIfPresent(Bool.self, forKey: .japaneseRomajiEnabled) ?? defaults.japaneseRomajiEnabled
        menuBarLyricDisplayMode = try container.decodeIfPresent(MenuBarLyricDisplayMode.self, forKey: .menuBarLyricDisplayMode) ?? defaults.menuBarLyricDisplayMode
    }

    private enum CodingKeys: String, CodingKey {
        case showsLyrics
        case showsTrackWhenLyricsMissing
        case menuBarFrameRate
        case translationEnabled
        case translationTargetLanguage
        case japaneseRomajiEnabled
        case menuBarLyricDisplayMode
    }
}

public extension AppSettings {
    static let `default` = AppSettings()
}
```

- [ ] **Step 4: Run tests and verify pass**

Run: `swift run LyricXUnitTests`

Expected: `LyricXUnitTests passed`.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/LyricXCore/Settings/AppSettings.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: add translation settings"
```

## Task 2: Translation timeline and romaji helpers

**Files:**
- Create: `Sources/LyricXCore/Lyrics/LyricTranslation.swift`
- Create: `Sources/LyricXCore/Lyrics/JapaneseRomaji.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

- [ ] **Step 1: Add failing model and romaji tests**

Add these calls after the LRC/timeline tests in `main()`:

```swift
try testTranslationTimelineMatchesSourceLineByIDAndTime()
try testTranslationTimelineRejectsSameIDWithDifferentTime()
try testJapaneseRomajiRomanizesKana()
try testJapaneseRomajiReturnsNilForNonJapaneseText()
```

Add these functions near existing timeline tests:

```swift
private static func testTranslationTimelineMatchesSourceLineByIDAndTime() throws {
    let source = LyricLine(time: 12.0, text: "君が好き")
    let translated = LyricTranslationLine(
        sourceLineID: source.id,
        time: source.time,
        translatedText: "I love you",
        romajiText: "kimi ga suki"
    )
    let timeline = LyricTranslationTimeline(targetLanguage: .english, lines: [translated])

    try expectEqual(timeline.line(for: source), translated)
}

private static func testTranslationTimelineRejectsSameIDWithDifferentTime() throws {
    let source = LyricLine(time: 12.0, text: "君が好き")
    let shifted = LyricTranslationLine(
        sourceLineID: source.id,
        time: 13.0,
        translatedText: "I love you",
        romajiText: nil
    )
    let timeline = LyricTranslationTimeline(targetLanguage: .english, lines: [shifted])

    try expectNil(timeline.line(for: source))
}

private static func testJapaneseRomajiRomanizesKana() throws {
    try expectEqual(JapaneseRomaji.romanizedText(for: "きみ が すき"), "kimi ga suki")
}

private static func testJapaneseRomajiReturnsNilForNonJapaneseText() throws {
    try expectNil(JapaneseRomaji.romanizedText(for: "hello world"))
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `swift run LyricXUnitTests`

Expected: compile failure naming missing `LyricTranslationLine`, `LyricTranslationTimeline`, or `JapaneseRomaji`.

- [ ] **Step 3: Create translation model file**

Create `Sources/LyricXCore/Lyrics/LyricTranslation.swift`:

```swift
import Foundation

public struct LyricTranslationLine: Identifiable, Codable, Equatable, Sendable {
    public let sourceLineID: String
    public let time: TimeInterval
    public let translatedText: String?
    public let romajiText: String?

    public var id: String { sourceLineID }

    public init(sourceLineID: String, time: TimeInterval, translatedText: String?, romajiText: String?) {
        self.sourceLineID = sourceLineID
        self.time = time
        self.translatedText = translatedText?.nilIfBlank
        self.romajiText = romajiText?.nilIfBlank
    }
}

public struct LyricTranslationTimeline: Codable, Equatable, Sendable {
    public let targetLanguage: TranslationLanguage
    public let lines: [LyricTranslationLine]

    public init(targetLanguage: TranslationLanguage, lines: [LyricTranslationLine]) {
        self.targetLanguage = targetLanguage
        self.lines = lines.sorted { lhs, rhs in
            if lhs.time == rhs.time {
                lhs.sourceLineID < rhs.sourceLineID
            } else {
                lhs.time < rhs.time
            }
        }
    }

    public func line(for sourceLine: LyricLine) -> LyricTranslationLine? {
        lines.first { line in
            line.sourceLineID == sourceLine.id && abs(line.time - sourceLine.time) < 0.001
        }
    }
}

public enum LyricTranslationStatus: Equatable, Sendable {
    case disabled
    case loading
    case available
    case failed(String)

    public var label: String {
        switch self {
        case .disabled:
            return "Translation disabled"
        case .loading:
            return "Translating lyrics"
        case .available:
            return "Translation available"
        case .failed(let message):
            return "Translation failed: \(message)"
        }
    }
}

public protocol LyricTranslationService: Sendable {
    func translationTimeline(
        for sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        includeRomaji: Bool
    ) async throws -> LyricTranslationTimeline
}

public struct LocalLyricTranslationService: LyricTranslationService {
    public init() {}

    public func translationTimeline(
        for sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        includeRomaji: Bool
    ) async throws -> LyricTranslationTimeline {
        LyricTranslationTimeline(
            targetLanguage: targetLanguage,
            lines: sourceTimeline.lines.map { line in
                LyricTranslationLine(
                    sourceLineID: line.id,
                    time: line.time,
                    translatedText: nil,
                    romajiText: includeRomaji ? JapaneseRomaji.romanizedText(for: line.text) : nil
                )
            }
        )
    }
}
```

- [ ] **Step 4: Create kana-only romaji helper**

Create `Sources/LyricXCore/Lyrics/JapaneseRomaji.swift`:

```swift
import Foundation

public enum JapaneseRomaji {
    public static func romanizedText(for text: String) -> String? {
        guard containsJapanese(text) else {
            return nil
        }

        let tokens = text.map { character -> String in
            if character.isWhitespace {
                return " "
            }
            return kanaMap[character] ?? String(character)
        }

        let romanized = tokens.joined()
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return romanized.nilIfBlank
    }

    public static func containsJapanese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(Int(scalar.value)) ||
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }

    private static let kanaMap: [Character: String] = [
        "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
        "か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
        "さ": "sa", "し": "shi", "す": "su", "せ": "se", "そ": "so",
        "た": "ta", "ち": "chi", "つ": "tsu", "て": "te", "と": "to",
        "な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
        "は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
        "ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
        "や": "ya", "ゆ": "yu", "よ": "yo",
        "ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
        "わ": "wa", "を": "wo", "ん": "n",
        "が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
        "ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
        "だ": "da", "ぢ": "ji", "づ": "zu", "で": "de", "ど": "do",
        "ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
        "ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "ぺ": "pe", "ぽ": "po",
        "ア": "a", "イ": "i", "ウ": "u", "エ": "e", "オ": "o",
        "カ": "ka", "キ": "ki", "ク": "ku", "ケ": "ke", "コ": "ko",
        "サ": "sa", "シ": "shi", "ス": "su", "セ": "se", "ソ": "so",
        "タ": "ta", "チ": "chi", "ツ": "tsu", "テ": "te", "ト": "to",
        "ナ": "na", "ニ": "ni", "ヌ": "nu", "ネ": "ne", "ノ": "no",
        "ハ": "ha", "ヒ": "hi", "フ": "fu", "ヘ": "he", "ホ": "ho",
        "マ": "ma", "ミ": "mi", "ム": "mu", "メ": "me", "モ": "mo",
        "ヤ": "ya", "ユ": "yu", "ヨ": "yo",
        "ラ": "ra", "リ": "ri", "ル": "ru", "レ": "re", "ロ": "ro",
        "ワ": "wa", "ヲ": "wo", "ン": "n"
    ]
}
```

- [ ] **Step 5: Run tests and verify pass**

Run: `swift run LyricXUnitTests`

Expected: `LyricXUnitTests passed`.

- [ ] **Step 6: Commit**

Run:

```bash
git add Sources/LyricXCore/Lyrics/LyricTranslation.swift Sources/LyricXCore/Lyrics/JapaneseRomaji.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: add lyric translation models"
```

## Task 3: Translation cache

**Files:**
- Create: `Sources/LyricXCore/Lyrics/LyricTranslationCache.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

- [ ] **Step 1: Add failing cache tests**

Add these calls after translation timeline tests in `main()`:

```swift
try testTranslationCacheKeyDiffersByLanguage()
try testTranslationCacheSavesAndLoadsTimeline()
try testTranslationCacheIgnoresInvalidJSON()
```

Add these functions near cache/repository tests:

```swift
private static func testTranslationCacheKeyDiffersByLanguage() throws {
    let cache = LyricTranslationCache(directory: URL(fileURLWithPath: NSTemporaryDirectory()))
    let track = PlaybackTrack(title: "Song", artist: "Artist", album: "Album", duration: 120)
    let timeline = LyricTimeline(lines: [LyricLine(time: 1, text: "Hello")])

    let english = cache.fileURL(for: track, sourceTimeline: timeline, targetLanguage: .english, includeRomaji: false)
    let chinese = cache.fileURL(for: track, sourceTimeline: timeline, targetLanguage: .simplifiedChinese, includeRomaji: false)

    try expectEqual(english == chinese, false)
}

private static func testTranslationCacheSavesAndLoadsTimeline() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cache = LyricTranslationCache(directory: directory)
    let track = PlaybackTrack(title: "Song", artist: "Artist", album: "Album", duration: 120)
    let sourceTimeline = LyricTimeline(lines: [LyricLine(time: 1, text: "Hello")])
    let translationTimeline = LyricTranslationTimeline(
        targetLanguage: .english,
        lines: [LyricTranslationLine(sourceLineID: sourceTimeline.lines[0].id, time: 1, translatedText: "Hello", romajiText: nil)]
    )

    cache.store(translationTimeline, for: track, sourceTimeline: sourceTimeline, includeRomaji: false)

    try expectEqual(
        cache.cachedTimeline(for: track, sourceTimeline: sourceTimeline, targetLanguage: .english, includeRomaji: false),
        translationTimeline
    )
}

private static func testTranslationCacheIgnoresInvalidJSON() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cache = LyricTranslationCache(directory: directory)
    let track = PlaybackTrack(title: "Song", artist: "Artist", album: "Album", duration: 120)
    let sourceTimeline = LyricTimeline(lines: [LyricLine(time: 1, text: "Hello")])
    let fileURL = cache.fileURL(for: track, sourceTimeline: sourceTimeline, targetLanguage: .english, includeRomaji: false)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("not-json".utf8).write(to: fileURL)

    try expectNil(cache.cachedTimeline(for: track, sourceTimeline: sourceTimeline, targetLanguage: .english, includeRomaji: false))
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `swift run LyricXUnitTests`

Expected: compile failure naming missing `LyricTranslationCache`.

- [ ] **Step 3: Implement translation cache**

Create `Sources/LyricXCore/Lyrics/LyricTranslationCache.swift`:

```swift
import Foundation

public struct LyricTranslationCache: Sendable {
    public let directory: URL

    public init(directory: URL? = nil) {
        self.directory = directory ?? Self.defaultDirectory()
    }

    public func cachedTimeline(
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        includeRomaji: Bool
    ) -> LyricTranslationTimeline? {
        let url = fileURL(for: track, sourceTimeline: sourceTimeline, targetLanguage: targetLanguage, includeRomaji: includeRomaji)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(LyricTranslationTimeline.self, from: data)
    }

    public func store(
        _ timeline: LyricTranslationTimeline,
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        includeRomaji: Bool
    ) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(timeline)
            try data.write(to: fileURL(for: track, sourceTimeline: sourceTimeline, targetLanguage: timeline.targetLanguage, includeRomaji: includeRomaji), options: .atomic)
        } catch {
            // Cache writes are best-effort; source lyrics must not depend on disk access.
        }
    }

    public func fileURL(
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        includeRomaji: Bool
    ) -> URL {
        directory.appendingPathComponent(cacheKey(for: track, sourceTimeline: sourceTimeline, targetLanguage: targetLanguage, includeRomaji: includeRomaji))
            .appendingPathExtension("json")
    }

    private func cacheKey(
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        includeRomaji: Bool
    ) -> String {
        [
            track.artist,
            track.title,
            track.album ?? "",
            track.duration.map { String(Int($0.rounded())) } ?? "",
            targetLanguage.rawValue,
            includeRomaji ? "romaji" : "no-romaji",
            sourceFingerprint(sourceTimeline)
        ]
        .joined(separator: "-")
        .lowercased()
        .unicodeScalars
        .map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
        }
        .reduce(into: "") { result, character in
            if character == "-", result.last == "-" {
                return
            }
            result.append(character)
        }
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func sourceFingerprint(_ timeline: LyricTimeline) -> String {
        String(timeline.lines.reduce(into: 5381) { hash, line in
            hash = ((hash << 5) &+ hash) &+ line.id.hashValue
        })
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("LyricX/LyricTranslations", isDirectory: true)
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

Run: `swift run LyricXUnitTests`

Expected: `LyricXUnitTests passed`.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/LyricXCore/Lyrics/LyricTranslationCache.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: cache lyric translations"
```

## Task 4: Menu bar display text selector

**Files:**
- Create: `Sources/LyricXCore/Display/MenuBarLyricDisplayText.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

- [ ] **Step 1: Add failing display tests**

Add these calls after menu bar behavior tests in `main()`:

```swift
try testMenuBarDisplayTextUsesOriginalMode()
try testMenuBarDisplayTextFallsBackWhenTranslationMissing()
try testMenuBarDisplayTextUsesTranslationMode()
try testMenuBarDisplayTextAlternatesOriginalThenTranslation()
try testMenuBarDisplayTextAlternatesOriginalThenRomaji()
try testMenuBarDisplayTextFallsBackToOriginalWhenRomajiMissing()
```

Add these functions near existing menu bar tests:

```swift
private static func testMenuBarDisplayTextUsesOriginalMode() throws {
    let source = LyricLine(time: 10, text: "君が好き")
    let translation = LyricTranslationLine(sourceLineID: source.id, time: 10, translatedText: "I love you", romajiText: "kimi ga suki")

    let text = MenuBarLyricDisplayText.resolve(sourceLine: source, translationLine: translation, mode: .original, lineProgress: 0.75)

    try expectEqual(text.text, "君が好き")
}

private static func testMenuBarDisplayTextFallsBackWhenTranslationMissing() throws {
    let source = LyricLine(time: 10, text: "君が好き")

    let text = MenuBarLyricDisplayText.resolve(sourceLine: source, translationLine: nil, mode: .translation, lineProgress: 0.75)

    try expectEqual(text.text, "君が好き")
}

private static func testMenuBarDisplayTextUsesTranslationMode() throws {
    let source = LyricLine(time: 10, text: "君が好き")
    let translation = LyricTranslationLine(sourceLineID: source.id, time: 10, translatedText: "I love you", romajiText: nil)

    let text = MenuBarLyricDisplayText.resolve(sourceLine: source, translationLine: translation, mode: .translation, lineProgress: 0.25)

    try expectEqual(text.text, "I love you")
}

private static func testMenuBarDisplayTextAlternatesOriginalThenTranslation() throws {
    let source = LyricLine(time: 10, text: "君が好き")
    let translation = LyricTranslationLine(sourceLineID: source.id, time: 10, translatedText: "I love you", romajiText: nil)

    let early = MenuBarLyricDisplayText.resolve(sourceLine: source, translationLine: translation, mode: .alternateOriginalTranslation, lineProgress: 0.25)
    let late = MenuBarLyricDisplayText.resolve(sourceLine: source, translationLine: translation, mode: .alternateOriginalTranslation, lineProgress: 0.75)

    try expectEqual(early.text, "君が好き")
    try expectEqual(late.text, "I love you")
}

private static func testMenuBarDisplayTextAlternatesOriginalThenRomaji() throws {
    let source = LyricLine(time: 10, text: "きみ が すき")
    let translation = LyricTranslationLine(sourceLineID: source.id, time: 10, translatedText: nil, romajiText: "kimi ga suki")

    let early = MenuBarLyricDisplayText.resolve(sourceLine: source, translationLine: translation, mode: .alternateOriginalRomaji, lineProgress: 0.25)
    let late = MenuBarLyricDisplayText.resolve(sourceLine: source, translationLine: translation, mode: .alternateOriginalRomaji, lineProgress: 0.75)

    try expectEqual(early.text, "きみ が すき")
    try expectEqual(late.text, "kimi ga suki")
}

private static func testMenuBarDisplayTextFallsBackToOriginalWhenRomajiMissing() throws {
    let source = LyricLine(time: 10, text: "hello")

    let text = MenuBarLyricDisplayText.resolve(sourceLine: source, translationLine: nil, mode: .alternateOriginalRomaji, lineProgress: 0.75)

    try expectEqual(text.text, "hello")
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `swift run LyricXUnitTests`

Expected: compile failure naming missing `MenuBarLyricDisplayText`.

- [ ] **Step 3: Implement display selector**

Create `Sources/LyricXCore/Display/MenuBarLyricDisplayText.swift`:

```swift
import Foundation

public struct MenuBarLyricDisplayText: Equatable, Sendable {
    public let text: String
    public let accessibilityText: String

    public init(text: String, accessibilityText: String) {
        self.text = text
        self.accessibilityText = accessibilityText
    }

    public static func resolve(
        sourceLine: LyricLine,
        translationLine: LyricTranslationLine?,
        mode: MenuBarLyricDisplayMode,
        lineProgress: Double
    ) -> MenuBarLyricDisplayText {
        let source = sourceLine.text
        let translation = translationLine?.translatedText?.nilIfBlank
        let romaji = translationLine?.romajiText?.nilIfBlank
        let useSecondary = lineProgress >= 0.5

        let selected: String
        switch mode {
        case .original:
            selected = source
        case .translation:
            selected = translation ?? source
        case .alternateOriginalTranslation:
            selected = useSecondary ? (translation ?? source) : source
        case .alternateOriginalRomaji:
            selected = useSecondary ? (romaji ?? source) : source
        }

        let accessibilityParts = [source, translation, romaji]
            .compactMap { $0?.nilIfBlank }
            .reduce(into: [String]()) { result, value in
                if !result.contains(value) {
                    result.append(value)
                }
            }

        return MenuBarLyricDisplayText(
            text: selected,
            accessibilityText: accessibilityParts.isEmpty ? selected : accessibilityParts.joined(separator: ", ")
        )
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

Run: `swift run LyricXUnitTests`

Expected: `LyricXUnitTests passed`.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/LyricXCore/Display/MenuBarLyricDisplayText.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: select menu bar translation text"
```

## Task 5: AppModel translation lifecycle

**Files:**
- Modify: `Sources/LyricX/App/AppModel.swift`
- Modify: `Sources/LyricXUnitTests/main.swift`

- [ ] **Step 1: Add focused fallback test**

Add this call after menu bar display tests in `main()`:

```swift
try testMenuBarDisplayTextKeepsSourceWhenTranslationFailed()
```

Add this test near other menu bar display tests:

```swift
private static func testMenuBarDisplayTextKeepsSourceWhenTranslationFailed() throws {
    let source = LyricLine(time: 10, text: "君が好き")

    let text = MenuBarLyricDisplayText.resolve(
        sourceLine: source,
        translationLine: nil,
        mode: .alternateOriginalTranslation,
        lineProgress: 0.9
    )

    try expectEqual(text.text, "君が好き")
}
```

- [ ] **Step 2: Run test to verify current pure fallback passes**

Run: `swift run LyricXUnitTests`

Expected: `LyricXUnitTests passed`. This protects the source lyric fallback before AppModel wiring.

- [ ] **Step 3: Add AppModel dependencies and state**

In `Sources/LyricX/App/AppModel.swift`, add stored properties near `timeline` and ignored dependencies:

```swift
var translationTimeline: LyricTranslationTimeline?
var translationStatus: LyricTranslationStatus = .disabled

@ObservationIgnored private let translationService: any LyricTranslationService
@ObservationIgnored private let translationCache: LyricTranslationCache
@ObservationIgnored private var translationTask: Task<Void, Never>?
```

Update `init` signature to include defaults:

```swift
translationService: any LyricTranslationService = LocalLyricTranslationService(),
translationCache: LyricTranslationCache = LyricTranslationCache(),
```

Assign them inside init:

```swift
self.translationService = translationService
self.translationCache = translationCache
```

- [ ] **Step 4: Add settings bindings**

Add computed properties near other AppModel setting properties:

```swift
var translationEnabled: Bool {
    get { settings.translationEnabled }
    set {
        settings.translationEnabled = newValue
        persistSettings()
        reloadTranslationForCurrentTrack()
    }
}

var translationTargetLanguage: TranslationLanguage {
    get { settings.translationTargetLanguage }
    set {
        settings.translationTargetLanguage = newValue
        persistSettings()
        reloadTranslationForCurrentTrack()
    }
}

var japaneseRomajiEnabled: Bool {
    get { settings.japaneseRomajiEnabled }
    set {
        settings.japaneseRomajiEnabled = newValue
        persistSettings()
        reloadTranslationForCurrentTrack()
    }
}

var menuBarLyricDisplayMode: MenuBarLyricDisplayMode {
    get { settings.menuBarLyricDisplayMode }
    set {
        settings.menuBarLyricDisplayMode = newValue
        persistSettings()
    }
}
```

- [ ] **Step 5: Clear translation state on no-track and track changes**

In `pollOnce()`, wherever `timeline`, `currentLine`, and `nextLine` are cleared, also set:

```swift
translationTask?.cancel()
translationTimeline = nil
translationStatus = settings.translationEnabled ? .loading : .disabled
```

For no-track case, use:

```swift
translationStatus = .disabled
```

- [ ] **Step 6: Load translation after source lyrics**

At the end of successful `loadLyrics(for:bypassCache:)`, after `timeline = loadedTimeline`, add:

```swift
if let loadedTimeline {
    loadTranslation(for: track, sourceTimeline: loadedTimeline)
} else {
    translationTimeline = nil
    translationStatus = settings.translationEnabled ? .failed("No source lyrics") : .disabled
}
```

Add helper methods:

```swift
private func reloadTranslationForCurrentTrack() {
    guard let track = playback.track, let timeline else {
        translationTimeline = nil
        translationStatus = settings.translationEnabled ? .loading : .disabled
        return
    }
    loadTranslation(for: track, sourceTimeline: timeline)
}

private func loadTranslation(for track: PlaybackTrack, sourceTimeline: LyricTimeline) {
    translationTask?.cancel()

    guard settings.translationEnabled || settings.japaneseRomajiEnabled else {
        translationTimeline = nil
        translationStatus = .disabled
        return
    }

    let targetLanguage = settings.translationTargetLanguage
    let includeRomaji = settings.japaneseRomajiEnabled

    if let cached = translationCache.cachedTimeline(
        for: track,
        sourceTimeline: sourceTimeline,
        targetLanguage: targetLanguage,
        includeRomaji: includeRomaji
    ) {
        translationTimeline = cached
        translationStatus = .available
        return
    }

    translationStatus = .loading
    let service = translationService
    let cache = translationCache
    translationTask = Task { [weak self] in
        do {
            let loadedTimeline = try await service.translationTimeline(
                for: sourceTimeline,
                targetLanguage: targetLanguage,
                includeRomaji: includeRomaji
            )
            await MainActor.run {
                guard self?.playback.track == track, self?.timeline == sourceTimeline else {
                    return
                }
                self?.translationTimeline = loadedTimeline
                self?.translationStatus = .available
                cache.store(loadedTimeline, for: track, sourceTimeline: sourceTimeline, includeRomaji: includeRomaji)
            }
        } catch {
            await MainActor.run {
                guard self?.playback.track == track else {
                    return
                }
                self?.translationTimeline = nil
                self?.translationStatus = .failed(error.localizedDescription)
            }
        }
    }
}
```

- [ ] **Step 7: Apply display text in menuBarPresentation**

Inside `menuBarPresentation(at:)`, replace the direct `lyric` selection for current line with:

```swift
let position = estimatedPlaybackPosition(at: date)
if let line = timeline?.currentLine(at: position), let lyric = nonBlank(line.text) {
    let startedAt = lyricStartedAt(for: line, position: position, date: date)
    let targetDuration = menuBarTargetDuration(for: line)
    let lineProgress = menuBarLineProgress(for: line, position: position)
    let displayText = MenuBarLyricDisplayText.resolve(
        sourceLine: line,
        translationLine: translationTimeline?.line(for: line),
        mode: settings.menuBarLyricDisplayMode,
        lineProgress: lineProgress
    )
    let text = nonBlank(displayText.text) ?? lyric
    return MenuBarPresentation(
        text: text,
        accessibilityText: displayText.accessibilityText,
        symbol: nil,
        behavior: menuBarBehavior(for: text, startedAt: startedAt, targetDuration: targetDuration, style: style),
        style: style
    )
}
```

Add helper:

```swift
private func menuBarLineProgress(for line: LyricLine, position: TimeInterval) -> Double {
    guard let duration = menuBarTargetDuration(for: line), duration > 0 else {
        return 0
    }
    return min(max((position - line.time) / duration, 0), 1)
}
```

- [ ] **Step 8: Run tests and build**

Run:

```bash
swift run LyricXUnitTests
swift build
```

Expected: tests print `LyricXUnitTests passed`; build completes without errors.

- [ ] **Step 9: Commit**

Run:

```bash
git add Sources/LyricX/App/AppModel.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: wire lyric translation state"
```

## Task 6: Settings UI

**Files:**
- Modify: `Sources/LyricX/Settings/SettingsView.swift`

- [ ] **Step 1: Add Translation section**

In `SettingsView.body`, insert this section between `Lyrics` and `Menu Bar`:

```swift
Section("Translation") {
    Toggle("Enable lyric translation", isOn: $model.translationEnabled)

    Picker("Target Language", selection: $model.translationTargetLanguage) {
        ForEach(TranslationLanguage.allCases) { language in
            Text(language.label).tag(language)
        }
    }
    .disabled(!model.translationEnabled)

    Toggle("Show Japanese romaji", isOn: $model.japaneseRomajiEnabled)

    Picker("Menu Bar Lyrics", selection: $model.menuBarLyricDisplayMode) {
        ForEach(MenuBarLyricDisplayMode.allCases) { mode in
            Text(mode.label).tag(mode)
        }
    }

    Text(model.translationStatus.label)
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

- [ ] **Step 2: Run build**

Run: `swift build`

Expected: build completes without errors.

- [ ] **Step 3: Commit**

Run:

```bash
git add Sources/LyricX/Settings/SettingsView.swift
git commit -m "feat: add translation settings UI"
```

## Task 7: Popover and main-window bilingual display

**Files:**
- Modify: `Sources/LyricX/Menu/MenuBarContentView.swift`
- Modify: `Sources/LyricX/Window/MainWindowView.swift`

- [ ] **Step 1: Add AppModel convenience accessors**

In `AppModel`, add computed helpers if not already present from Task 5:

```swift
var currentTranslationLine: LyricTranslationLine? {
    guard let currentLine else {
        return nil
    }
    return translationTimeline?.line(for: currentLine)
}
```

Commit this with Task 7 UI files, not Task 5, if discovered during implementation.

- [ ] **Step 2: Update popover current lyric area**

In `MenuBarContentView`, add a compact lyric stack below the existing track metadata or near the progress area, depending on current layout:

```swift
if let currentLine = model.currentLine {
    VStack(alignment: .leading, spacing: 3) {
        Text(currentLine.text)
            .font(.callout.weight(.medium))
            .lineLimit(1)

        if let romaji = model.currentTranslationLine?.romajiText {
            Text(romaji)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }

        if let translation = model.currentTranslationLine?.translatedText {
            Text(translation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}
```

Keep existing artwork and controls; do not increase the popover enough to make it feel like a lyric window.

- [ ] **Step 3: Update main-window Current row**

In `MainWindowView`, extend the current lyric section so the Current row shows source, romaji, translation, and `model.translationStatus.label`. Use existing `LyricContextRow` style where possible. If `LyricContextRow` only accepts plain text, add small `Text` rows below Current:

```swift
if let romaji = model.currentTranslationLine?.romajiText {
    LyricContextRow(label: "Romaji", text: romaji, prominence: .secondary)
}

if let translation = model.currentTranslationLine?.translatedText {
    LyricContextRow(label: "Translation", text: translation, prominence: .secondary)
}

LyricContextRow(label: "Translation Status", text: model.translationStatus.label, prominence: .secondary)
```

- [ ] **Step 4: Build**

Run: `swift build`

Expected: build completes without errors.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/LyricX/App/AppModel.swift Sources/LyricX/Menu/MenuBarContentView.swift Sources/LyricX/Window/MainWindowView.swift
git commit -m "feat: show bilingual lyric context"
```

## Task 8: Final verification and cleanup

**Files:**
- Verify all modified files.
- No documentation changes unless implementation diverged from spec.

- [ ] **Step 1: Run unit tests**

Run: `swift run LyricXUnitTests`

Expected: `LyricXUnitTests passed`.

- [ ] **Step 2: Run package build**

Run: `swift build`

Expected: build completes without errors.

- [ ] **Step 3: Build app bundle**

Run: `bash scripts/build-app.sh`

Expected: app bundle build completes without errors.

- [ ] **Step 4: Search for forbidden regressions**

Run repository search, not shell grep, for these strings:

- `FloatingLyrics`
- `IslandLyrics`
- `temporary implementation marker`
- `unfinished implementation marker`

Expected: no newly introduced floating/island source references; no unfinished scaffolding markers in new translation implementation.

- [ ] **Step 5: Commit final cleanup if needed**

Only if Step 4 or verification required edits:

```bash
git add <changed-files>
git commit -m "chore: clean up lyric translation implementation"
```

## Self-review

- Spec coverage: settings, target language, separate romaji, cache, provider boundary, menu-bar single-line modes, popover/main-window bilingual display, fallback behavior, and old settings migration all map to tasks above.
- No network provider is required by this plan; it establishes the boundary and local deterministic enrichment so source lyrics remain reliable. A real provider can be added as a follow-up behind `LyricTranslationService`.
- Type consistency: `TranslationLanguage`, `MenuBarLyricDisplayMode`, `LyricTranslationLine`, `LyricTranslationTimeline`, `LyricTranslationStatus`, `LyricTranslationCache`, `JapaneseRomaji`, and `MenuBarLyricDisplayText` are introduced before use.
- Verification: each implementation task runs `swift run LyricXUnitTests` or `swift build`; final task runs tests, build, and app bundle build.
