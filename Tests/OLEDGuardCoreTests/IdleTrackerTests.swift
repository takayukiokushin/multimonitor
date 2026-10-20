import CoreGraphics
import Foundation
import XCTest
@testable import OLEDGuardCore

final class IdleTrackerTests: XCTestCase {
    // 左: A(1920x1200)、右: B(1920x1200)、その右: C(2560x1440)
    private let frameA = CGRect(x: 0, y: 0, width: 1920, height: 1200)
    private let frameB = CGRect(x: 1920, y: 0, width: 1920, height: 1200)
    private let frameC = CGRect(x: 3840, y: 0, width: 2560, height: 1440)
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    private func display(_ uuid: String, _ frame: CGRect, enabled: Bool = true, timeout: TimeInterval = 300) -> TrackedDisplay {
        TrackedDisplay(uuid: uuid, frame: frame, isEnabled: enabled, timeout: timeout)
    }

    private func makeTracker(_ displays: [TrackedDisplay]) -> IdleTracker {
        let tracker = IdleTracker()
        tracker.configure(displays, now: start)
        return tracker
    }

    // MARK: - 経過時間

    func testFiresOnlyAfterTimeout() {
        let tracker = makeTracker([display("A", frameA, timeout: 300)])
        XCTAssertEqual(tracker.tick(now: at(299)), [])
        XCTAssertEqual(tracker.tick(now: at(300)), ["A"])
    }

    func testDoesNotFireAgainWhileShowing() {
        let tracker = makeTracker([display("A", frameA, timeout: 300)])
        XCTAssertEqual(tracker.tick(now: at(300)), ["A"])
        XCTAssertTrue(tracker.isShowingOverlay("A"))
        XCTAssertEqual(tracker.tick(now: at(1000)), [])
    }

    func testDisabledDisplayNeverFires() {
        let tracker = makeTracker([display("A", frameA, enabled: false, timeout: 300)])
        XCTAssertEqual(tracker.tick(now: at(10_000)), [])
        XCTAssertNil(tracker.remainingTime(for: "A", now: at(10)))
    }

    func testRemainingTime() {
        let tracker = makeTracker([display("A", frameA, timeout: 300)])
        XCTAssertEqual(tracker.remainingTime(for: "A", now: at(100)), 200)
        XCTAssertEqual(tracker.remainingTime(for: "A", now: at(400)), 0)
    }

    // MARK: - リセット

    func testMovementOnTargetResets() {
        let tracker = makeTracker([display("A", frameA, timeout: 300)])
        tracker.mouseMoved(to: CGPoint(x: 100, y: 100), now: at(0))
        tracker.mouseMoved(to: CGPoint(x: 120, y: 100), now: at(200))
        XCTAssertEqual(tracker.tick(now: at(300)), [])
        XCTAssertEqual(tracker.tick(now: at(500)), ["A"])
    }

    func testStillCursorOnTargetCountsAsIdle() {
        let tracker = makeTracker([display("A", frameA, timeout: 300)])
        for second in stride(from: 0.0, through: 300.0, by: 1.0) {
            tracker.mouseMoved(to: CGPoint(x: 100, y: 100), now: at(second))
        }
        XCTAssertEqual(tracker.tick(now: at(300)), ["A"])
    }

    func testFirstSampleIsNotMovement() {
        let tracker = makeTracker([display("A", frameA, timeout: 300)])
        tracker.mouseMoved(to: CGPoint(x: 100, y: 100), now: at(200))
        XCTAssertEqual(tracker.tick(now: at(300)), ["A"])
    }

    func testClickOnTargetResets() {
        let tracker = makeTracker([display("A", frameA, timeout: 300)])
        tracker.mouseClicked(at: CGPoint(x: 10, y: 10), now: at(250))
        XCTAssertEqual(tracker.tick(now: at(300)), [])
        XCTAssertEqual(tracker.tick(now: at(550)), ["A"])
    }

    func testDismissRestartsTimer() {
        let tracker = makeTracker([display("A", frameA, timeout: 300)])
        XCTAssertEqual(tracker.tick(now: at(300)), ["A"])
        tracker.overlayDismissed("A", now: at(400))
        XCTAssertFalse(tracker.isShowingOverlay("A"))
        XCTAssertEqual(tracker.tick(now: at(699)), [])
        XCTAssertEqual(tracker.tick(now: at(700)), ["A"])
    }

    func testActivityIsIgnoredWhileShowing() {
        let tracker = makeTracker([display("A", frameA, timeout: 300)])
        XCTAssertEqual(tracker.tick(now: at(300)), ["A"])
        tracker.mouseClicked(at: CGPoint(x: 10, y: 10), now: at(350))
        XCTAssertTrue(tracker.isShowingOverlay("A"))
        XCTAssertNil(tracker.remainingTime(for: "A", now: at(350)))
    }

    // MARK: - 複数モニター

    func testActivityOnOtherDisplayDoesNotReset() {
        let tracker = makeTracker([display("A", frameA, timeout: 300), display("B", frameB, timeout: 300)])
        // B の上でずっと作業している
        tracker.mouseMoved(to: CGPoint(x: 2000, y: 100), now: at(0))
        for second in stride(from: 1.0, through: 300.0, by: 1.0) {
            tracker.mouseMoved(to: CGPoint(x: 2000 + second, y: 100), now: at(second))
            tracker.mouseClicked(at: CGPoint(x: 2000 + second, y: 100), now: at(second))
        }
        XCTAssertEqual(tracker.tick(now: at(300)), ["A"])
    }

    func testIndependentTimersPerDisplay() {
        let tracker = makeTracker([
            display("A", frameA, timeout: 300),
            display("B", frameB, timeout: 600),
            display("C", frameC, timeout: 300),
        ])
        tracker.mouseClicked(at: CGPoint(x: 4000, y: 100), now: at(200)) // C を触る
        XCTAssertEqual(tracker.tick(now: at(300)), ["A"])
        XCTAssertEqual(tracker.tick(now: at(500)), ["C"])
        XCTAssertEqual(tracker.tick(now: at(600)), ["B"])
    }

    func testMovingAcrossDisplaysResetsOnlyDestination() {
        let tracker = makeTracker([display("A", frameA, timeout: 300), display("B", frameB, timeout: 300)])
        tracker.mouseMoved(to: CGPoint(x: 100, y: 100), now: at(0))
        tracker.mouseMoved(to: CGPoint(x: 2500, y: 100), now: at(100)) // A から B へ移動
        XCTAssertEqual(tracker.tick(now: at(300)), ["A"])
        XCTAssertEqual(tracker.tick(now: at(400)), ["B"])
    }

    func testDisplayContainingPointOnSharedEdge() {
        let tracker = makeTracker([display("A", frameA), display("B", frameB)])
        XCTAssertEqual(tracker.displayUUID(containing: CGPoint(x: 1920, y: 100)), "B")
        XCTAssertEqual(tracker.displayUUID(containing: CGPoint(x: 1919.5, y: 100)), "A")
        // 上端ちょうど(contains では外れる位置)
        XCTAssertEqual(tracker.displayUUID(containing: CGPoint(x: 100, y: 1200)), "A")
        XCTAssertNil(tracker.displayUUID(containing: CGPoint(x: 100, y: 5000)))
    }

    // MARK: - 一時停止

    func testPauseStopsAndResumeRestarts() {
        let tracker = makeTracker([display("A", frameA, timeout: 300)])
        tracker.setPaused(true, now: at(100))
        XCTAssertEqual(tracker.tick(now: at(1000)), [])
        XCTAssertNil(tracker.remainingTime(for: "A", now: at(1000)))
        tracker.setPaused(false, now: at(1000))
        XCTAssertEqual(tracker.tick(now: at(1299)), [])
        XCTAssertEqual(tracker.tick(now: at(1300)), ["A"])
    }

    func testResetAll() {
        let tracker = makeTracker([display("A", frameA, timeout: 300), display("B", frameB, timeout: 300)])
        tracker.resetAll(now: at(250))
        XCTAssertEqual(tracker.tick(now: at(500)), [])
        XCTAssertEqual(tracker.tick(now: at(550)), ["A", "B"])
    }

    // MARK: - 設定変更

    func testChangingTimeoutRestarts() {
        let tracker = makeTracker([display("A", frameA, timeout: 300)])
        tracker.configure([display("A", frameA, timeout: 600)], now: at(200))
        XCTAssertEqual(tracker.tick(now: at(700)), [])
        XCTAssertEqual(tracker.tick(now: at(800)), ["A"])
    }

    func testEnablingRestarts() {
        let tracker = makeTracker([display("A", frameA, enabled: false, timeout: 300)])
        tracker.configure([display("A", frameA, enabled: true, timeout: 300)], now: at(1000))
        XCTAssertEqual(tracker.tick(now: at(1200)), [])
        XCTAssertEqual(tracker.tick(now: at(1300)), ["A"])
    }

    func testFrameChangeKeepsTimer() {
        let tracker = makeTracker([display("A", frameA, timeout: 300)])
        // モニターの並び順を変えた
        tracker.configure([display("A", frameB, timeout: 300)], now: at(200))
        XCTAssertEqual(tracker.tick(now: at(300)), ["A"])
    }

    func testUnchangedConfigureKeepsShowingState() {
        let tracker = makeTracker([display("A", frameA, timeout: 300)])
        XCTAssertEqual(tracker.tick(now: at(300)), ["A"])
        tracker.configure([display("A", frameA, timeout: 300)], now: at(310))
        XCTAssertTrue(tracker.isShowingOverlay("A"))
    }

    func testDisconnectedDisplayIsDropped() {
        let tracker = makeTracker([display("A", frameA, timeout: 300), display("B", frameB, timeout: 300)])
        tracker.configure([display("A", frameA, timeout: 300)], now: at(100))
        XCTAssertEqual(tracker.tick(now: at(1000)), ["A"])
        XCTAssertNil(tracker.displayUUID(containing: CGPoint(x: 2500, y: 100)))
    }
}
