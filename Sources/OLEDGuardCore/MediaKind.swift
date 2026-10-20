import Foundation

/// 待ち受けに使えるファイルの種類。拡張子で判定する。
public enum MediaKind: Sendable {
    case image
    case pdf
    case video

    public static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif"]
    public static let pdfExtensions: Set<String> = ["pdf"]
    public static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]

    public static var allExtensions: Set<String> {
        imageExtensions.union(pdfExtensions).union(videoExtensions)
    }

    public init?(url: URL) {
        let ext = url.pathExtension.lowercased()
        if Self.imageExtensions.contains(ext) {
            self = .image
        } else if Self.pdfExtensions.contains(ext) {
            self = .pdf
        } else if Self.videoExtensions.contains(ext) {
            self = .video
        } else {
            return nil
        }
    }
}
