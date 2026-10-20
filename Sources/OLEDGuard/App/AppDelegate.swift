import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var displayManager: DisplayManager!
    private var appState: AppState!
    private var settingsStore: SettingsStore!
    private var loginItem: LoginItemController!
    private var settingsWindow: SettingsWindowController!
    private var cancellables: Set<AnyCancellable> = []

    private var pauseItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Info.plist の LSUIElement に加えて、念のためコードでも Dock 非表示にする
        NSApp.setActivationPolicy(.accessory)

        displayManager = DisplayManager()
        appState = AppState()
        settingsStore = SettingsStore()
        loginItem = LoginItemController()
        settingsWindow = SettingsWindowController(
            displayManager: displayManager,
            appState: appState,
            store: settingsStore,
            loginItem: loginItem
        )

        // 接続中モニターの名前を設定に記録しておく(未接続になったときの表示用)
        displayManager.$displays
            .sink { [weak self] displays in
                MainActor.assumeIsolated {
                    self?.settingsStore.noteConnected(displays)
                }
            }
            .store(in: &cancellables)

        setUpStatusItem()
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "moon.zzz", accessibilityDescription: "OLEDGuard")
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()

        pauseItem = NSMenuItem(title: "一時停止", action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        let settingsItem = NSMenuItem(title: "設定を開く…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // ステップ3で実装する。action が nil の間はメニュー上で無効表示になる。
        let testItem = NSMenuItem(title: "今すぐテスト表示", action: nil, keyEquivalent: "")
        menu.addItem(testItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        updatePauseItem()
    }

    @objc private func togglePause() {
        appState.isPaused.toggle()
        updatePauseItem()
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    private func updatePauseItem() {
        pauseItem.title = appState.isPaused ? "再開" : "一時停止"
        statusItem.button?.appearsDisabled = appState.isPaused
    }
}
