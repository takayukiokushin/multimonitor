// 各テストを登録する(XCTest の代わり。名前は 各 *Tests クラスのメソッドと対応)

enum AllTests {
    static func run() {
        test("IdleTracker.testFiresOnlyAfterTimeout") { IdleTrackerTests().testFiresOnlyAfterTimeout() }
        test("IdleTracker.testDoesNotFireAgainWhileShowing") { IdleTrackerTests().testDoesNotFireAgainWhileShowing() }
        test("IdleTracker.testDisabledDisplayNeverFires") { IdleTrackerTests().testDisabledDisplayNeverFires() }
        test("IdleTracker.testRemainingTime") { IdleTrackerTests().testRemainingTime() }
        test("IdleTracker.testMovementOnTargetResets") { IdleTrackerTests().testMovementOnTargetResets() }
        test("IdleTracker.testStillCursorOnTargetCountsAsIdle") { IdleTrackerTests().testStillCursorOnTargetCountsAsIdle() }
        test("IdleTracker.testFirstSampleIsNotMovement") { IdleTrackerTests().testFirstSampleIsNotMovement() }
        test("IdleTracker.testClickOnTargetResets") { IdleTrackerTests().testClickOnTargetResets() }
        test("IdleTracker.testDismissRestartsTimer") { IdleTrackerTests().testDismissRestartsTimer() }
        test("IdleTracker.testActivityIsIgnoredWhileShowing") { IdleTrackerTests().testActivityIsIgnoredWhileShowing() }
        test("IdleTracker.testActivityOnOtherDisplayDoesNotReset") { IdleTrackerTests().testActivityOnOtherDisplayDoesNotReset() }
        test("IdleTracker.testIndependentTimersPerDisplay") { IdleTrackerTests().testIndependentTimersPerDisplay() }
        test("IdleTracker.testMovingAcrossDisplaysResetsOnlyDestination") { IdleTrackerTests().testMovingAcrossDisplaysResetsOnlyDestination() }
        test("IdleTracker.testDisplayContainingPointOnSharedEdge") { IdleTrackerTests().testDisplayContainingPointOnSharedEdge() }
        test("IdleTracker.testPauseStopsAndResumeRestarts") { IdleTrackerTests().testPauseStopsAndResumeRestarts() }
        test("IdleTracker.testResetAll") { IdleTrackerTests().testResetAll() }
        test("IdleTracker.testChangingTimeoutRestarts") { IdleTrackerTests().testChangingTimeoutRestarts() }
        test("IdleTracker.testEnablingRestarts") { IdleTrackerTests().testEnablingRestarts() }
        test("IdleTracker.testFrameChangeKeepsTimer") { IdleTrackerTests().testFrameChangeKeepsTimer() }
        test("IdleTracker.testUnchangedConfigureKeepsShowingState") { IdleTrackerTests().testUnchangedConfigureKeepsShowingState() }
        test("IdleTracker.testDisconnectedDisplayIsDropped") { IdleTrackerTests().testDisconnectedDisplayIsDropped() }
        test("Settings.testIdleMinutesAreNormalizedToChoices") { let c = SettingsTests(); try c.setUp(); defer { c.tearDown() }; c.testIdleMinutesAreNormalizedToChoices() }
        test("Settings.testSaveAndLoadRoundTrip") { let c = SettingsTests(); try c.setUp(); defer { c.tearDown() }; try c.testSaveAndLoadRoundTrip() }
        test("Settings.testMissingFileGivesDefaults") { let c = SettingsTests(); try c.setUp(); defer { c.tearDown() }; c.testMissingFileGivesDefaults() }
        test("Settings.testBrokenFileIsMovedAside") { let c = SettingsTests(); try c.setUp(); defer { c.tearDown() }; try c.testBrokenFileIsMovedAside() }
        test("Settings.testMissingKeysUseDefaults") { let c = SettingsTests(); try c.setUp(); defer { c.tearDown() }; try c.testMissingKeysUseDefaults() }
        test("Settings.testLegacyMediaPathBecomesFileSource") { let c = SettingsTests(); try c.setUp(); defer { c.tearDown() }; try c.testLegacyMediaPathBecomesFileSource() }
        test("Settings.testSlideshowMinutesAreNormalizedToChoices") { let c = SettingsTests(); try c.setUp(); defer { c.tearDown() }; c.testSlideshowMinutesAreNormalizedToChoices() }
        test("Settings.testMediaKind") { let c = SettingsTests(); try c.setUp(); defer { c.tearDown() }; c.testMediaKind() }
        test("MediaLibrary.testFolderListsSupportedFilesSortedByName") { let c = MediaLibraryTests(); try c.setUp(); defer { c.tearDown() }; try c.testFolderListsSupportedFilesSortedByName() }
        test("MediaLibrary.testFilesKeepRegistrationOrderAndSkipMissingAndDuplicates") { let c = MediaLibraryTests(); try c.setUp(); defer { c.tearDown() }; try c.testFilesKeepRegistrationOrderAndSkipMissingAndDuplicates() }
        test("MediaLibrary.testSourceStatus") { let c = MediaLibraryTests(); try c.setUp(); defer { c.tearDown() }; try c.testSourceStatus() }
        test("MediaLibrary.testSequentialAdvancesAndWraps") { let c = MediaLibraryTests(); try c.setUp(); defer { c.tearDown() }; c.testSequentialAdvancesAndWraps() }
        test("MediaLibrary.testRandomNeverRepeatsLastWhenPossible") { let c = MediaLibraryTests(); try c.setUp(); defer { c.tearDown() }; c.testRandomNeverRepeatsLastWhenPossible() }
        test("MediaLibrary.testRandomWithSingleCandidate") { let c = MediaLibraryTests(); try c.setUp(); defer { c.tearDown() }; c.testRandomWithSingleCandidate() }
        test("MediaLibrary.testNoCandidates") { let c = MediaLibraryTests(); try c.setUp(); defer { c.tearDown() }; c.testNoCandidates() }
        test("MediaLibrary.testAttemptOrder") { let c = MediaLibraryTests(); try c.setUp(); defer { c.tearDown() }; c.testAttemptOrder() }
    }
}
