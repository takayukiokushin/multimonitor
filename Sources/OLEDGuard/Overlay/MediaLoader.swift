import AppKit
import ImageIO
import OLEDGuardCore
import PDFKit

/// 待ち受けに表示する中身。
enum OverlayContent {
    /// ファイル未指定・見つからないときは黒画面
    case black
    case image(CGImage)
    case video(VideoPlayback)
}

enum MediaLoadError: LocalizedError {
    case unsupportedFormat(String)
    case unreadableImage(String)
    case unreadablePDF(String)
    case unplayableVideo(String, String?)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let name):
            return "対応していない形式です: \(name)"
        case .unreadableImage(let name):
            return "画像を読み込めませんでした: \(name)"
        case .unreadablePDF(let name):
            return "PDF を読み込めませんでした: \(name)"
        case .unplayableVideo(let name, let reason):
            if let reason {
                return "動画を再生できませんでした: \(name)(\(reason))"
            }
            return "動画を再生できませんでした: \(name)"
        }
    }
}

enum MediaLoader {
    /// 設定に従って中身を用意する。重い読み込みはバックグラウンドで行う。
    @MainActor
    static func load(settings: DisplaySettings, targetPixelSize: CGSize) async -> Result<OverlayContent, Error> {
        guard let url = settings.mediaURL,
              FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            return .success(.black)
        }
        guard let kind = MediaKind(url: url) else {
            return .failure(MediaLoadError.unsupportedFormat(url.lastPathComponent))
        }
        let mode = settings.scaleMode

        switch kind {
        case .image:
            // バックグラウンドからは CGImage だけを受け渡す
            let result = await Task.detached(priority: .userInitiated) {
                Result { try MediaLoader.loadImage(url: url, targetPixelSize: targetPixelSize, mode: mode) }
            }.value
            return result.map { OverlayContent.image($0) }
        case .pdf:
            let result = await Task.detached(priority: .userInitiated) {
                Result { try MediaLoader.renderPDF(url: url, targetPixelSize: targetPixelSize, mode: mode) }
            }.value
            return result.map { OverlayContent.image($0) }
        case .video:
            do {
                return .success(.video(try await VideoPlayback.prepare(url: url)))
            } catch {
                return .failure(error)
            }
        }
    }

    /// ImageIO で、画面に必要な大きさまで縮小して読み込む(元画像より大きくはしない)。
    static func loadImage(url: URL, targetPixelSize: CGSize, mode: ScaleMode) throws -> CGImage {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let rawWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let rawHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              rawWidth > 0, rawHeight > 0 else {
            throw MediaLoadError.unreadableImage(url.lastPathComponent)
        }

        // EXIF の向きが 5〜8 なら縦横が入れ替わる
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let (width, height) = orientation >= 5 ? (rawHeight, rawWidth) : (rawWidth, rawHeight)

        let scale = min(1, fittingScale(content: CGSize(width: width, height: height), target: targetPixelSize, mode: mode))
        let maxPixelSize = max(1, (max(width, height) * scale).rounded(.up))

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw MediaLoadError.unreadableImage(url.lastPathComponent)
        }
        return image
    }

    /// PDF の1ページ目を、画面の解像度に合わせて描画する(ベクターなので拡大もする)。
    static func renderPDF(url: URL, targetPixelSize: CGSize, mode: ScaleMode) throws -> CGImage {
        guard let document = PDFDocument(url: url), let page = document.page(at: 0) else {
            throw MediaLoadError.unreadablePDF(url.lastPathComponent)
        }
        var pageSize = page.bounds(for: .mediaBox).size
        if page.rotation % 180 != 0 {
            pageSize = CGSize(width: pageSize.height, height: pageSize.width)
        }
        guard pageSize.width > 0, pageSize.height > 0 else {
            throw MediaLoadError.unreadablePDF(url.lastPathComponent)
        }

        let scale = fittingScale(content: pageSize, target: targetPixelSize, mode: mode)
        let size = NSSize(
            width: (pageSize.width * scale).rounded(),
            height: (pageSize.height * scale).rounded()
        )
        let thumbnail = page.thumbnail(of: size, for: .mediaBox)
        guard let image = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw MediaLoadError.unreadablePDF(url.lastPathComponent)
        }
        return image
    }

    /// フィルは画面を覆う倍率、フィットは全体が収まる倍率。
    private static func fittingScale(content: CGSize, target: CGSize, mode: ScaleMode) -> CGFloat {
        let sx = target.width / content.width
        let sy = target.height / content.height
        return mode == .fill ? max(sx, sy) : min(sx, sy)
    }
}
