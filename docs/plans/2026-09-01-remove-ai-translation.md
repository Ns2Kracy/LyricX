# Remove AI Translation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove OpenAI-compatible machine translation without removing existing lyric translation, source-provider, cache, display, or Japanese romaji support.

**Architecture:** Delete machine-provider configuration and network implementation at the settings, app-model, UI, and core-provider layers. Preserve the generic provider chain for non-AI lyric sources and migrate persisted `machineTranslationOnly` values to `auto` during settings decoding.

**Tech Stack:** Swift 6.2, SwiftUI, Swift Package Manager, custom executable unit-test harness.

---

### Task 1: Prove legacy settings migration

**Files:**

- Modify: `Sources/LyricXUnitTests/SettingsAndUpdateTests.swift`
- Modify: `Sources/LyricXUnitTests/TestMain.swift`

**Step 1: Write the failing test**

Add `testAppSettingsMigratesRemovedMachineTranslationMode()` that decodes JSON containing `"translationSourceMode":"machineTranslationOnly"` and expects `.auto`.

**Step 2: Run the test suite to verify it fails**

Run: `swift run LyricXUnitTests`
Expected: FAIL because the current decoder preserves `.machineTranslationOnly`.

### Task 2: Remove machine-translation settings and UI

**Files:**

- Modify: `Sources/LyricXCore/Settings/AppSettings.swift`
- Modify: `Sources/LyricX/App/AppModel.swift`
- Modify: `Sources/LyricX/Settings/SettingsView.swift`
- Modify: `Sources/LyricXUnitTests/SettingsAndUpdateTests.swift`

**Steps:**

1. Remove `MachineTranslationProvider`, `.machineTranslationOnly`, OpenAI settings fields, initializer parameters, decoding, and coding keys.
2. Decode `translationSourceMode` by raw string and fall back to `.auto`, which migrates the removed value.
3. Remove AppModel bindings and provider-option forwarding for machine translation.
4. Remove machine-provider and credential controls from the Translation settings section.
5. Keep NetEase/QQ roadmap controls and update explanatory copy to mention only those lyric sources.
6. Update settings round-trip/default tests to assert retained non-AI settings.

### Task 3: Remove OpenAI provider implementation

**Files:**

- Modify: `Sources/LyricXCore/Lyrics/LyricTranslation.swift`
- Modify: `Sources/LyricXUnitTests/TranslationTests.swift`
- Modify: `Sources/LyricXUnitTests/TestMain.swift`

**Steps:**

1. Remove OpenAI provider kind, provider registration, URL request implementation, payload types, and machine-option fields.
2. Default `ProviderChainLyricTranslationService` to an empty provider list while retaining local romaji fallback.
3. Remove OpenAI-specific tests.
4. Change generic provider-chain test doubles to non-AI provider kinds.
5. Keep injected translation-service coverage without configuring a machine provider.

### Task 4: Verify and commit

**Files:**

- Verify all modified production and test files.

**Steps:**

1. Run LSP diagnostics on modified Swift files.
2. Run `swift run LyricXUnitTests` and require zero failures.
3. Run `swift build` and require exit code 0.
4. Search production code for `OpenAI`, `MachineTranslationProvider`, `machineTranslationOnly`, and `openAICompatible`; require zero matches.
5. Inspect `git diff --check`, staged diff, and status without adding `.omp/`, `.pi-glla/`, or `.pi/`.
6. Commit on `main` with `refactor: remove AI lyric translation`.
