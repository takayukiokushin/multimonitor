import AppKit
import Combine
import OLEDGuardCore

/// モニターごとの待ち受けウィンドウを出し入れする。
@MainActor
final class OverlayManager: ObservableObject {
    enum DismissReason {
        /// 待ち受けをクリックした
        case click
        /// スリープ・画面ロック・ディスプレイ構成の変更など
        case system
    }

    /// 待ち受けを表示中のモニター(UUID)
    @Published private(set) var visibleUUIDs: Set<String> = []

    /// 待ち受けが閉じたとき、または出せなかったとき(無操作タイマーのやり直しに使う)
    var onDismiss: (@MainActor (String, DismissReason) -> Void)?
    /// 読み込みに失敗したとき。isTest は「今すぐテスト表示」からかどうか
    var onMediaError: (@MainActor (String, Bool) -> Void)?

    private let displayManager: DisplayManager
    private let store: SettingsStore
    private var panels: [String: OverlayPanel] = [:]
    /// 読み込み中のモニターと、その読み込みの識別子(途中で閉じられたら結果を捨てる)
    private var pendingLoads: [String: UUID] = [:]
    private var playbacks: [String: VideoPlayback] = [:]
    /// 動画の再生中だけ動かす、失敗の見張り
    private var healthTimer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init(displayManager: DisplayManager, store: SettingsStore) {
        self.displayManager = displayManager
        self.store = store
        observeSystemEvents()
    }

    func isActive(_ uuid: String) -> Bool {
        panels[uuid] != nil || pendingLoads[uuid] != nil
    }

    /// 「今すぐテスト表示」。設定の有効/無効に関係なく表示する。
    func showTest(uuid: String) {
        guard let display = displayManager.display(withUUID: uuid) else { return }
        show(display: display, isTest: true)
    }

    func show(display: DisplayInfo, isTest: Bool) {
        let uuid = display.uuid
        guard !isActive(uuid) else { return }

        let settings = store.displaySettings(for: uuid)
        let target = CGSize(width: display.pixelWidth, height: display.pixelHeight)
        let token = UUID()
        pendingLoads[uuid] = token

        Task {
            let result = await MediaLoader.load(settings: settings, targetPixelSize: target)
            guard pendingLoads[uuid] == token else {
                // 読み込み中に閉じられた。用意した動画は捨てる
                if case .success(.video(let playback)) = result { playback.stop() }
                return
            }
            pendingLoads[uuid] = nil

            switch result {
            case .success(let content):
                // 読み込み中に切断・配置変更されていたら、最新の位置で出す
                guard let current = displayManager.display(withUUID: uuid) else {
                    if case .video(let playback) = content { playback.stop() }
                    onDismiss?(uuid, .system)
                    return
                }
                store.clearMediaError(for: uuid)
                present(content, on: current, mode: settings.scaleMode)
            case .failure(let error):
                store.setMediaError(error.localizedDescription, for: uuid)
                onMediaError?(uuid, isTest)
                // 出せなかったので、無操作タイマーは最初から数え直す
                onDismiss?(uuid, .system)
            }
        }
    }

    func dismiss(uuid: String, reason: DismissReason) {
        let wasActive = isActive(uuid)
        pendingLoads[uuid] = nil
        playbacks.removeValue(forKey: uuid)?.stop()
        updateHealthTimer()
        if let panel = panels.removeValue(forKey: uuid) {
            (panel.contentView as? OverlayContentView)?.detachVideo()
            panel.orderOut(nil)
            panel.contentView = nil
            panel.close()
        }
        visibleUUIDs.remove(uuid)
        if wasActive {
            onDismiss?(uuid, reason)
        }
    }

    func dismissAll(reason: DismissReason) {
        for uuid in Set(panels.keys).union(pendingLoads.keys) {
            dismiss(uuid: uuid, reason: reason)
        }
    }

    private func present(_ content: OverlayContent, on display: DisplayInfo, mode: ScaleMode) {
        let panel = OverlayPanel(screenFrame: display.frame)
        let view = OverlayContentView(frame: NSRect(origin: .zero, size: display.frame.size))
        switch content {
        case .black:
            view.setImage(nil, mode: mode)
        case .image(let image):
            view.setImage(image, mode: mode)
        case .video(let playback):
            view.setImage(nil, mode: mode)
            view.setVideo(playback.player, mode: mode)
            playbacks[display.uuid] = playback
            playback.play()
        }
        let uuid = display.uuid
        view.onClick = { [weak self] in
            self?.dismiss(uuid: uuid, reason: .click)
        }
        panel.contentView = view
        panel.orderFrontRegardless()

        panels[uuid] = panel
        visibleUUIDs.insert(uuid)
        updateHealthTimer()
    }

    /// 再生途中で失敗した動画は、黒画面のまま残さずに閉じて警告を出す。
    private func checkPlaybackHealth() {
        for (uuid, playback) in playbacks {
            guard let failure = playback.failureDescription else { continue }
            dismiss(uuid: uuid, reason: .system)
            store.setMediaError("動画の再生に失敗しました(\(failure))", for: uuid)
            onMediaError?(uuid, false)
        }
    }

    private func updateHealthTimer() {
        if playbacks.isEmpty {
            healthTimer?.invalidate()
            healthTimer = nil
        } else if healthTimer == nil {
            let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.checkPlaybackHealth()
                }
            }
            timer.tolerance = 0.5
            RunLoop.main.add(timer, forMode: .common)
            healthTimer = timer
        }
    }

    /// スリープ・画面ロック・ユーザー切り替え・ディスプレイ構成の変更で、すべて閉じる。
    private func observeSystemEvents() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let names: [(NotificationCenter, Notification.Name)] = [
            (workspaceCenter, NSWorkspace.willSleepNotification),
            (workspaceCenter, NSWorkspace.screensDidSleepNotification),
            (workspaceCenter, NSWorkspace.sessionDidResignActiveNotification),
            (DistributedNotificationCenter.default(), Notification.Name("com.apple.screenIsLocked")),
            (NotificationCenter.default, NSApplication.didChangeScreenParametersNotification),
        ]
        for (center, name) in names {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.dismissAll(reason: .system)
                }
            }
            observers.append((center, observer))
        }
    }
}
