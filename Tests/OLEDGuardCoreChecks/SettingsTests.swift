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
        expectEqual(DisplaySettings.normalizedIdleMinutes(40), 45)
        expectEqual(DisplaySettings.normalizedIdleMinutes(50), 60)
        expectEqual(DisplaySettings.normalizedIdleMinutes(90), 90)
        expectEqual(DisplaySettings.normalizedIdleMinutes(120), 120)
        expectEqual(DisplaySettings.normalizedIdleMinutes(200), 120)
        var settings = DisplaySettings()
        settings.idleMinutes = 33
        expectEqual(settings.idleMinutes, 45)
    }

    func testSaveAndLoadRoundTrip() throws {
        let file = SettingsFile(url: directory.appendingPathComponent("settings.json"))
        var settings = AppSettings()
        settings.displays["UUID-1"] = DisplaySettings(isEnabled: true, idleMinutes: 15, mediaSources: [MediaSource(kind: .file, path: "/tmp/a.mp4"), MediaSource(kind: .folder, path: "/tmp/pics")], selectionOrder: .sequential, slideshowEnabled: true, slideshowMinutes: 5, scaleMode: .fit, lastKnownName: "LG", lastShownPath: "/tmp/a.mp4")
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

    func testLegacyMediaPathBecomesFileSource() throws {
        let json = #"{"displays":{"X":{"isEnabled":true,"mediaPath":"/a/b.png"}}}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        expectEqual(settings.displays["X"]?.mediaSources, [MediaSource(kind: .file, path: "/a/b.png")])
        expectEqual(settings.displays["X"]?.selectionOrder, .random)
        expectEqual(settings.displays["X"]?.slideshowEnabled, false)
    }

    func testSlideshowMinutesAreNormalizedToChoices() {
        expectEqual(DisplaySettings.normalizedSlideshowMinutes(1), 1)
        expectEqual(DisplaySettings.normalizedSlideshowMinutes(2), 5)
        expectEqual(DisplaySettings.normalizedSlideshowMinutes(500), 120)
    }

    func testMediaKind() {
        expectEqual(MediaKind(url: URL(fileURLWithPath: "/a/b.HEIC")), .image)
        expectEqual(MediaKind(url: URL(fileURLWithPath: "/a/b.pdf")), .pdf)
        expectEqual(MediaKind(url: URL(fileURLWithPath: "/a/b.m4v")), .video)
        expectNil(MediaKind(url: URL(fileURLWithPath: "/a/b.gif")))
    }
}
