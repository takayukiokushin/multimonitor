import AppKit
import Combine

/// 接続中のモニター一覧を保持し、接続・切断・配置変更を検知して更新する。
@MainActor
final class DisplayManager: ObservableObject {
    /// 想定する最大枚数。超えた分も一覧には出すが、設定画面で注意を表示する。
    static let maxSupportedDisplays = 3

    @Published private(set) var displays: [DisplayInfo] = []

    private var observer: NSObjectProtocol?

    init() {
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    func refresh() {
        // 左から右(同じなら下から上)の並びにそろえる
        let list = NSScreen.screens
            .compactMap(DisplayInfo.init(screen:))
            .sorted { ($0.frame.minX, $0.frame.minY) < ($1.frame.minX, $1.frame.minY) }
        if list != displays {
            displays = list
        }
    }

    func display(withUUID uuid: String) -> DisplayInfo? {
        displays.first { $0.uuid == uuid }
    }
}
