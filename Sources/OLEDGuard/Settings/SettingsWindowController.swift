import AppKit
import SwiftUI

/// SwiftUI の設定画面を載せる通常ウィンドウ。閉じても破棄せず使い回す。
@MainActor
final class SettingsWindowController {
    private let displayManager: DisplayManager
    private let appState: AppState
    private var window: NSWindow?

    init(displayManager: DisplayManager, appState: AppState) {
        self.displayManager = displayManager
        self.appState = appState
    }

    func show() {
        if window == nil {
            let root = SettingsView()
                .environmentObject(displayManager)
                .environmentObject(appState)
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = "OLEDGuard 設定"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 560, height: 520))
            window.center()
            self.window = window
        }
        // メニューバー常駐アプリは非アクティブなので、前面に出すために明示的にアクティブにする
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
