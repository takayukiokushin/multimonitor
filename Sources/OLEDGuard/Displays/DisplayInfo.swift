import AppKit

/// 接続中のモニター1枚分の情報。
struct DisplayInfo: Identifiable, Equatable {
    /// CGDisplayCreateUUIDFromDisplayID の UUID。設定の永続化キーに使う。
    let uuid: String
    let displayID: CGDirectDisplayID
    let name: String
    /// グローバル座標(ポイント、左下原点)。NSEvent.mouseLocation と同じ座標系。
    let frame: CGRect
    let pixelWidth: Int
    let pixelHeight: Int
    let refreshRate: Double
    let isMain: Bool

    var id: String { uuid }

    init?(screen: NSScreen) {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        let displayID = CGDirectDisplayID(number.uint32Value)
        guard let uuid = DisplayInfo.uuidString(for: displayID) else { return nil }

        self.uuid = uuid
        self.displayID = displayID
        self.name = screen.localizedName
        self.frame = screen.frame

        let mode = CGDisplayCopyDisplayMode(displayID)
        self.pixelWidth = mode?.pixelWidth ?? Int(screen.frame.width * screen.backingScaleFactor)
        self.pixelHeight = mode?.pixelHeight ?? Int(screen.frame.height * screen.backingScaleFactor)

        // 一部のモニターは refreshRate が 0 を返すため、NSScreen の値で補う
        var rate = mode?.refreshRate ?? 0
        if rate <= 0 { rate = Double(screen.maximumFramesPerSecond) }
        self.refreshRate = rate

        self.isMain = CGDisplayIsMain(displayID) != 0
    }

    static func uuidString(for displayID: CGDirectDisplayID) -> String? {
        guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
            return nil
        }
        return CFUUIDCreateString(nil, cfUUID) as String
    }
}
