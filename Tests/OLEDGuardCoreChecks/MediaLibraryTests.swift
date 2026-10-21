import Foundation
import OLEDGuardCore

/// 毎回同じ並びになる乱数(テスト用)
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class MediaLibraryTests {
    private var directory: URL!

    func setUp() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OLEDGuardMedia-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    @discardableResult
    private func makeFile(_ name: String, in folder: URL? = nil) throws -> URL {
        let url = (folder ?? directory).appendingPathComponent(name)
        try Data("x".utf8).write(to: url)
        return url
    }

    private func path(_ url: URL) -> String {
        url.standardizedFileURL.path(percentEncoded: false)
    }

    // MARK: - 候補の収集

    func testFolderListsSupportedFilesSortedByName() throws {
        let folder = directory.appendingPathComponent("pics", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try makeFile("img10.jpg", in: folder)
        try makeFile("img2.png", in: folder)
        try makeFile("clip.MOV", in: folder)
        try makeFile("notes.txt", in: folder)
        try makeFile(".hidden.jpg", in: folder)
        let sub = folder.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try makeFile("inner.jpg", in: sub)

        let names = MediaLibrary.candidates(for: [MediaSource(kind: .folder, path: folder.path)]).map(\.lastPathComponent)
        expectEqual(names, ["clip.MOV", "img2.png", "img10.jpg"])
        expectEqual(MediaLibrary.status(of: MediaSource(kind: .folder, path: folder.path)), .ok(3))
    }

    func testFilesKeepRegistrationOrderAndSkipMissingAndDuplicates() throws {
        let b = try makeFile("b.jpg")
        let a = try makeFile("a.mp4")
        let sources = [
            MediaSource(kind: .file, path: b.path),
            MediaSource(kind: .file, path: directory.appendingPathComponent("gone.png").path),
            MediaSource(kind: .file, path: a.path),
            MediaSource(kind: .folder, path: directory.path), // b.jpg・a.mp4 は重複として除く
        ]
        expectEqual(MediaLibrary.candidates(for: sources).map(\.lastPathComponent), ["b.jpg", "a.mp4"])
    }

    func testSourceStatus() throws {
        let image = try makeFile("a.heic")
        let text = try makeFile("a.txt")
        let empty = directory.appendingPathComponent("empty", isDirectory: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)

        expectEqual(MediaLibrary.status(of: MediaSource(kind: .file, path: image.path)), .ok(1))
        expectEqual(MediaLibrary.status(of: MediaSource(kind: .file, path: text.path)), .unsupported)
        expectEqual(MediaLibrary.status(of: MediaSource(kind: .file, path: directory.appendingPathComponent("x.png").path)), .missing)
        expectEqual(MediaLibrary.status(of: MediaSource(kind: .folder, path: empty.path)), .emptyFolder)
        expectEqual(MediaLibrary.status(of: MediaSource(kind: .folder, path: directory.appendingPathComponent("none").path)), .missing)
    }

    // MARK: - 選び方

    func testSequentialAdvancesAndWraps() {
        var generator = SeededGenerator(seed: 1)
        let list = ["a", "b", "c"]
        expectEqual(MediaSelector.next(from: list, after: nil, order: .sequential, using: &generator), "a")
        expectEqual(MediaSelector.next(from: list, after: "a", order: .sequential, using: &generator), "b")
        expectEqual(MediaSelector.next(from: list, after: "c", order: .sequential, using: &generator), "a")
        // 前回のファイルが登録から外れていたら最初から
        expectEqual(MediaSelector.next(from: list, after: "zzz", order: .sequential, using: &generator), "a")
    }

    func testRandomNeverRepeatsLastWhenPossible() {
        var generator = SeededGenerator(seed: 42)
        let list = (1...20).map { "img\($0)" }
        var last: String? = nil
        var seen: Set<String> = []
        for _ in 0..<500 {
            let next = MediaSelector.next(from: list, after: last, order: .random, using: &generator)
            expectTrue(next != nil && next != last)
            if let next { seen.insert(next) }
            last = next
        }
        // 500回選べば、20枚すべてが一度は出る
        expectEqual(seen.count, 20)
    }

    func testRandomWithSingleCandidate() {
        var generator = SeededGenerator(seed: 7)
        expectEqual(MediaSelector.next(from: ["only"], after: "only", order: .random, using: &generator), "only")
    }

    func testNoCandidates() {
        var generator = SeededGenerator(seed: 7)
        expectNil(MediaSelector.next(from: [], after: nil, order: .random, using: &generator))
        expectNil(MediaSelector.next(from: [], after: "a", order: .sequential, using: &generator))
    }

    func testAttemptOrder() {
        var generator = SeededGenerator(seed: 3)
        let list = ["a", "b", "c", "d"]
        expectEqual(MediaSelector.attemptOrder(startingWith: "c", in: list, order: .sequential, using: &generator), ["c", "d", "a", "b"])
        let random = MediaSelector.attemptOrder(startingWith: "b", in: list, order: .random, using: &generator)
        expectEqual(random.first, "b")
        expectEqual(Set(random), Set(list))
        expectEqual(random.count, 4)
    }
}
