# Lyrics Translation Providers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a real configurable translation provider path so LyricX can produce `translatedText` lines instead of only Japanese romaji.

**Architecture:** Keep `LyricTimeline` as the source timing model and keep `LyricTranslationTimeline` as enrichment. Add provider settings, a provider-chain service, and an OpenAI-compatible machine translation provider as the first real multi-language backend. Leave NetEase/QQ as explicit disabled provider toggles until their APIs are implemented and reviewed.

**Tech Stack:** Swift 6.2, Foundation `URLSession`, SwiftUI settings UI, existing executable unit-test harness.

---

## File structure

- Modify `Sources/LyricXCore/Settings/AppSettings.swift`: provider settings enums and Codable migration defaults.
- Modify `Sources/LyricXCore/Lyrics/LyricTranslation.swift`: provider protocol/result/options, OpenAI-compatible provider, provider-chain service.
- Modify `Sources/LyricX/App/AppModel.swift`: expose provider settings, pass track into provider-chain service, preserve stale async guards.
- Modify `Sources/LyricX/Settings/SettingsView.swift`: provider controls under Translation settings.
- Modify `Sources/LyricXUnitTests/main.swift`: red/green coverage for provider settings migration, provider chain, OpenAI-compatible request parsing, and AppModel real translation path.

## Task 1: Provider settings model

**Files:**
- Modify: `Sources/LyricXCore/Settings/AppSettings.swift`
- Test: `Sources/LyricXUnitTests/main.swift`

- [ ] **Step 1: Write failing settings tests**

Add tests that assert new provider settings decode from old JSON with safe defaults and round-trip through Codable:

```swift
try testAppSettingsDecodesProviderDefaultsFromOldJSON()
try testTranslationProviderSettingsCodableRoundTrip()
```

Expected defaults:

```swift
settings.translationSourceMode == .auto
settings.machineTranslationProvider == .none
settings.openAICompatibleBaseURL == ""
settings.openAICompatibleModel == ""
settings.openAICompatibleAPIKey == ""
settings.netEaseTranslationSourceEnabled == false
settings.qqMusicTranslationSourceEnabled == false
```

- [ ] **Step 2: Run red test**

Run: `swift run LyricXUnitTests`

Expected: compile failure because the provider setting symbols do not exist.

- [ ] **Step 3: Implement settings types**

Add:

```swift
public enum TranslationSourceMode: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case auto
    case existingLyricsOnly
    case chineseLyricSourcesOnly
    case machineTranslationOnly
}

public enum MachineTranslationProvider: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case none
    case openAICompatible
}
```

Add labels for UI, and add fields to `AppSettings` with defaults listed above. Extend custom decoder with `decodeIfPresent` for backward compatibility.

- [ ] **Step 4: Run green test**

Run: `swift run LyricXUnitTests`

Expected: provider settings tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/LyricXCore/Settings/AppSettings.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: add translation provider settings"
```

## Task 2: Provider chain and OpenAI-compatible provider

**Files:**
- Modify: `Sources/LyricXCore/Lyrics/LyricTranslation.swift`
- Test: `Sources/LyricXUnitTests/main.swift`

- [ ] **Step 1: Write failing provider-chain tests**

Add tests for:

- Provider chain returns the first confident provider result and does not call later providers.
- Provider chain falls through when a provider returns no translated lines.
- OpenAI-compatible provider parses a JSON response into line-aligned translations.
- OpenAI-compatible provider rejects missing base URL, model, or API key.

- [ ] **Step 2: Run red test**

Run: `swift run LyricXUnitTests`

Expected: compile failure because provider-chain symbols do not exist.

- [ ] **Step 3: Implement provider protocol and chain**

Add `TranslationProviderKind`, `LyricTranslationProviderOptions`, `LyricTranslationProviderResult`, `LyricTranslationProvider`, `LyricTranslationProviderChain`, and `ProviderChainLyricTranslationService`.

The chain must return the first result where `timeline.lines.contains { $0.translatedText?.nilIfBlank != nil }`.

- [ ] **Step 4: Implement OpenAI-compatible provider**

Implement a provider that POSTs to `baseURL` with Chat Completions compatible JSON, asking the model to return strict JSON:

```json
{"translations":[{"id":"source-line-id","text":"translated lyric"}]}
```

Map by `id` to source lines; missing IDs become `nil`. Preserve romaji generation when requested.

- [ ] **Step 5: Run green test**

Run: `swift run LyricXUnitTests`

Expected: provider-chain and parsing tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/LyricXCore/Lyrics/LyricTranslation.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: add lyric translation provider chain"
```

## Task 3: Wire AppModel and settings UI

**Files:**
- Modify: `Sources/LyricX/App/AppModel.swift`
- Modify: `Sources/LyricX/Settings/SettingsView.swift`
- Test: `Sources/LyricXUnitTests/main.swift`

- [ ] **Step 1: Write failing AppModel test**

Add a test that configures `machineTranslationProvider = .openAICompatible`, injects a deterministic provider-chain service returning translated text, enables translation, and asserts:

```swift
model.translationStatus == .available
model.translationTimeline?.line(for: source)?.translatedText == "I love you"
```

- [ ] **Step 2: Run red test**

Run: `swift run LyricXUnitTests`

Expected: compile failure or failure because AppModel does not carry provider settings into translation loading.

- [ ] **Step 3: Update AppModel API**

Expose model bindings for:

```swift
translationSourceMode
machineTranslationProvider
openAICompatibleBaseURL
openAICompatibleModel
openAICompatibleAPIKey
netEaseTranslationSourceEnabled
qqMusicTranslationSourceEnabled
```

Each setter persists settings and calls `reloadTranslationForCurrentTrack()` when it changes provider behavior.

Update translation service calls to include `track` and `settings` via options while preserving current request identity stale guards.

- [ ] **Step 4: Update SettingsView**

In Translation settings add:

- Source mode picker.
- Chinese lyric source toggles marked disabled with explanatory text.
- Machine translation provider picker.
- Base URL, model, and API key fields shown only for OpenAI-compatible provider.
- Provider limitation/help text.

- [ ] **Step 5: Run green test**

Run: `swift run LyricXUnitTests`

Expected: AppModel provider setting tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/LyricX/App/AppModel.swift Sources/LyricX/Settings/SettingsView.swift Sources/LyricXUnitTests/main.swift
git commit -m "feat: wire translation provider settings"
```

## Task 4: Final verification

**Files:**
- No planned source edits unless verification exposes a defect.

- [ ] **Step 1: Run full unit tests**

Run: `swift run LyricXUnitTests`

Expected: `LyricXUnitTests passed`.

- [ ] **Step 2: Run build**

Run: `swift build`

Expected: exit 0.

- [ ] **Step 3: Build app bundle**

Run: `bash scripts/build-app.sh`

Expected: `Built .../dist/LyricX.app`.

- [ ] **Step 4: Regression search**

Run source searches for accidental forbidden regressions:

- `FloatingLyrics`
- `IslandLyrics`
- `temporary implementation marker`
- `unfinished implementation marker`
- `TODO`
- `placeholder`

Expected: no source regressions.

- [ ] **Step 5: Commit verification fixes if any**

If verification required code changes, commit them as a small fix commit. Otherwise no commit.
