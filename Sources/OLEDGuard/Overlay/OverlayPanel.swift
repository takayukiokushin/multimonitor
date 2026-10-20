import AVFoundation
import AppKit
import OLEDGuardCore

/// 1枚のモニター全面を覆う、枠なしの待ち受けウィンドウ。
///
/// - .nonactivatingPanel: クリックしてもこのアプリが前面化せず、他のアプリのキー入力も奪わない
/// - level .screenSaver: メニューバー・Dock・全画面アプリより前面
/// - canJoinAllSpaces / fullScreenAuxiliary: どの Space や全画面アプリの上にも出る
final class OverlayPanel: NSPanel {
    convenience init(screenFrame: CGRect) {
        self.init(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .black
        isOpaque = true
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        animationBehavior = .none
        // contentRect の解釈に頼らず、グローバル座標で対象モニターにぴったり合わせる
        setFrame(screenFrame, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// 待ち受けの中身。背景は黒で、画像は CALayer、動画は AVPlayerLayer で表示する。
final class OverlayContentView: NSView {
    /// クリック(ボタンを離したとき)で呼ばれる
    var onClick: (@MainActor () -> Void)?

    private let mediaLayer = CALayer()
    private var playerLayer: AVPlayerLayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        mediaLayer.frame = bounds
        mediaLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        mediaLayer.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(mediaLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setImage(_ image: CGImage?, mode: ScaleMode) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mediaLayer.contents = image
        mediaLayer.contentsGravity = mode == .fill ? .resizeAspectFill : .resizeAspect
        mediaLayer.masksToBounds = true
        CATransaction.commit()
    }

    func setVideo(_ player: AVPlayer, mode: ScaleMode) {
        detachVideo()
        let videoLayer = AVPlayerLayer(player: player)
        videoLayer.frame = bounds
        videoLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        videoLayer.backgroundColor = NSColor.black.cgColor
        videoLayer.videoGravity = mode == .fill ? .resizeAspectFill : .resizeAspect
        layer?.addSublayer(videoLayer)
        playerLayer = videoLayer
    }

    func detachVideo() {
        playerLayer?.player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }

    // 非アクティブなアプリのウィンドウでも、最初のクリックを受け取る
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // 押下はここで受け止めて下のアプリに渡さず、離したときに閉じる
    override func mouseDown(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) { onClick?() }
    override func rightMouseUp(with event: NSEvent) { onClick?() }
    override func otherMouseUp(with event: NSEvent) { onClick?() }
}
