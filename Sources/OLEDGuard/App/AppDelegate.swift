import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var displayManager: DisplayManager!
    private var appState: AppState!
    private var settingsStore: SettingsStore!
    private var loginItem: LoginItemController!
    private var overlayManager: OverlayManager!
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
        overlayManager = OverlayManager(displayManager: displayManager, store: settingsStore)
        // テスト表示で失敗したら、警告が見えるよう設定画面を開く
        overlayManager.onMediaError = { [weak self] _, isTest in
            if isTest { self?.settingsWindow.show() }
        }
        settingsWindow = SettingsWindowController(
            displayManager: displayManager,
            appState: appState,
            store: settingsStore,
            loginItem: loginItem,
            overlays: overlayManager
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

        let testItem = NSMenuItem(title: "今すぐテスト表示", action: #selector(testOverlay), keyEquivalent: "")
        testItem.target = self
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

    /// 「待ち受けを使う」がオンの接続中モニターすべてに、待ち受けを表示する。
    @objc private func testOverlay() {
        let targets = displayManager.displays.filter {
            settingsStore.displaySettings(for: $0.uuid).isEnabled
        }
        guard !targets.isEmpty else {
            NSApp.activate()
            let alert = NSAlert()
            alert.messageText = "待ち受けを使うモニターがありません"
            alert.informativeText = "設定画面で、モニターの「待ち受けを使う」をオンにしてください。"
            alert.runModal()
            settingsWindow.show()
            return
        }
        for display in targets {
            overlayManager.show(display: display, isTest: true)
        }
    }

    private func updatePauseItem() {
        pauseItem.title = appState.isPaused ? "再開" : "一時停止"
        statusItem.button?.appearsDisabled = appState.isPaused
    }
}
