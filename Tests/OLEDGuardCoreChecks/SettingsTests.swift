import Foundation
import OLEDGuardCore

final class SettingsTests {
    private var directory: URL!

    func setUp() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OLEDGuardTests-\(UUID().uuidString)", isDirectory: true)
    }

    func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func testIdleMinutesAreNormalizedToChoices() {
        expectEqual(DisplaySettings.normalizedIdleMinutes(5), 5)
        expectEqual(DisplaySettings.normalizedIdleMinutes(7), 10)
        expectEqual(DisplaySettings.normalizedIdleMinutes(0), 5)
        expectEqual(DisplaySettings.normalizedIdleMinutes(90), 60)
        var settings = DisplaySettings()
        settings.idleMinutes = 33
        expectEqual(settings.idleMinutes, 40)
    }

    func testSaveAndLoadRoundTrip() throws {
        let file = SettingsFile(url: directory.appendingPathComponent("settings.json"))
        var settings = AppSettings()
        settings.displays["UUID-1"] = DisplaySettings(isEnabled: true, idleMinutes: 15, mediaPath: "/tmp/a.mp4", scaleMode: .fit, lastKnownName: "LG")
        settings.displays["UUID-2"] = DisplaySettings()
        try file.save(settings)
        expectEqual(file.load(), settings)
    }

    func testMissingFileGivesDefaults() {
        let file = SettingsFile(url: directory.appendingPathComponent("none.json"))
        expectEqual(file.load(), AppSettings())
    }

    func testBrokenFileIsMovedAside() throws {
        let url = directory.appendingPathComponent("settings.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        expectEqual(SettingsFile(url: url).load(), AppSettings())
        expectTrue(FileManager.default.fileExists(atPath: url.appendingPathExtension("broken").path))
    }

    func testMissingKeysUseDefaults() throws {
        let json = #"{"displays":{"X":{"isEnabled":true}}}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        expectEqual(settings.displays["X"], DisplaySettings(isEnabled: true))
    }

    func testMediaKind() {
        expectEqual(MediaKind(url: URL(fileURLWithPath: "/a/b.HEIC")), .image)
        expectEqual(MediaKind(url: URL(fileURLWithPath: "/a/b.pdf")), .pdf)
        expectEqual(MediaKind(url: URL(fileURLWithPath: "/a/b.m4v")), .video)
        expectNil(MediaKind(url: URL(fileURLWithPath: "/a/b.gif")))
    }
}
