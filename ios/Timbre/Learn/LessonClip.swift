import AVFoundation
import SwiftUI
import UIKit

/// A lesson's clip of a hand doing what the words describe (a bow hold, a pick grip, palm muting): a short bundled
/// video (`<name>.mov`, `.mp4` or `.m4v`) looping without sound, else a photograph of it (`<name>` in the asset
/// catalogue). Under Reduce Motion the video holds still. With neither in the bundle yet, the card shows its words alone.
struct LessonClipView: View {
    let name: String
    var height: CGFloat = 240
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let url = LessonClip.video(name) {
            LoopingVideo(url: url, playing: !reduceMotion)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous))
                .accessibilityHidden(true)
        } else if LessonClip.hasPhoto(name) {
            Image(name).resizable().interpolation(.high).scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous))
                .accessibilityHidden(true)
        }
    }
}

/// Where a lesson clip's media lives in the bundle.
enum LessonClip {
    /// The clip's video, if the bundle has one.
    static func video(_ name: String) -> URL? {
        for type in ["mov", "mp4", "m4v"] {
            if let url = Bundle.main.url(forResource: name, withExtension: type) { return url }
        }
        return nil
    }

    /// Whether the asset catalogue has a photograph of it.
    @MainActor static func hasPhoto(_ name: String) -> Bool { UIImage(named: name) != nil }
}

/// A muted video looping in place.
private struct LoopingVideo: UIViewRepresentable {
    let url: URL
    let playing: Bool

    func makeUIView(context: Context) -> LoopingVideoView { LoopingVideoView(url: url) }

    func updateUIView(_ view: LoopingVideoView, context: Context) { view.setPlaying(playing) }

    static func dismantleUIView(_ view: LoopingVideoView, coordinator: ()) { view.stop() }
}

/// The video's layer and its looping player: silent, never keeping the screen awake, paused in the background.
private final class LoopingVideoView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init(url: URL) {
        super.init(frame: .zero)
        backgroundColor = .clear
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.audiovisualBackgroundPlaybackPolicy = .pauses
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        if let video = layer as? AVPlayerLayer {
            video.player = player
            video.videoGravity = .resizeAspect
        }
    }

    required init?(coder: NSCoder) { nil }

    func setPlaying(_ playing: Bool) {
        if playing { player.play() } else { player.pause() }
    }

    func stop() {
        player.pause()
        looper?.disableLooping()
        looper = nil
    }
}
