import CoreGraphics
import Foundation

/// 無操作判定の対象になるモニター1枚分の情報。
public struct TrackedDisplay: Equatable, Sendable {
    public var uuid: String
    /// グローバル座標(NSEvent.mouseLocation と同じ、左下原点)
    public var frame: CGRect
    public var isEnabled: Bool
    /// 待ち受けまでの秒数
    public var timeout: TimeInterval

    public init(uuid: String, frame: CGRect, isEnabled: Bool, timeout: TimeInterval) {
        self.uuid = uuid
        self.frame = frame
        self.isEnabled = isEnabled
        self.timeout = timeout
    }
}

/// モニター単位の無操作判定。UI やタイマーを持たず、時刻はすべて引数で受け取る。
///
/// - 対象モニターの範囲内でカーソルが動いた/クリックしたときだけ、そのモニターのタイマーをやり直す
/// - キーボードや他のモニターでの操作は関係しない
/// - 待ち受けの表示中は、そのモニターの判定を止める
public final class IdleTracker {
    private struct Entry {
        var display: TrackedDisplay
        var lastActivity: Date
        var isShowingOverlay: Bool
    }

    private var entries: [String: Entry] = [:]
    private var lastMouseLocation: CGPoint?
    public private(set) var isPaused = false

    public init() {}

    /// 接続中のモニターと設定を反映する。
    /// 新しいモニター、または有効/無効・時間が変わったモニターは、タイマーを最初から数え直す。
    /// 一覧にないモニターは判定対象から外す。
    public func configure(_ displays: [TrackedDisplay], now: Date) {
        var next: [String: Entry] = [:]
        for display in displays {
            if var entry = entries[display.uuid] {
                if entry.display.isEnabled != display.isEnabled || entry.display.timeout != display.timeout {
                    entry.lastActivity = now
                }
                entry.display = display
                next[display.uuid] = entry
            } else {
                next[display.uuid] = Entry(display: display, lastActivity: now, isShowingOverlay: false)
            }
        }
        entries = next
    }

    /// 定期的に取得したカーソル位置を渡す。前回から位置が変わっていれば、今いるモニターの操作とみなす。
    public func mouseMoved(to location: CGPoint, now: Date) {
        defer { lastMouseLocation = location }
        guard let last = lastMouseLocation, last != location else { return }
        registerActivity(at: location, now: now)
    }

    /// クリックされた位置を渡す。
    public func mouseClicked(at location: CGPoint, now: Date) {
        registerActivity(at: location, now: now)
    }

    /// 待ち受けに入るべきモニターを返し、それらを「表示中」にする。
    public func tick(now: Date) -> [String] {
        guard !isPaused else { return [] }
        var due: [String] = []
        for (uuid, entry) in entries
        where entry.display.isEnabled && !entry.isShowingOverlay
            && now.timeIntervalSince(entry.lastActivity) >= entry.display.timeout {
            entries[uuid]?.isShowingOverlay = true
            due.append(uuid)
        }
        return due.sorted()
    }

    /// 待ち受けが閉じた(または出せなかった)。そのモニターのタイマーを最初から数え直す。
    public func overlayDismissed(_ uuid: String, now: Date) {
        entries[uuid]?.isShowingOverlay = false
        entries[uuid]?.lastActivity = now
    }

    /// 一時停止中は待ち受けに入らない。再開したら全モニターを最初から数え直す。
    public func setPaused(_ paused: Bool, now: Date) {
        guard paused != isPaused else { return }
        isPaused = paused
        if !paused {
            resetAll(now: now)
        }
    }

    /// スリープ復帰・ロック解除などで、全モニターを最初から数え直す。
    public func resetAll(now: Date) {
        for uuid in entries.keys {
            entries[uuid]?.lastActivity = now
        }
    }

    public func isShowingOverlay(_ uuid: String) -> Bool {
        entries[uuid]?.isShowingOverlay ?? false
    }

    /// 待ち受けまでの残り秒数。無効・一時停止中・表示中・対象外なら nil。
    public func remainingTime(for uuid: String, now: Date) -> TimeInterval? {
        guard !isPaused, let entry = entries[uuid], entry.display.isEnabled, !entry.isShowingOverlay else {
            return nil
        }
        return max(0, entry.display.timeout - now.timeIntervalSince(entry.lastActivity))
    }

    /// その位置を含むモニター。隣り合うモニターの境界上では、内側に含むほうを優先する。
    public func displayUUID(containing point: CGPoint) -> String? {
        let sorted = entries.values.sorted { $0.display.uuid < $1.display.uuid }
        if let inside = sorted.first(where: { $0.display.frame.contains(point) }) {
            return inside.display.uuid
        }
        // 上端・右端ちょうど(contains では外れる)の位置
        return sorted.first { entry in
            let f = entry.display.frame
            return point.x >= f.minX && point.x <= f.maxX && point.y >= f.minY && point.y <= f.maxY
        }?.display.uuid
    }

    private func registerActivity(at location: CGPoint, now: Date) {
        guard let uuid = displayUUID(containing: location),
              let entry = entries[uuid],
              !entry.isShowingOverlay else { return }
        entries[uuid]?.lastActivity = now
    }
}
