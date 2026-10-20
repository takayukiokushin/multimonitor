import Foundation
import XCTest
@testable import OLEDGuardCore

final class SettingsTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OLEDGuardTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testIdleMinutesAreNormalizedToChoices() {
        XCTAssertEqual(DisplaySettings.normalizedIdleMinutes(5), 5)
        XCTAssertEqual(DisplaySettings.normalizedIdleMinutes(7), 10)
        XCTAssertEqual(DisplaySettings.normalizedIdleMinutes(0), 5)
        XCTAssertEqual(DisplaySettings.normalizedIdleMinutes(90), 60)
        var settings = DisplaySettings()
        settings.idleMinutes = 33
        XCTAssertEqual(settings.idleMinutes, 40)
    }

    func testSaveAndLoadRoundTrip() throws {
        let file = SettingsFile(url: directory.appendingPathComponent("settings.json"))
        var settings = AppSettings()
        settings.displays["UUID-1"] = DisplaySettings(isEnabled: true, idleMinutes: 15, mediaPath: "/tmp/a.mp4", scaleMode: .fit, lastKnownName: "LG")
        settings.displays["UUID-2"] = DisplaySettings()
        try file.save(settings)
        XCTAssertEqual(file.load(), settings)
    }

    func testMissingFileGivesDefaults() {
        let file = SettingsFile(url: directory.appendingPathComponent("none.json"))
        XCTAssertEqual(file.load(), AppSettings())
    }

    func testBrokenFileIsMovedAside() throws {
        let url = directory.appendingPathComponent("settings.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        XCTAssertEqual(SettingsFile(url: url).load(), AppSettings())
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.appendingPathExtension("broken").path))
    }

    func testMissingKeysUseDefaults() throws {
        let json = #"{"displays":{"X":{"isEnabled":true}}}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.displays["X"], DisplaySettings(isEnabled: true))
    }

    func testMediaKind() {
        XCTAssertEqual(MediaKind(url: URL(fileURLWithPath: "/a/b.HEIC")), .image)
        XCTAssertEqual(MediaKind(url: URL(fileURLWithPath: "/a/b.pdf")), .pdf)
        XCTAssertEqual(MediaKind(url: URL(fileURLWithPath: "/a/b.m4v")), .video)
        XCTAssertNil(MediaKind(url: URL(fileURLWithPath: "/a/b.gif")))
    }
}
