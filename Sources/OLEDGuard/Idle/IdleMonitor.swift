import AppKit
import Combine
import OLEDGuardCore

/// IdleTracker に実際のカーソル位置・クリック・時刻を渡し、待ち受けの表示を指示する。
///
/// - カーソル位置は1秒ごとに NSEvent.mouseLocation で取得する(特別な権限は不要)
/// - クリックは NSEvent のグローバルモニターで受け取る(マウスのイベントだけなので権限は不要)
/// - スリープ・画面ロック中は判定を止め、戻ったら全モニターを最初から数え直す
@MainActor
final class IdleMonitor: ObservableObject {
    /// 待ち受けまでの残り秒数(設定画面の表示用)。対象外のモニターは含まない
    @Published private(set) var remainingSeconds: [String: Int] = [:]

    private let tracker = IdleTracker()
    private let displayManager: DisplayManager
    private let store: SettingsStore
    private let appState: AppState
    private let overlays: OverlayManager
    private let secondsPerMinute: TimeInterval

    private var pollTimer: Timer?
    private var eventMonitors: [Any] = []
    private var notificationObservers: [(NotificationCenter, NSObjectProtocol)] = []
    private var cancellables: Set<AnyCancellable> = []
    /// 判定を止めている理由(スリープ、ロックなど)。空なら判定する
    private var suspendReasons: Set<String> = []

    init(
        displayManager: DisplayManager,
        store: SettingsStore,
        appState: AppState,
        overlays: OverlayManager,
        secondsPerMinute: TimeInterval = DebugOptions.secondsPerMinute
    ) {
        self.displayManager = displayManager
        self.store = store
        self.appState = appState
        self.overlays = overlays
        self.secondsPerMinute = secondsPerMinute
    }

    func start() {
        // @Published は値が変わる直前に流れてくるので、渡された新しい値を使う
        store.$settings
            .combineLatest(displayManager.$displays)
            .sink { [weak self] settings, displays in
                MainActor.assumeIsolated {
                    self?.reconfigure(settings: settings, displays: displays)
                }
            }
            .store(in: &cancellables)

        appState.$isPaused
            .sink { [weak self] paused in
                MainActor.assumeIsolated {
                    self?.setPaused(paused)
                }
            }
            .store(in: &cancellables)

        let clickMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        // 他のアプリへのクリック
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: clickMask, handler: { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleClick()
            }
        }) {
            eventMonitors.append(monitor)
        }
        // このアプリ(設定画面など)へのクリック
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: clickMask, handler: { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleClick()
            }
            return event
        }) {
            eventMonitors.append(monitor)
        }

        observeSystemEvents()

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        poll()
    }

    /// 待ち受けが閉じた(または出せなかった)ときに呼ぶ。
    func overlayDismissed(_ uuid: String) {
        tracker.overlayDismissed(uuid, now: Date())
        updateRemaining(now: Date())
    }

    private func reconfigure(settings: AppSettings, displays: [DisplayInfo]) {
        let tracked = displays.map { display in
            let displaySettings = settings.displays[display.uuid] ?? DisplaySettings()
            return TrackedDisplay(
                uuid: display.uuid,
                frame: display.frame,
                isEnabled: displaySettings.isEnabled,
                timeout: TimeInterval(displaySettings.idleMinutes) * secondsPerMinute
            )
        }
        tracker.configure(tracked, now: Date())
        updateRemaining(now: Date())
    }

    private func setPaused(_ paused: Bool) {
        tracker.setPaused(paused, now: Date())
        if paused {
            overlays.dismissAll(reason: .system)
        }
        updateRemaining(now: Date())
    }

    private func handleClick() {
        tracker.mouseClicked(at: NSEvent.mouseLocation, now: Date())
    }

    private func poll() {
        let now = Date()
        guard suspendReasons.isEmpty else { return }

        tracker.mouseMoved(to: NSEvent.mouseLocation, now: now)

        for uuid in tracker.tick(now: now) {
            if overlays.isActive(uuid) {
                // テスト表示などですでに出ている。閉じたときにタイマーがやり直される
                continue
            }
            if let display = displayManager.display(withUUID: uuid) {
                overlays.show(display: display, isTest: false)
            } else {
                tracker.overlayDismissed(uuid, now: now)
            }
        }
        updateRemaining(now: now)
    }

    private func updateRemaining(now: Date) {
        var result: [String: Int] = [:]
        for display in displayManager.displays {
            if let remaining = tracker.remainingTime(for: display.uuid, now: now) {
                result[display.uuid] = Int(remaining.rounded(.up))
            }
        }
        if result != remainingSeconds {
            remainingSeconds = result
        }
    }

    private func suspend(_ reason: String) {
        suspendReasons.insert(reason)
        updateRemaining(now: Date())
    }

    private func resume(_ reason: String) {
        suspendReasons.remove(reason)
        // 止まっていた間の時間は無操作に数えない
        tracker.resetAll(now: Date())
        updateRemaining(now: Date())
    }

    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        let pairs: [(NotificationCenter, Notification.Name, String, Bool)] = [
            (workspace, NSWorkspace.willSleepNotification, "sleep", true),
            (workspace, NSWorkspace.didWakeNotification, "sleep", false),
            (workspace, NSWorkspace.screensDidSleepNotification, "screens", true),
            (workspace, NSWorkspace.screensDidWakeNotification, "screens", false),
            (workspace, NSWorkspace.sessionDidResignActiveNotification, "session", true),
            (workspace, NSWorkspace.sessionDidBecomeActiveNotification, "session", false),
            (distributed, Notification.Name("com.apple.screenIsLocked"), "lock", true),
            (distributed, Notification.Name("com.apple.screenIsUnlocked"), "lock", false),
        ]
        for (center, name, reason, isSuspending) in pairs {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    if isSuspending {
                        self?.suspend(reason)
                    } else {
                        self?.resume(reason)
                    }
                }
            }
            notificationObservers.append((center, observer))
        }
    }
}
