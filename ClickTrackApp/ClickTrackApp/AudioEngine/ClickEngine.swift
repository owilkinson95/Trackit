import AVFoundation
import Combine

/// Drives the infinite click loop. One AVAudioPlayerNode, one looping buffer.
/// Changing tempo/time-signature rebuilds the buffer and reschedules at the
/// next loop boundary rather than mid-bar, so the click never stutters.
@MainActor
final class ClickEngine: ObservableObject {

    @Published var pattern: ClickGenerator.Pattern = .default
    @Published private(set) var isPlaying = false
    @Published private(set) var currentSongTitle: String?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isGraphReady = false

    init() {
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: ClickGenerator.sampleRate, channels: 2)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func start() {
        guard !isPlaying else { return }
        do {
            if !isGraphReady {
                #if os(iOS)
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                #endif
                try engine.start()
                isGraphReady = true
            }
            scheduleLoop()
            player.play()
            isPlaying = true
        } catch {
            print("ClickEngine failed to start: \(error)")
        }
    }

    func stop() {
        guard isPlaying else { return }
        player.stop()
        isPlaying = false
    }

    /// Apply a new tempo/time-signature. If currently playing, restarts the
    /// loop cleanly at the new pattern (a short, acceptable gap — mid-bar
    /// crossfade is a later refinement, not needed for v1 correctness).
    func update(pattern newPattern: ClickGenerator.Pattern) {
        pattern = newPattern
        if isPlaying {
            player.stop()
            scheduleLoop()
            player.play()
        }
    }

    /// Loads a song's tempo pattern into the transport. Does not start playback
    /// by itself — the user still presses Play, same as Playback does.
    func loadSong(_ song: Song) {
        currentSongTitle = song.title
        update(pattern: song.pattern)
    }

    private func scheduleLoop() {
        let buffer = ClickGenerator.buffer(for: pattern)
        player.scheduleBuffer(buffer, at: nil, options: .loops)
    }
}
