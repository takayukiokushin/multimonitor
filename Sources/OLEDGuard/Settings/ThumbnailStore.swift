import AVFoundation
import AppKit
import OLEDGuardCore

/// 設定画面に出す小さなサムネイルを、ファイルパスごとに作って覚えておく。
@MainActor
final class ThumbnailStore: ObservableObject {
    private static let maxPixelSize = CGSize(width: 240, height: 240)

    @Published private(set) var images: [String: NSImage] = [:]
    private var requested: Set<String> = []

    /// まだなければ作り始めて nil を返す(できあがると画面が更新される)。
    func thumbnail(for url: URL) -> NSImage? {
        let path = url.path(percentEncoded: false)
        if let image = images[path] {
            return image
        }
        if !requested.contains(path) {
            requested.insert(path)
            // 画面の描画中に @Published を書き換えないよう、次の機会に回す
            Task { await load(url: url, path: path) }
        }
        return nil
    }

    /// ファイルが差し替わったときなどに、作り直せるようにする。
    func invalidateAll() {
        images = [:]
        requested = []
    }

    private func load(url: URL, path: String) async {
        let size = Self.maxPixelSize
        let image: CGImage?
        switch MediaKind(url: url) {
        case .image:
            image = await Task.detached(priority: .utility) {
                try? MediaLoader.loadImage(url: url, targetPixelSize: size, mode: .fit)
            }.value
        case .pdf:
            image = await Task.detached(priority: .utility) {
                try? MediaLoader.renderPDF(url: url, targetPixelSize: size, mode: .fit)
            }.value
        case .video:
            image = await videoFrame(url: url)
        case nil:
            image = nil
        }
        if let image {
            images[path] = NSImage(cgImage: image, size: .zero)
        }
    }

    /// 動画は1秒目(短ければ先頭)のフレームを使う。
    private func videoFrame(url: URL) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = Self.maxPixelSize
        for seconds in [1.0, 0.0] {
            if let frame = try? await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)) {
                return frame.image
            }
        }
        return nil
    }
}
