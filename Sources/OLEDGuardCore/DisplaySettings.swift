import Foundation

/// 待ち受けの表示方法。
public enum ScaleMode: String, Codable, CaseIterable, Hashable, Sendable {
    /// 画面全体を覆う(はみ出した部分は切れる)
    case fill
    /// 全体が見える(余白は黒)
    case fit
}

/// モニター1枚分の設定。UUID をキーに AppSettings に保存する。
public struct DisplaySettings: Codable, Hashable, Sendable {
    /// 待ち受けまでの時間の選択肢(分)。この9択のみ。
    public static let idleMinuteChoices = [5, 10, 15, 20, 30, 45, 60, 90, 120]
    public static let defaultIdleMinutes = 10

    public var isEnabled: Bool
    public var idleMinutes: Int {
        didSet { idleMinutes = Self.normalizedIdleMinutes(idleMinutes) }
    }
    /// 待ち受けに使うファイルの絶対パス。未指定なら nil。
    public var mediaPath: String?
    public var scaleMode: ScaleMode
    /// 最後に接続されていたときのモニター名。未接続モニターの一覧表示に使う。
    public var lastKnownName: String?

    public init(
        isEnabled: Bool = false,
        idleMinutes: Int = DisplaySettings.defaultIdleMinutes,
        mediaPath: String? = nil,
        scaleMode: ScaleMode = .fill,
        lastKnownName: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.idleMinutes = Self.normalizedIdleMinutes(idleMinutes)
        self.mediaPath = mediaPath
        self.scaleMode = scaleMode
        self.lastKnownName = lastKnownName
    }

    /// 選択肢にない値は、それ以上で最も近い選択肢に丸める(120超は120)。
    /// 以前の選択肢で保存した 40分は45分、50分は60分になる。
    public static func normalizedIdleMinutes(_ minutes: Int) -> Int {
        idleMinuteChoices.first { $0 >= minutes } ?? idleMinuteChoices.last!
    }

    public var mediaURL: URL? {
        guard let mediaPath, !mediaPath.isEmpty else { return nil }
        return URL(fileURLWithPath: mediaPath)
    }

    // 項目が増えても古い設定ファイルを読めるよう、欠けている項目は既定値で補う
    private enum CodingKeys: String, CodingKey {
        case isEnabled, idleMinutes, mediaPath, scaleMode, lastKnownName
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isEnabled: try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false,
            idleMinutes: try c.decodeIfPresent(Int.self, forKey: .idleMinutes) ?? Self.defaultIdleMinutes,
            mediaPath: try c.decodeIfPresent(String.self, forKey: .mediaPath),
            scaleMode: (try? c.decodeIfPresent(ScaleMode.self, forKey: .scaleMode)) ?? .fill,
            lastKnownName: try c.decodeIfPresent(String.self, forKey: .lastKnownName)
        )
    }
}

/// アプリ全体の設定。接続されていないモニターの設定も消さずに持つ。
public struct AppSettings: Codable, Hashable, Sendable {
    /// キーはモニターの UUID(CGDisplayCreateUUIDFromDisplayID)
    public var displays: [String: DisplaySettings]

    public init(displays: [String: DisplaySettings] = [:]) {
        self.displays = displays
    }

    private enum CodingKeys: String, CodingKey { case displays }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.displays = try c.decodeIfPresent([String: DisplaySettings].self, forKey: .displays) ?? [:]
    }
}
