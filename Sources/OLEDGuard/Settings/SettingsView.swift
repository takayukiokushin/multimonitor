import AppKit
import OLEDGuardCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var displayManager: DisplayManager
    @EnvironmentObject private var store: SettingsStore
    @EnvironmentObject private var loginItem: LoginItemController

    /// アプリが前面に戻るたびに増やし、ファイルの有無を確認し直すきっかけにする
    @State private var fileCheckToken = 0

    private var disconnectedUUIDs: [String] {
        let connected = Set(displayManager.displays.map(\.uuid))
        return store.settings.displays.keys.filter { !connected.contains($0) }.sorted()
    }

    var body: some View {
        Form {
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
                        fileCheckToken: fileCheckToken
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
            fileCheckToken += 1
        }
    }

    /// 書き込み時にモニター名も記録して、未接続になったときに名前で表示できるようにする
    private func binding(for display: DisplayInfo) -> Binding<DisplaySettings> {
        Binding(
            get: { store.displaySettings(for: display.uuid) },
            set: { newValue in
                var value = newValue
                value.lastKnownName = display.name
                store.settings.displays[display.uuid] = value
            }
        )
    }
}

/// モニター1枚分の設定項目。
private struct DisplaySettingsEditor: View {
    @Binding var settings: DisplaySettings
    let fileCheckToken: Int

    var body: some View {
        Toggle("待ち受けを使う", isOn: $settings.isEnabled)

        Picker("待ち受けまでの時間", selection: $settings.idleMinutes) {
            ForEach(DisplaySettings.idleMinuteChoices, id: \.self) { minutes in
                Text("\(minutes) 分").tag(minutes)
            }
        }
        .pickerStyle(.menu)

        LabeledContent("ファイル") {
            HStack {
                Text(settings.mediaURL?.lastPathComponent ?? "未選択")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(settings.mediaURL == nil ? HierarchicalShapeStyle.secondary : HierarchicalShapeStyle.primary)
                    .help(settings.mediaPath ?? "")
                Button("選択…") { chooseFile() }
                if settings.mediaPath != nil {
                    Button("クリア") { settings.mediaPath = nil }
                }
            }
        }

        Picker("表示方法", selection: $settings.scaleMode) {
            Text("フィル(画面全体を覆う)").tag(ScaleMode.fill)
            Text("フィット(全体を表示)").tag(ScaleMode.fit)
        }
        .pickerStyle(.menu)

        ForEach(warnings, id: \.self) { message in
            WarningLabel(message)
        }
    }

    private var warnings: [String] {
        _ = fileCheckToken
        var result: [String] = []
        if let url = settings.mediaURL {
            if MediaKind(url: url) == nil {
                result.append("対応していない形式のファイルです: \(url.lastPathComponent)")
            } else if !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                result.append("ファイルが見つかりません。移動・名前の変更・削除をしていないか確認してください: \(url.path(percentEncoded: false))")
            }
        } else if settings.isEnabled {
            result.append("ファイルが選ばれていません。待ち受けは黒い画面になります。")
        }
        return result
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = MediaKind.allExtensions.sorted().compactMap { UTType(filenameExtension: $0) }
        panel.message = "待ち受けに使う画像(JPEG / PNG / HEIC / PDF)または動画(MP4 / MOV / M4V)を選んでください"
        if let current = settings.mediaURL {
            panel.directoryURL = current.deletingLastPathComponent()
        }
        if panel.runModal() == .OK, let url = panel.url {
            settings.mediaPath = url.path(percentEncoded: false)
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
        let file = settings.mediaURL?.lastPathComponent ?? "ファイル未選択"
        return "\(state) / \(settings.idleMinutes) 分 / \(file)"
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
