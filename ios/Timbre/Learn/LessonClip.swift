import AVFoundation
import SwiftUI
import UIKit

/// A lesson's clip of a hand doing what the words describe (a bow hold, a pick grip, palm muting): a short bundled
/// video (`<name>.mov`, `.mp4` or `.m4v`) looping without sound; else its photographs, one (`<name>` in the asset
/// catalogue) or a few steps of it (`<name>`, `<name>-2`, `<name>-3`…) shown one after another (`ClipPhotoSteps`), as
/// a single phone shoot can make them before a video exists. Under Reduce Motion the video and the steps hold still (a
/// tap steps on). With nothing in the bundle yet, the card shows its words alone.
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
        } else {
            photos(LessonClip.photos(name))
        }
    }

    @ViewBuilder private func photos(_ names: [String]) -> some View {
        if names.count > 1 {
            ClipPhotoSteps(names: names, height: height)
        } else if let only = names.first {
            Image(only).resizable().interpolation(.high).scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous))
                .accessibilityHidden(true)
        }
    }
}

/// Where a lesson clip's media lives in the bundle.
enum LessonClip {
    /// The most photographs a clip's steps run to.
    static let maxSteps = 6

    /// The clip's video, if the bundle has one.
    static func video(_ name: String) -> URL? {
        for type in ["mov", "mp4", "m4v"] {
            if let url = Bundle.main.url(forResource: name, withExtension: type) { return url }
        }
        return nil
    }

    /// Whether the asset catalogue has a photograph of it.
    @MainActor static func hasPhoto(_ name: String) -> Bool { UIImage(named: name) != nil }

    /// The clip's photographs in order: `<name>` (the one the curriculum build looks for), then `<name>-2`,
    /// `<name>-3`… while the catalogue has them. Empty without the first.
    @MainActor static func photos(_ name: String) -> [String] {
        guard hasPhoto(name) else { return [] }
        var names = [name]
        for step in 2...maxSteps {
            let next = "\(name)-\(step)"
            guard hasPhoto(next) else { break }
            names.append(next)
        }
        return names
    }
}

/// A technique in a few photographs: each holds a moment, then cross-fades to the next, round and round, with a dot
/// per step under them (the one up drawn long); a tap steps on. Under Reduce Motion the steps change only on a tap.
/// The lesson's words say what the hand does, so VoiceOver reads those rather than the pictures.
private struct ClipPhotoSteps: View {
    let names: [String]
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    /// Seconds each step holds.
    private static let hold = 1.8

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                ForEach(names.indices, id: \.self) { index in
                    Image(names[index]).resizable().interpolation(.high).scaledToFit()
                        .opacity(index == step ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: max(80, height - 16))
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { advance() }
            HStack(spacing: 6) {
                ForEach(names.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Palette.ink : Palette.inkFaint.opacity(0.5))
                        .frame(width: index == step ? 16 : 6, height: 6)
                }
            }
            .frame(height: 8)
        }
        .animation(Motion.fade, value: step)
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.hold))
                guard !Task.isCancelled else { return }
                advance()
            }
        }
        .accessibilityHidden(true)
    }

    private func advance() { step = (step + 1) % max(1, names.count) }
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
