import AppKit

// トップレベルのコードはメインスレッドで動くが、Swift 5 モードでは
// MainActor 扱いにならないため、明示的にメインアクター上で起動する。
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
