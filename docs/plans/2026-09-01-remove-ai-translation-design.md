# Remove AI Translation Design

## Scope

Remove the OpenAI-compatible machine-translation feature while preserving non-AI lyric enrichment: existing translated lyrics, provider-chain support for lyric sources, translation display and cache behavior, and Japanese romaji.

## Changes

- Remove OpenAI-compatible request/response code and provider registration.
- Remove machine-provider settings, credentials, and settings UI.
- Remove the machine-translation-only source mode.
- Keep generic lyric-source provider interfaces and the NetEase/QQ roadmap controls.
- Map persisted `machineTranslationOnly` settings to `Auto`; ignore obsolete OpenAI fields during decoding.
- Remove OpenAI-specific tests and retain coverage for provider chaining, translation fallback, settings compatibility, and romaji.

## Verification

- A regression test proves legacy machine-only settings migrate to `Auto`.
- Source searches find no OpenAI or machine-translation public symbols in production code.
- The full Swift test executable and package build pass.
