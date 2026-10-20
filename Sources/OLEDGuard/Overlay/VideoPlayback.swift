import AVFoundation

/// 動画1本分のループ再生。AVQueuePlayer + AVPlayerLooper で、ミュートのまま繰り返す。
///
/// - ファイルは AVURLAsset で必要な分だけ読み出す(全体をメモリに載せない)
/// - デコードは AVFoundation 標準の経路(VideoToolbox のハードウェアデコード)に任せる
@MainActor
final class VideoPlayback {
    let player: AVQueuePlayer
    private var looper: AVPlayerLooper?

    private init(player: AVQueuePlayer, looper: AVPlayerLooper) {
        self.player = player
        self.looper = looper
    }

    /// 再生できることを確かめてから返す。再生できなければ throw し、何も残さない。
    static func prepare(url: URL, timeout: Duration = .seconds(10)) async throws -> VideoPlayback {
        let name = url.lastPathComponent
        let asset = AVURLAsset(url: url)

        guard try await asset.load(.isPlayable) else {
            throw MediaLoadError.unplayableVideo(name, nil)
        }
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw MediaLoadError.unplayableVideo(name, "映像トラックがありません")
        }
        guard try await track.load(.isDecodable) else {
            throw MediaLoadError.unplayableVideo(name, "このコーデックはデコードできません")
        }

        let player = AVQueuePlayer()
        player.isMuted = true
        player.volume = 0
        // 待ち受け中でも、macOS のディスプレイスリープは妨げない
        player.preventsDisplaySleepDuringVideoPlayback = false
        let looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(asset: asset))
        let playback = VideoPlayback(player: player, looper: looper)

        // 最初のフレームを出せる状態になるまで待つ(黒画面のまま固まらないように)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if let failure = playback.failureDescription {
                playback.stop()
                throw MediaLoadError.unplayableVideo(name, failure)
            }
            if player.currentItem?.status == .readyToPlay {
                return playback
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        playback.stop()
        throw MediaLoadError.unplayableVideo(name, "再生の準備が時間内に終わりませんでした")
    }

    /// 再生に失敗していればその内容。問題なければ nil。
    var failureDescription: String? {
        if let looper, looper.status == .failed {
            return looper.error?.localizedDescription ?? "ループ再生に失敗しました"
        }
        if let item = player.currentItem, item.status == .failed {
            return item.error?.localizedDescription ?? "再生に失敗しました"
        }
        return nil
    }

    func play() {
        player.play()
    }

    /// 再生を止め、読み込んだ項目を手放す。以後このインスタンスは使わない。
    func stop() {
        player.pause()
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
    }
}
