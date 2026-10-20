import AppKit
import SwiftUI

/// SwiftUI の設定画面を載せる通常ウィンドウ。閉じても破棄せず使い回す。
@MainActor
final class SettingsWindowController {
    private let displayManager: DisplayManager
    private let appState: AppState
    private let store: SettingsStore
    private let loginItem: LoginItemController
    private let overlays: OverlayManager
    private let idleMonitor: IdleMonitor
    private var window: NSWindow?

    init(displayManager: DisplayManager, appState: AppState, store: SettingsStore,
         loginItem: LoginItemController, overlays: OverlayManager, idleMonitor: IdleMonitor) {
        self.displayManager = displayManager
        self.appState = appState
        self.store = store
        self.loginItem = loginItem
        self.overlays = overlays
        self.idleMonitor = idleMonitor
    }

    func show() {
        if window == nil {
            let root = SettingsView()
                .environmentObject(displayManager)
                .environmentObject(appState)
                .environmentObject(store)
                .environmentObject(loginItem)
                .environmentObject(overlays)
                .environmentObject(idleMonitor)
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = "OLEDGuard 設定"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 600, height: 680))
            window.center()
            self.window = window
        }
        loginItem.refresh()
        // メニューバー常駐アプリは非アクティブなので、前面に出すために明示的にアクティブにする
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
