import Combine
import Foundation
import OLEDGuardCore

/// 設定を保持し、変更されるたびに JSON へ保存する。
@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            if settings != oldValue { save() }
        }
    }
    @Published private(set) var saveError: String?
    /// 増えるたびに設定画面がファイルの有無を確認し直す。
    /// (@State は SwiftUI のマクロで、コマンドラインツールだけの環境ではビルドできないため使わない)
    @Published private(set) var fileCheckToken = 0
    /// 待ち受けの読み込みに失敗したときのメッセージ(UUID ごと、保存しない)
    @Published private(set) var mediaErrors: [String: String] = [:]

    private let file: SettingsFile

    init(file: SettingsFile = SettingsFile()) {
        self.file = file
        self.settings = file.load()
    }

    func displaySettings(for uuid: String) -> DisplaySettings {
        settings.displays[uuid] ?? DisplaySettings()
    }

    /// 接続中モニターの名前を、すでに設定があるものだけ記録しておく(未接続時の表示用)。
    func noteConnected(_ displays: [DisplayInfo]) {
        var updated = settings
        for display in displays where updated.displays[display.uuid] != nil {
            updated.displays[display.uuid]?.lastKnownName = display.name
        }
        settings = updated
    }

    func removeSettings(for uuid: String) {
        settings.displays[uuid] = nil
    }

    func setMediaError(_ message: String, for uuid: String) {
        mediaErrors[uuid] = message
    }

    func clearMediaError(for uuid: String) {
        mediaErrors[uuid] = nil
    }

    func recheckFiles() {
        fileCheckToken += 1
    }

    private func save() {
        do {
            try file.save(settings)
            saveError = nil
        } catch {
            saveError = "設定を保存できませんでした: \(error.localizedDescription)"
        }
    }
}
