import AppKit
import OLEDGuardCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var displayManager: DisplayManager
    @EnvironmentObject private var store: SettingsStore
    @EnvironmentObject private var loginItem: LoginItemController
    @EnvironmentObject private var overlays: OverlayManager
    @EnvironmentObject private var idleMonitor: IdleMonitor
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var thumbnails: ThumbnailStore

    private var disconnectedUUIDs: [String] {
        let connected = Set(displayManager.displays.map(\.uuid))
        return store.settings.displays.keys.filter { !connected.contains($0) }.sorted()
    }

    var body: some View {
        Form {
            if DebugOptions.isShortened {
                Section {
                    WarningLabel("デバッグ: 待ち受けまでの時間を短縮中(1分 = \(Int(DebugOptions.secondsPerMinute))秒)")
                }
            }

            Section("全般") {
                Toggle("ログイン時に自動起動", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                if loginItem.needsApproval {
                    HStack {
                        WarningLabel("システム設定の「ログイン項目」で許可が必要です。")
                        Spacer()
                        Button("システム設定を開く") { loginItem.openSystemSettings() }
                    }
                }
                if let message = loginItem.errorMessage {
                    WarningLabel(message)
                }
                if let message = store.saveError {
                    WarningLabel(message)
                }
            }

            if displayManager.displays.count > DisplayManager.maxSupportedDisplays {
                Section {
                    WarningLabel("\(DisplayManager.maxSupportedDisplays)台を超えるモニターが接続されています。想定は最大\(DisplayManager.maxSupportedDisplays)台です。")
                }
            }

            if displayManager.displays.isEmpty {
                Section {
                    Text("モニターが見つかりません").foregroundStyle(.secondary)
                }
            }

            ForEach(Array(displayManager.displays.enumerated()), id: \.element.id) { index, display in
                Section("モニター \(index + 1): \(display.name)\(display.isMain ? "(メイン)" : "")") {
                    DisplaySettingsEditor(
                        settings: binding(for: display),
                        fileCheckToken: store.fileCheckToken,
                        mediaError: store.mediaErrors[display.uuid],
                        status: status(for: display.uuid),
                        onTest: { overlays.showTest(uuid: display.uuid) }
                    )
                    DisclosureGroup("モニター情報") {
                        DisplayInfoDetails(display: display)
                    }
                }
            }

            if !disconnectedUUIDs.isEmpty {
                Section("未接続のモニター(設定は保存されています)") {
                    ForEach(disconnectedUUIDs, id: \.self) { uuid in
                        DisconnectedDisplayRow(
                            uuid: uuid,
                            settings: store.displaySettings(for: uuid),
                            onRemove: { store.removeSettings(for: uuid) }
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, minHeight: 420)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.recheckFiles()
            thumbnails.invalidateAll()
        }
    }

    private func status(for uuid: String) -> String {
        if overlays.visibleUUIDs.contains(uuid) {
            return "待ち受けを表示中"
        }
        guard store.displaySettings(for: uuid).isEnabled else {
            return "無効"
        }
        if appState.isPaused {
            return "一時停止中"
        }
        guard let seconds = idleMonitor.remainingSeconds[uuid] else {
            return "判定を停止中"
        }
        return String(format: "待ち受けまで あと %ld:%02ld", seconds / 60, seconds % 60)
    }

    /// 書き込み時にモニター名も記録して、未接続になったときに名前で表示できるようにする
    private func binding(for display: DisplayInfo) -> Binding<DisplaySettings> {
        Binding(
            get: { store.displaySettings(for: display.uuid) },
            set: { newValue in
                var value = newValue
                value.lastKnownName = display.name
                if value.mediaSources != store.displaySettings(for: display.uuid).mediaSources {
                    store.clearMediaError(for: display.uuid)
                }
                store.settings.displays[display.uuid] = value
            }
        )
    }
}

/// モニター1枚分の設定項目。
private struct DisplaySettingsEditor: View {
    @EnvironmentObject private var thumbnails: ThumbnailStore
    @Binding var settings: DisplaySettings
    let fileCheckToken: Int
    let mediaError: String?
    let status: String
    let onTest: () -> Void

    var body: some View {
        let _ = fileCheckToken
        let candidateCount = MediaLibrary.candidates(for: settings.mediaSources).count

        Toggle("待ち受けを使う", isOn: $settings.isEnabled)

        LabeledContent("状態", value: status)

        Picker("待ち受けまでの時間", selection: $settings.idleMinutes) {
            ForEach(DisplaySettings.idleMinuteChoices, id: \.self) { minutes in
                Text("\(minutes) 分").tag(minutes)
            }
        }
        .pickerStyle(.menu)

        LabeledContent("待ち受けにするファイル") {
            HStack {
                Text(settings.mediaSources.isEmpty ? "未登録" : "\(candidateCount) ファイル")
                    .foregroundStyle(.secondary)
                Button("ファイルを追加…") { addFiles() }
                Button("フォルダを追加…") { addFolder() }
            }
        }

        ForEach(settings.mediaSources, id: \.self) { source in
            MediaSourceRow(
                source: source,
                status: MediaLibrary.status(of: source),
                thumbnail: thumbnail(for: source),
                onRemove: { settings.mediaSources.removeAll { $0 == source } }
            )
        }

        Picker("選び方", selection: $settings.selectionOrder) {
            Text("ランダム").tag(SelectionOrder.random)
            Text("順番(登録順・フォルダ内は名前順)").tag(SelectionOrder.sequential)
        }
        .pickerStyle(.menu)

        Toggle("表示中も切り替える", isOn: $settings.slideshowEnabled)

        Picker("切り替える間隔", selection: $settings.slideshowMinutes) {
            ForEach(DisplaySettings.slideshowMinuteChoices, id: \.self) { minutes in
                Text("\(minutes) 分").tag(minutes)
            }
        }
        .pickerStyle(.menu)
        .disabled(!settings.slideshowEnabled)

        Picker("表示方法", selection: $settings.scaleMode) {
            Text("フィル(画面全体を覆う)").tag(ScaleMode.fill)
            Text("フィット(全体を表示)").tag(ScaleMode.fit)
        }
        .pickerStyle(.menu)

        ForEach(warnings(candidateCount: candidateCount), id: \.self) { message in
            WarningLabel(message)
        }

        HStack {
            Spacer()
            Button("今すぐテスト表示", action: onTest)
                .help("このモニターに待ち受けを表示します。クリックで閉じます。")
        }
    }

    private func thumbnail(for source: MediaSource) -> NSImage? {
        guard source.kind == .file,
              FileManager.default.fileExists(atPath: source.path) else { return nil }
        return thumbnails.thumbnail(for: source.url)
    }

    private func warnings(candidateCount: Int) -> [String] {
        var result: [String] = []
        if let mediaError {
            result.append("表示できなかったファイルがあります: \(mediaError)")
        }
        let problems = settings.mediaSources.filter {
            if case .ok = MediaLibrary.status(of: $0) { return false }
            return true
        }
        if !problems.isEmpty {
            result.append("見つからない、または使えないファイル・フォルダがあります。移動・名前の変更・削除をしていないか確認してください。")
        }
        if settings.isEnabled && candidateCount == 0 {
            if settings.mediaSources.isEmpty {
                result.append("ファイルが登録されていません。待ち受けは黒い画面になります。")
            } else {
                result.append("使えるファイルが1つもありません。待ち受けは黒い画面になります。")
            }
        }
        return result
    }

    private func addFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = MediaKind.allExtensions.sorted().compactMap { UTType(filenameExtension: $0) }
        panel.message = "待ち受けに使う画像(JPEG / PNG / HEIC / PDF)・動画(MP4 / MOV / M4V)を選んでください(複数選択できます)"
        panel.prompt = "追加"
        if let last = settings.mediaSources.last {
            panel.directoryURL = last.kind == .folder ? last.url : last.url.deletingLastPathComponent()
        }
        guard panel.runModal() == .OK else { return }
        add(panel.urls.map { MediaSource(kind: .file, path: $0.path(percentEncoded: false)) })
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "フォルダを選ぶと、中の画像・動画(サブフォルダは除く)がすべて候補になります"
        panel.prompt = "追加"
        guard panel.runModal() == .OK else { return }
        add(panel.urls.map { MediaSource(kind: .folder, path: $0.path(percentEncoded: false)) })
    }

    private func add(_ sources: [MediaSource]) {
        var updated = settings.mediaSources
        for source in sources where !updated.contains(source) {
            updated.append(source)
        }
        settings.mediaSources = updated
    }
}

/// 登録したファイル・フォルダ1件分の行。
private struct MediaSourceRow: View {
    let source: MediaSource
    let status: MediaLibrary.SourceStatus
    let thumbnail: NSImage?
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                if source.kind == .folder {
                    Image(systemName: "folder.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                } else if let thumbnail {
                    Color.black
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "doc")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(source.url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(isProblem ? Color.orange : Color.secondary)
            }
            .help(source.path)

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("登録から外す(ファイル自体は消えません)")
        }
    }

    private var isProblem: Bool {
        if case .ok = status { return false }
        return true
    }

    private var detail: String {
        switch status {
        case .ok(let count):
            if source.kind == .folder {
                return "フォルダ・\(count) ファイル"
            }
            switch MediaKind(url: source.url) {
            case .video: return "動画"
            case .pdf: return "PDF"
            default: return "画像"
            }
        case .missing:
            return source.kind == .folder ? "フォルダが見つかりません" : "ファイルが見つかりません"
        case .unsupported:
            return "対応していない形式です"
        case .emptyFolder:
            return "フォルダに対応ファイルがありません"
        }
    }
}

private struct DisconnectedDisplayRow: View {
    let uuid: String
    let settings: DisplaySettings
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(settings.lastKnownName ?? "名前不明のモニター").font(.headline)
                Text(summary).font(.caption).foregroundStyle(.secondary)
                Text(uuid)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            Button("設定を削除", role: .destructive, action: onRemove)
        }
    }

    private var summary: String {
        let state = settings.isEnabled ? "有効" : "無効"
        let files = settings.mediaSources.isEmpty ? "ファイル未登録" : "\(settings.mediaSources.count) 件登録"
        return "\(state) / \(settings.idleMinutes) 分 / \(files)"
    }
}

private struct DisplayInfoDetails: View {
    let display: DisplayInfo

    var body: some View {
        LabeledContent("解像度", value: "\(display.pixelWidth) × \(display.pixelHeight) px")
        LabeledContent("表示サイズ", value: "\(Int(display.frame.width)) × \(Int(display.frame.height)) pt")
        LabeledContent("位置", value: "x: \(Int(display.frame.minX)), y: \(Int(display.frame.minY))")
        LabeledContent("リフレッシュレート", value: String(format: "%.0f Hz", display.refreshRate))
        LabeledContent("UUID") {
            Text(display.uuid)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}

struct WarningLabel: View {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
    }
}
