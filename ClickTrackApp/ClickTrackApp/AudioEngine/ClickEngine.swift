import AVFoundation
import Combine

/// Drives the infinite click loop. One AVAudioPlayerNode, one looping buffer.
/// Changing tempo/time-signature rebuilds the buffer and reschedules at the
/// next loop boundary rather than mid-bar, so the click never stutters.
///
/// Output routing (which physical channel(s) carry the click) is implemented
/// by generating the loop buffer directly in the device's full channel count,
/// with real audio only in the assigned channels and silence elsewhere —
/// see `ChannelRouter`. That avoids needing Core Audio's channel-map APIs
/// and works the same way on macOS and iOS.
@MainActor
final class ClickEngine: ObservableObject {

    @Published var pattern: ClickGenerator.Pattern = .default
    @Published private(set) var isPlaying = false
    @Published private(set) var currentSongTitle: String?
    @Published private(set) var deviceChannelCount: Int = 2
    @Published var clickChannels: Set<Int> {
        didSet {
            persistClickChannels()
            if isPlaying { scheduleLoop() }
        }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isGraphReady = false
    private var connectedChannelCount = 2

    private static let clickChannelsKey = "clickOutputChannels"

    init() {
        clickChannels = Self.loadClickChannels()
        engine.attach(player)
        connectGraph(channelCount: connectedChannelCount)

        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshDeviceChannelCount() }
        }
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
            refreshDeviceChannelCount()
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

    /// Re-reads the active output device's channel count — call after the
    /// engine starts, or when the user wants to pick up a newly connected
    /// audio interface — and reconnects the graph if it changed.
    func refreshDeviceChannelCount() {
        let channels = Int(engine.outputNode.outputFormat(forBus: 0).channelCount)
        deviceChannelCount = max(channels, 1)
        if deviceChannelCount != connectedChannelCount {
            connectGraph(channelCount: deviceChannelCount)
            if isPlaying { scheduleLoop() }
        }
    }

    private func connectGraph(channelCount: Int) {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: ClickGenerator.sampleRate, channels: AVAudioChannelCount(channelCount)) else { return }
        engine.disconnectNodeOutput(player)
        engine.disconnectNodeOutput(engine.mainMixerNode)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)
        connectedChannelCount = channelCount
    }

    private func scheduleLoop() {
        let monoBuffer = ClickGenerator.buffer(for: pattern)
        let validChannels = clickChannels.filter { $0 < connectedChannelCount }
        let activeChannels = validChannels.isEmpty ? Set(0..<min(connectedChannelCount, 2)) : validChannels
        let buffer = ChannelRouter.expand(
            mono: monoBuffer,
            toChannelCount: connectedChannelCount,
            activeChannels: activeChannels,
            sampleRate: ClickGenerator.sampleRate
        )
        player.scheduleBuffer(buffer, at: nil, options: .loops)
    }

    private static func loadClickChannels() -> Set<Int> {
        guard let saved = UserDefaults.standard.string(forKey: clickChannelsKey), !saved.isEmpty else {
            return [0, 1]
        }
        let parsed = Set(saved.split(separator: ",").compactMap { Int($0) })
        return parsed.isEmpty ? [0, 1] : parsed
    }

    private func persistClickChannels() {
        let value = clickChannels.sorted().map(String.init).joined(separator: ",")
        UserDefaults.standard.set(value, forKey: Self.clickChannelsKey)
    }
}
