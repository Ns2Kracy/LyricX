import Foundation
import LyricXCore
import LyricXMac
@testable import LyricXApp

@main
struct LyricXUnitTests {
    static func main() async throws {
        try runCoreTests()
        try await runPlaybackAndMenuBarTests()
        try await runTranslationTests()
        try await runSettingsAndUpdateTests()
        print("LyricXUnitTests passed")
    }

    private static func runCoreTests() throws {
        try testParsesTimestampedLine()
        try testParsesMultipleTimestampsOnOneLine()
        try testIgnoresMetadataAndBlankLines()
        try testSortsParsedLinesByTime()
        try testParsesEnhancedInlineSegmentTimestamps()
        try testNormalTimestampedLineHasNoSegments()
        try testTimelineReturnsNilBeforeFirstLine()
        try testTimelineReturnsCurrentLineAtAndBetweenTimestamps()
        try testTimelineCanDelaySwitchWithinLeadTolerance()
        try testTimelineReturnsNextLineAfterPosition()
        try testTimelineContextReturnsPreviousCurrentAndNextLine()
        try testTranslationTimelineMatchesSourceLineByIDAndTime()
        try testTranslationTimelineRejectsSameIDWithDifferentTime()
        try testTranslationCacheKeyDiffersByLanguage()
        try testTranslationCacheSavesAndLoadsTimeline()
        try testTranslationCacheIgnoresInvalidJSON()
        try testJapaneseRomajiRomanizesKana()
        try testJapaneseRomajiRomanizesSmallTsuAndLongVowelMark()
        try testJapaneseRomajiRomanizesSmallYoonKana()
        try testJapaneseRomajiRomanizesKatakanaLoanwordSmallVowels()
        try testJapaneseRomajiReturnsNilForNonJapaneseText()
        try testJapaneseRomajiReturnsNilForKanjiText()
        try testTrackScopedLyricLoadRejectsStaleTrack()
        try testTrackScopedLyricLoadRejectsSupersededRequest()
        try testTrackScopedLyricLoadAcceptsCurrentTrack()
        try testMenuBarMarqueeKeepsShortTextWhole()
        try testMenuBarMarqueeReturnsFixedWindowForLongText()
        try testMenuBarMarqueeReturnsTimedWindowForLongLyric()
        try testMenuBarMarqueeShowsFinalWindowBeforeLineSwitch()
        try testMenuBarMarqueeCalculatesContinuousScrollOffset()
        try testMenuBarMarqueeClampsContinuousScrollProgress()
        try testMenuBarAnimationFrameRatesExposeSupportedValues()
        try testMenuBarAnimationFrameRateIntervals()
        try testMenuBarAnimationFrameRateCodableRoundTrip()
        try testTimelineMarqueeOffsetPausesBeforeMoving()
        try testTimelineMarqueeOffsetMovesAtConfiguredSpeed()
        try testTimelineMarqueeOffsetAdaptsToShortLyricDuration()
        try testTimelineMarqueeOffsetStopsAtEnd()
        try testTimelineMarqueeOffsetStaysZeroWithoutOverflow()
        try testTimelineMarqueeOffsetStaysAtEndAfterScrollCompletes()
    }

    @MainActor
    private static func runPlaybackAndMenuBarTests() async throws {
        try testSpotifyControlScriptForPlayPause()
        try testSpotifyControlScriptForNextTrack()
        try testSpotifyControlScriptForPreviousTrack()
        try testSpotifyServiceRunsControlCommand()
        try testSpotifyParseReadsArtworkURL()
        try await testSpotifyArtworkProviderLoadsArtworkData()
        try testTrackArtworkStoresPNGData()
        try testAppModelSelectsMenuBarArtworkOnlyWhenEnabled()
        try testMenuBarStatusItemArtworkOccupiesSpaceOnlyWhenDrawable()
        try testDefaultStylePresetsIncludeMenuBarCompact()
        try testStylePresetDerivesMenuBarStyle()
        try testMenuBarBehaviorUsesPresetWidth()
        try testMenuBarLayoutShrinksForShortTextWithoutAccessory()
        try testMenuBarLayoutCapsLongTextAtPresetWidth()
        try testMenuBarLayoutAddsTrailingAccessoryOnlyWhenPresent()
        try testMenuBarLayoutUsesReducedRightPaddingForArtwork()
        try testMenuBarDisplayTextUsesOriginalMode()
        try testMenuBarDisplayTextFallsBackWhenTranslationMissing()
        try testMenuBarDisplayTextUsesTranslationMode()
        try testMenuBarDisplayTextAlternatesOriginalThenTranslation()
        try testMenuBarDisplayTextAlternatesOriginalThenRomaji()
        try testMenuBarDisplayTextFallsBackToOriginalWhenRomajiMissing()
        try testMenuBarDisplayTextKeepsSourceWhenTranslationFailed()
    }

    private static func runTranslationTests() async throws {
        try await testAppModelKeepsSourceMenuBarTextWhenTranslationFails()
        try await testAppModelIgnoresStaleTranslationAfterSettingsChange()
        try await testAppModelReportsUnavailableTranslationProvider()
        try await testAppModelUsesConfiguredTranslationProvider()
        try await testProviderChainStopsAtFirstTranslatedResult()
        try await testProviderChainFallsThroughEmptyResult()
        try testOpenAICompatibleProviderParsesTranslationsByID()
        try await testOpenAICompatibleProviderRejectsMissingConfiguration()
    }

    @MainActor
    private static func runSettingsAndUpdateTests() async throws {
        try testMenuBarClickFeedbackStaysVisibleWhilePressed()
        try testMenuBarClickFeedbackIgnoresStaleReleaseTimeout()
        try testMenuBarContextMenuItemsExposeSettingsFirst()
        try testStylePresetCodableRoundTrip()
        try testStylePresetStoreSavesAndLoadsSelection()
        try testAppSettingsDefaultFrameRateIsThirtyFPS()
        try testAppSettingsDefaultsToShowingMenuBarArtwork()
        try testAppSettingsStoreSavesAndLoadsFrameRate()
        try testAppSettingsStoreSavesMenuBarArtworkPreference()
        try testAppSettingsDecodesMenuBarArtworkDefaultFromOldJSON()
        try testAppSettingsDecodesTranslationDefaultsFromOldJSON()
        try testAppModelMigratesOnlyUntouchedCompactPresetWidth()
        try testAppSettingsDecodesProviderDefaultsFromOldJSON()
        try testTranslationProviderSettingsCodableRoundTrip()
        try testMenuBarLyricDisplayModeCodableRoundTrip()
        try testTranslationLanguageCodableRoundTrip()
        try testAppVersionComparisonFindsNewerPatch()
        try testAppVersionIgnoresLeadingV()
        try testGitHubReleaseDecoderFindsPackageAsset()
        try testLRCLIBLookupURLEncodesTrackQuery()
        try testLRCLIBSearchURLEncodesTrackQuery()
    }
}
