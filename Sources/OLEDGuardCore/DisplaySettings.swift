import Foundation

/// 待ち受けの表示方法。
public enum ScaleMode: String, Codable, CaseIterable, Hashable, Sendable {
    /// 画面全体を覆う(はみ出した部分は切れる)
    case fill
    /// 全体が見える(余白は黒)
    case fit
}

/// 待ち受けに使うファイルの登録1件。ファイル1つ、またはフォルダ(中の対応ファイルすべて)。
public struct MediaSource: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case file
        case folder
    }

    public var kind: Kind
    /// 絶対パス
    public var path: String

    public init(kind: Kind, path: String) {
        self.kind = kind
        self.path = path
    }

    public var url: URL {
        URL(fileURLWithPath: path, isDirectory: kind == .folder)
    }
}

/// 登録したファイルの中から、待ち受けごとにどれを選ぶか。
public enum SelectionOrder: String, Codable, CaseIterable, Hashable, Sendable {
    /// ランダム(直前と同じものは避ける)
    case random
    /// 登録順(フォルダの中は名前順)に1つずつ進む
    case sequential
}

/// モニター1枚分の設定。UUID をキーに AppSettings に保存する。
public struct DisplaySettings: Codable, Hashable, Sendable {
    /// 待ち受けまでの時間の選択肢(分)。この9択のみ。
    public static let idleMinuteChoices = [5, 10, 15, 20, 30, 45, 60, 90, 120]
    public static let defaultIdleMinutes = 10
    /// 表示中に切り替える間隔の選択肢(分)。
    public static let slideshowMinuteChoices = [1, 5, 10, 15, 30, 45, 60, 90, 120]
    public static let defaultSlideshowMinutes = 10

    public var isEnabled: Bool
    public var idleMinutes: Int {
        didSet { idleMinutes = Self.normalizedIdleMinutes(idleMinutes) }
    }
    /// 待ち受けに使うファイル・フォルダ(登録順)。空なら黒画面。
    public var mediaSources: [MediaSource]
    public var selectionOrder: SelectionOrder
    /// 待ち受けの表示中も、一定時間ごとに次のファイルへ切り替える
    public var slideshowEnabled: Bool
    public var slideshowMinutes: Int {
        didSet { slideshowMinutes = Self.normalizedSlideshowMinutes(slideshowMinutes) }
    }
    public var scaleMode: ScaleMode
    /// 最後に接続されていたときのモニター名。未接続モニターの一覧表示に使う。
    public var lastKnownName: String?
    /// 最後に表示したファイルのパス。「順番」の続きと、「ランダム」で同じものを続けないために使う。
    public var lastShownPath: String?

    public init(
        isEnabled: Bool = false,
        idleMinutes: Int = DisplaySettings.defaultIdleMinutes,
        mediaSources: [MediaSource] = [],
        selectionOrder: SelectionOrder = .random,
        slideshowEnabled: Bool = false,
        slideshowMinutes: Int = DisplaySettings.defaultSlideshowMinutes,
        scaleMode: ScaleMode = .fill,
        lastKnownName: String? = nil,
        lastShownPath: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.idleMinutes = Self.normalizedIdleMinutes(idleMinutes)
        self.mediaSources = mediaSources
        self.selectionOrder = selectionOrder
        self.slideshowEnabled = slideshowEnabled
        self.slideshowMinutes = Self.normalizedSlideshowMinutes(slideshowMinutes)
        self.scaleMode = scaleMode
        self.lastKnownName = lastKnownName
        self.lastShownPath = lastShownPath
    }

    /// 選択肢にない値は、それ以上で最も近い選択肢に丸める(120超は120)。
    /// 以前の選択肢で保存した 40分は45分、50分は60分になる。
    public static func normalizedIdleMinutes(_ minutes: Int) -> Int {
        idleMinuteChoices.first { $0 >= minutes } ?? idleMinuteChoices.last!
    }

    public static func normalizedSlideshowMinutes(_ minutes: Int) -> Int {
        slideshowMinuteChoices.first { $0 >= minutes } ?? slideshowMinuteChoices.last!
    }

    // 項目が増えても古い設定ファイルを読めるよう、欠けている項目は既定値で補う
    private enum CodingKeys: String, CodingKey {
        case isEnabled, idleMinutes, mediaSources, selectionOrder, slideshowEnabled, slideshowMinutes
        case scaleMode, lastKnownName, lastShownPath
        /// 以前の形式(ファイル1つだけ)。読み込み時に mediaSources へ移す
        case mediaPath
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var sources = try c.decodeIfPresent([MediaSource].self, forKey: .mediaSources) ?? []
        if sources.isEmpty, let legacy = try c.decodeIfPresent(String.self, forKey: .mediaPath), !legacy.isEmpty {
            sources = [MediaSource(kind: .file, path: legacy)]
        }
        self.init(
            isEnabled: try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false,
            idleMinutes: try c.decodeIfPresent(Int.self, forKey: .idleMinutes) ?? Self.defaultIdleMinutes,
            mediaSources: sources,
            selectionOrder: (try? c.decodeIfPresent(SelectionOrder.self, forKey: .selectionOrder)) ?? .random,
            slideshowEnabled: try c.decodeIfPresent(Bool.self, forKey: .slideshowEnabled) ?? false,
            slideshowMinutes: try c.decodeIfPresent(Int.self, forKey: .slideshowMinutes) ?? Self.defaultSlideshowMinutes,
            scaleMode: (try? c.decodeIfPresent(ScaleMode.self, forKey: .scaleMode)) ?? .fill,
            lastKnownName: try c.decodeIfPresent(String.self, forKey: .lastKnownName),
            lastShownPath: try c.decodeIfPresent(String.self, forKey: .lastShownPath)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(isEnabled, forKey: .isEnabled)
        try c.encode(idleMinutes, forKey: .idleMinutes)
        try c.encode(mediaSources, forKey: .mediaSources)
        try c.encode(selectionOrder, forKey: .selectionOrder)
        try c.encode(slideshowEnabled, forKey: .slideshowEnabled)
        try c.encode(slideshowMinutes, forKey: .slideshowMinutes)
        try c.encode(scaleMode, forKey: .scaleMode)
        try c.encodeIfPresent(lastKnownName, forKey: .lastKnownName)
        try c.encodeIfPresent(lastShownPath, forKey: .lastShownPath)
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
