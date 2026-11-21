import AVFoundation
import Combine

/// Drives the infinite click loop. Five AVAudioPlayerNodes — Accent,
/// Quarter (1/4), Eighth (1/8), Sixteenth (1/16), and Guide — each with
/// their own looping buffer and their own mixer fader, so the downbeat
/// accent and each subdivision tier can be balanced independently, like
/// Playback's mixer. Which tiers actually have ticks in them depends on
/// the pattern's subdivision (see `ClickGenerator.Layer`); at the coarsest
/// subdivision, Eighth/Sixteenth are simply silent, so their faders have
/// no audible effect until a finer subdivision is chosen.
/// Changing tempo/time-signature/sound/guide mode rebuilds all the buffers
/// and reschedules at the next loop boundary rather than mid-bar, so the
/// click never stutters.
///
/// Output routing (which physical channel(s) carry the click) is implemented
/// by generating the loop buffers directly in the device's full channel
/// count, with real audio only in the assigned channels and silence
/// elsewhere — see `ChannelRouter`. That avoids needing Core Audio's
/// channel-map APIs and works the same way on macOS and iOS.
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

    @Published var accentVolume: Double = ClickEngine.loadDouble(key: ClickEngine.accentVolumeKey, default: 0.9) {
        didSet { persistDouble(Self.accentVolumeKey, accentVolume); updateOutputVolumes() }
    }
    @Published var accentMuted = false {
        didSet { updateOutputVolumes() }
    }
    @Published var quarterVolume: Double = ClickEngine.loadDouble(key: ClickEngine.quarterVolumeKey, default: 0.8) {
        didSet { persistDouble(Self.quarterVolumeKey, quarterVolume); updateOutputVolumes() }
    }
    @Published var quarterMuted = false {
        didSet { updateOutputVolumes() }
    }
    @Published var eighthVolume: Double = ClickEngine.loadDouble(key: ClickEngine.eighthVolumeKey, default: 0.8) {
        didSet { persistDouble(Self.eighthVolumeKey, eighthVolume); updateOutputVolumes() }
    }
    @Published var eighthMuted = false {
        didSet { updateOutputVolumes() }
    }
    @Published var sixteenthVolume: Double = ClickEngine.loadDouble(key: ClickEngine.sixteenthVolumeKey, default: 0.8) {
        didSet { persistDouble(Self.sixteenthVolumeKey, sixteenthVolume); updateOutputVolumes() }
    }
    @Published var sixteenthMuted = false {
        didSet { updateOutputVolumes() }
    }
    /// A soft reference pulse, independent of the click, to help singers
    /// and players land pitches and entrances. Off and silent by default —
    /// `guideMode` decides when it sounds, this fader decides how loud.
    @Published var guideVolume: Double = ClickEngine.loadDouble(key: ClickEngine.guideVolumeKey, default: 0.0) {
        didSet { persistDouble(Self.guideVolumeKey, guideVolume); updateOutputVolumes() }
    }
    @Published var guideMuted = false {
        didSet { updateOutputVolumes() }
    }
    @Published var guideMode: GuideMode = ClickEngine.loadGuideMode() {
        didSet {
            persistGuideMode()
            if isPlaying { scheduleLoop() }
        }
    }
    @Published var clickSound: ClickSound = ClickEngine.loadClickSound() {
        didSet {
            persistClickSound()
            if isPlaying { scheduleLoop() }
        }
    }
    /// Scales everything in the mix — click, guide, and (once there's a
    /// stem-audio playback engine) tracks.
    @Published var masterVolume: Double = ClickEngine.loadDouble(key: ClickEngine.masterVolumeKey, default: 1.0) {
        didSet { persistDouble(Self.masterVolumeKey, masterVolume); updateOutputVolumes() }
    }

    private let engine = AVAudioEngine()
    private let accentPlayer = AVAudioPlayerNode()
    private let quarterPlayer = AVAudioPlayerNode()
    private let eighthPlayer = AVAudioPlayerNode()
    private let sixteenthPlayer = AVAudioPlayerNode()
    private let guidePlayer = AVAudioPlayerNode()
    private var isGraphReady = false
    private var connectedChannelCount = 2
    private var transportTimer: Timer?

    private var allPlayers: [AVAudioPlayerNode] {
        [accentPlayer, quarterPlayer, eighthPlayer, sixteenthPlayer, guidePlayer]
    }

    private static let clickChannelsKey = "clickOutputChannels"
    private static let accentVolumeKey = "accentVolume"
    private static let quarterVolumeKey = "quarterVolume"
    private static let eighthVolumeKey = "eighthVolume"
    private static let sixteenthVolumeKey = "sixteenthVolume"
    private static let guideVolumeKey = "guideVolume"
    private static let guideModeKey = "guideMode"
    private static let clickSoundKey = "clickSound"
    private static let masterVolumeKey = "masterVolume"

    init() {
        clickChannels = Self.loadClickChannels()
        for player in allPlayers {
            engine.attach(player)
        }
        connectGraph(channelCount: connectedChannelCount)
        updateOutputVolumes()

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
            for player in allPlayers { player.play() }
            isPlaying = true
            startTransportClock()
        } catch {
            print("ClickEngine failed to start: \(error)")
        }
    }

    func stop() {
        guard isPlaying else { return }
        for player in allPlayers { player.stop() }
        isPlaying = false
        stopTransportClock()
    }

    /// Apply a new tempo/time-signature. If currently playing, restarts the
    /// loop cleanly at the new pattern (a short, acceptable gap — mid-bar
    /// crossfade is a later refinement, not needed for v1 correctness).
    func update(pattern newPattern: ClickGenerator.Pattern) {
        pattern = newPattern
        if isPlaying {
            for player in allPlayers { player.stop() }
            scheduleLoop()
            for player in allPlayers { player.play() }
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
        for player in allPlayers {
            engine.disconnectNodeOutput(player)
        }
        engine.disconnectNodeOutput(engine.mainMixerNode)
        for player in allPlayers {
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)
        connectedChannelCount = channelCount
    }

    private func scheduleLoop() {
        let validChannels = clickChannels.filter { $0 < connectedChannelCount }
        let activeChannels = validChannels.isEmpty ? Set(0..<min(connectedChannelCount, 2)) : validChannels

        func expanded(_ mono: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
            ChannelRouter.expand(mono: mono, toChannelCount: connectedChannelCount, activeChannels: activeChannels, sampleRate: ClickGenerator.sampleRate)
        }

        accentPlayer.scheduleBuffer(expanded(ClickGenerator.buffer(for: pattern, layer: .accent, sound: clickSound)), at: nil, options: .loops)
        quarterPlayer.scheduleBuffer(expanded(ClickGenerator.buffer(for: pattern, layer: .quarter, sound: clickSound)), at: nil, options: .loops)
        eighthPlayer.scheduleBuffer(expanded(ClickGenerator.buffer(for: pattern, layer: .eighth, sound: clickSound)), at: nil, options: .loops)
        sixteenthPlayer.scheduleBuffer(expanded(ClickGenerator.buffer(for: pattern, layer: .sixteenth, sound: clickSound)), at: nil, options: .loops)
        guidePlayer.scheduleBuffer(expanded(ClickGenerator.guideBuffer(for: pattern, mode: guideMode)), at: nil, options: .loops)
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

    private func updateOutputVolumes() {
        accentPlayer.volume = accentMuted ? 0 : Float(accentVolume * masterVolume)
        quarterPlayer.volume = quarterMuted ? 0 : Float(quarterVolume * masterVolume)
        eighthPlayer.volume = eighthMuted ? 0 : Float(eighthVolume * masterVolume)
        sixteenthPlayer.volume = sixteenthMuted ? 0 : Float(sixteenthVolume * masterVolume)
        guidePlayer.volume = guideMuted ? 0 : Float(guideVolume * masterVolume)
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

    private static func loadGuideMode() -> GuideMode {
        guard let raw = UserDefaults.standard.string(forKey: guideModeKey), let mode = GuideMode(rawValue: raw) else {
            return .off
        }
        return mode
    }

    private func persistGuideMode() {
        UserDefaults.standard.set(guideMode.rawValue, forKey: Self.guideModeKey)
    }

    private static func loadClickSound() -> ClickSound {
        guard let raw = UserDefaults.standard.string(forKey: clickSoundKey), let sound = ClickSound(rawValue: raw) else {
            return .classic
        }
        return sound
    }

    private func persistClickSound() {
        UserDefaults.standard.set(clickSound.rawValue, forKey: Self.clickSoundKey)
    }
}
