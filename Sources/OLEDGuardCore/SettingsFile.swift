import Foundation

/// 設定を JSON ファイルに保存・復元する。
public struct SettingsFile: Sendable {
    public let url: URL

    public init(url: URL = SettingsFile.defaultURL) {
        self.url = url
    }

    /// ~/Library/Application Support/OLEDGuard/settings.json
    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("OLEDGuard", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    /// ファイルがなければ既定値。壊れていたら .broken に退避して既定値で始める。
    public func load() -> AppSettings {
        guard let data = try? Data(contentsOf: url) else { return AppSettings() }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            let backup = url.appendingPathExtension("broken")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            return AppSettings()
        }
    }

    public func save(_ settings: AppSettings) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: url, options: .atomic)
    }
}
