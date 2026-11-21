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
    /// The beat (0-based, within the bar) currently sounding — drives the
    /// visual beat indicator. Only meaningful while `isPlaying`.
    @Published private(set) var currentBeat = 0
    /// Seconds since Play was pressed — drives the elapsed-time display and
    /// the performance-screen playhead. Resets on stop.
    @Published private(set) var elapsedSeconds: Double = 0
    @Published var clickVolume: Double = ClickEngine.loadDouble(key: ClickEngine.clickVolumeKey, default: 0.8) {
        didSet { persistDouble(Self.clickVolumeKey, clickVolume); updateClickOutputVolume() }
    }
    @Published var clickMuted = false {
        didSet { updateClickOutputVolume() }
    }
    /// Scales everything in the mix — right now that's just the click,
    /// since there's no stem-audio playback engine yet, but this is where
    /// that mix-down happens once there is one.
    @Published var masterVolume: Double = ClickEngine.loadDouble(key: ClickEngine.masterVolumeKey, default: 1.0) {
        didSet { persistDouble(Self.masterVolumeKey, masterVolume); updateClickOutputVolume() }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isGraphReady = false
    private var connectedChannelCount = 2
    private var transportTimer: Timer?

    private static let clickChannelsKey = "clickOutputChannels"
    private static let clickVolumeKey = "clickVolume"
    private static let masterVolumeKey = "masterVolume"

    init() {
        clickChannels = Self.loadClickChannels()
        engine.attach(player)
        connectGraph(channelCount: connectedChannelCount)
        updateClickOutputVolume()

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
            startTransportClock()
        } catch {
            print("ClickEngine failed to start: \(error)")
        }
    }

    func stop() {
        guard isPlaying else { return }
        player.stop()
        isPlaying = false
        stopTransportClock()
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
            startTransportClock()
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

    /// Drives `currentBeat` and `elapsedSeconds` on a plain Timer rather than
    /// sample-accurate engine timing — fine for a visual cue and a playhead
    /// (unlike the audio itself, where any drift at all would be
    /// unacceptable).
    private func startTransportClock() {
        elapsedSeconds = 0
        currentBeat = 0
        transportTimer?.invalidate()
        let secondsPerBeat = 60.0 / pattern.bpm
        let beatsPerBar = pattern.beatsPerBar
        let tickInterval = 0.05
        transportTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.elapsedSeconds += tickInterval
                self.currentBeat = Int(self.elapsedSeconds / secondsPerBeat) % beatsPerBar
            }
        }
    }

    private func stopTransportClock() {
        transportTimer?.invalidate()
        transportTimer = nil
        currentBeat = 0
        elapsedSeconds = 0
    }

    private func updateClickOutputVolume() {
        player.volume = clickMuted ? 0 : Float(clickVolume * masterVolume)
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

    private static func loadDouble(key: String, default defaultValue: Double) -> Double {
        UserDefaults.standard.object(forKey: key) as? Double ?? defaultValue
    }

    private func persistDouble(_ key: String, _ value: Double) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
