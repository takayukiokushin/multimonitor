import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var displayManager: DisplayManager

    var body: some View {
        Form {
            Section("接続中のモニター(\(displayManager.displays.count)台)") {
                if displayManager.displays.isEmpty {
                    Text("モニターが見つかりません")
                        .foregroundStyle(.secondary)
                }
                ForEach(displayManager.displays) { display in
                    DisplayInfoRow(display: display)
                }
            }

            if displayManager.displays.count > DisplayManager.maxSupportedDisplays {
                Section {
                    Label(
                        "\(DisplayManager.maxSupportedDisplays)台を超えるモニターが接続されています。想定は最大\(DisplayManager.maxSupportedDisplays)台です。",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 360)
    }
}

private struct DisplayInfoRow: View {
    let display: DisplayInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "display")
                Text(display.name).font(.headline)
                if display.isMain {
                    Text("メイン")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2), in: Capsule())
                }
            }
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
        .padding(.vertical, 4)
    }
}
