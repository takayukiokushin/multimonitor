import Foundation

/// 動作確認用に、待ち受けまでの時間を短縮する。
///
/// 「1分」を何秒として扱うかを、次のどちらかで指定する(両方あれば起動引数を優先)。
/// - 起動引数: `open build/OLEDGuard.app --args --minute-seconds 6`
/// - 環境変数: `OLEDGUARD_MINUTE_SECONDS=6`
enum DebugOptions {
    static let secondsPerMinute: TimeInterval = {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--minute-seconds"),
           index + 1 < arguments.count,
           let value = TimeInterval(arguments[index + 1]), value > 0 {
            return value
        }
        if let raw = ProcessInfo.processInfo.environment["OLEDGUARD_MINUTE_SECONDS"],
           let value = TimeInterval(raw), value > 0 {
            return value
        }
        return 60
    }()

    static var isShortened: Bool {
        secondsPerMinute != 60
    }
}
