import Foundation

/// 登録したファイル・フォルダから、待ち受けの候補を集める。
public enum MediaLibrary {
    /// 登録1件の状態(設定画面の表示用)。
    public enum SourceStatus: Equatable, Sendable {
        /// 使えるファイルの数(ファイルなら 1)
        case ok(Int)
        /// ファイル・フォルダが見つからない
        case missing
        /// 対応していない形式のファイル
        case unsupported
        /// フォルダに対応ファイルが1つもない
        case emptyFolder
    }

    /// 候補のファイル(登録順。フォルダの中は名前順。重複は除く)。存在しないものは含まない。
    public static func candidates(for sources: [MediaSource], fileManager: FileManager = .default) -> [URL] {
        var seen: Set<String> = []
        var result: [URL] = []
        for source in sources {
            for url in files(in: source, fileManager: fileManager) {
                let path = url.standardizedFileURL.path(percentEncoded: false)
                if seen.insert(path).inserted {
                    result.append(URL(fileURLWithPath: path))
                }
            }
        }
        return result
    }

    public static func status(of source: MediaSource, fileManager: FileManager = .default) -> SourceStatus {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
            return .missing
        }
        switch source.kind {
        case .file:
            if isDirectory.boolValue { return .missing }
            return MediaKind(url: source.url) == nil ? .unsupported : .ok(1)
        case .folder:
            if !isDirectory.boolValue { return .missing }
            let count = files(in: source, fileManager: fileManager).count
            return count == 0 ? .emptyFolder : .ok(count)
        }
    }

    /// フォルダは直下の対応ファイルだけを見る(サブフォルダ・隠しファイルは含めない)。
    private static func files(in source: MediaSource, fileManager: FileManager) -> [URL] {
        switch source.kind {
        case .file:
            let url = source.url
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue,
                  MediaKind(url: url) != nil else { return [] }
            return [url]
        case .folder:
            guard let contents = try? fileManager.contentsOfDirectory(
                at: source.url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            return contents
                .filter { url in
                    MediaKind(url: url) != nil
                        && ((try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false)
                }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        }
    }
}

/// 候補の中から、次に表示するものを選ぶ。
public enum MediaSelector {
    /// - Parameters:
    ///   - candidates: 候補のパス(並び順は MediaLibrary.candidates のとおり)
    ///   - last: 直前に表示したパス
    /// - Returns: 次に表示するパス。候補がなければ nil
    public static func next<R: RandomNumberGenerator>(
        from candidates: [String],
        after last: String?,
        order: SelectionOrder,
        using generator: inout R
    ) -> String? {
        guard !candidates.isEmpty else { return nil }
        switch order {
        case .sequential:
            guard let last, let index = candidates.firstIndex(of: last) else {
                return candidates[0]
            }
            return candidates[(index + 1) % candidates.count]
        case .random:
            let pool = candidates.count > 1 ? candidates.filter { $0 != last } : candidates
            return pool.randomElement(using: &generator) ?? candidates[0]
        }
    }

    /// 次のものが読み込めなかったときに順に試す並び。first を先頭に、残りを選び方に沿って並べる。
    public static func attemptOrder<R: RandomNumberGenerator>(
        startingWith first: String,
        in candidates: [String],
        order: SelectionOrder,
        using generator: inout R
    ) -> [String] {
        let others = candidates.filter { $0 != first }
        switch order {
        case .sequential:
            guard let index = candidates.firstIndex(of: first) else { return [first] + others }
            let rotated = Array(candidates[index...] + candidates[..<index])
            return rotated
        case .random:
            return [first] + others.shuffled(using: &generator)
        }
    }
}
