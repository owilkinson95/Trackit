import AVFoundation

/// Builds seamless, loopable click buffers for a given tempo pattern.
/// One buffer = exactly one bar, so AVAudioPlayerNode's `.loops` option
/// repeats it with sample-accurate timing and no gap or restart glitch —
/// this is what gives us a true infinite click.
enum ClickGenerator {

    static let sampleRate: Double = 44_100

    struct Pattern: Equatable {
        var bpm: Double
        var beatsPerBar: Int
        var subdivision: Int // 1 = quarter notes only, 2 = eighths, 3 = triplets, 4 = sixteenths
        var accentFirstBeat: Bool

        static let `default` = Pattern(bpm: 120, beatsPerBar: 4, subdivision: 1, accentFirstBeat: true)
    }

    /// Which click layer a tick belongs to. Each layer plays on its own
    /// `AVAudioPlayerNode` so it gets its own mixer fader — matching
    /// Playback's separate Accent/1⁄4/1⁄8/1⁄16 click controls — instead of a
    /// single combined click volume. Which tiers actually have any ticks in
    /// a given bar depends on `Pattern.subdivision`: at `subdivision == 1`
    /// only Accent/Quarter have content, and Eighth/Sixteenth are silent
    /// (empty buffers) until a finer subdivision is chosen.
    enum Layer {
        case accent
        case quarter
        case eighth
        case sixteenth
    }

    /// Which layer a given tick (0-based, within the bar) belongs to, for
    /// the given pattern's beat/subdivision grid.
    private static func layer(forTick tick: Int, pattern: Pattern) -> Layer {
        if pattern.accentFirstBeat && tick == 0 { return .accent }
        let sub = pattern.subdivision
        let posInBeat = tick % sub
        if posInBeat == 0 { return .quarter }
        if sub == 4 { return posInBeat == 2 ? .eighth : .sixteenth }
        // subdivision == 2 (eighths) or == 3 (triplets): the one non-beat
        // tick per beat is bucketed as the "eighth" tier — triplets have no
        // clean eighth/sixteenth split, so this is a reasonable simplification.
        return .eighth
    }

    /// One bar of audio for a single click layer, click-per-subdivision, at
    /// the given pattern — ticks belonging to another layer are left
    /// silent. Mono — `ChannelRouter` expands this to however many output
    /// channels the active device/routing assignment calls for.
    static func buffer(for pattern: Pattern, layer requestedLayer: Layer, sound: ClickSound) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let secondsPerBeat = 60.0 / pattern.bpm
        let ticksPerBar = pattern.beatsPerBar * pattern.subdivision
        let secondsPerTick = secondsPerBeat / Double(pattern.subdivision)
        let totalFrames = AVAudioFrameCount(secondsPerTick * Double(ticksPerBar) * sampleRate)

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(totalFrames, 1))!
        buffer.frameLength = buffer.frameCapacity

        guard let channelData = buffer.floatChannelData else { return buffer }
        let frameCount = Int(buffer.frameLength)
        for frame in 0..<frameCount {
            channelData[0][frame] = 0
        }

        for tick in 0..<ticksPerBar {
            guard layer(forTick: tick, pattern: pattern) == requestedLayer else { continue }
            let isAccent = requestedLayer == .accent
            let isStrongBeat = tick % pattern.subdivision == 0
            let startFrame = Int(Double(tick) * secondsPerTick * sampleRate)
            writeTick(into: channelData[0], frameCount: frameCount, startFrame: startFrame, accent: isAccent, strong: isStrongBeat, sound: sound)
        }

        return buffer
    }

    /// One bar of audio for the Guide layer — a soft reference pulse, with a
    /// distinct timbre from the click, at the beats the chosen mode calls
    /// for. All silence when `mode` is `.off`.
    static func guideBuffer(for pattern: Pattern, mode: GuideMode) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let secondsPerBeat = 60.0 / pattern.bpm
        let ticksPerBar = pattern.beatsPerBar * pattern.subdivision
        let secondsPerTick = secondsPerBeat / Double(pattern.subdivision)
        let totalFrames = AVAudioFrameCount(secondsPerTick * Double(ticksPerBar) * sampleRate)

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(totalFrames, 1))!
        buffer.frameLength = buffer.frameCapacity

        guard let channelData = buffer.floatChannelData else { return buffer }
        let frameCount = Int(buffer.frameLength)
        for frame in 0..<frameCount {
            channelData[0][frame] = 0
        }
        guard mode != .off else { return buffer }

        for tick in 0..<ticksPerBar where tick % pattern.subdivision == 0 {
            let isDownbeat = tick == 0
            if mode == .downbeat && !isDownbeat { continue }
            let startFrame = Int(Double(tick) * secondsPerTick * sampleRate)
            writeGuidePulse(into: channelData[0], frameCount: frameCount, startFrame: startFrame, accent: isDownbeat)
        }

        return buffer
    }

    /// A short, decaying tick whose waveform shape depends on the chosen
    /// click sound, and whose pitch/level depends on the beat's role.
    private static func writeTick(into channel: UnsafeMutablePointer<Float>, frameCount: Int, startFrame: Int, accent: Bool, strong: Bool, sound: ClickSound) {
        let frequency: Double = accent ? 1760 : (strong ? 1320 : 1000)
        let amplitude: Float = accent ? 0.9 : (strong ? 0.7 : 0.45)
        let tickFrames = Int(sound.tickDurationSeconds * sampleRate)

        for i in 0..<tickFrames {
            let frame = startFrame + i
            guard frame < frameCount else { break }
            let t = Double(i) / sampleRate
            let envelope = Float(exp(-t / sound.decayConstant))
            channel[frame] = amplitude * envelope * sound.waveform(frequency: frequency, t: t)
        }
    }

    /// A soft, warm pulse — longer and lower than the click's tick, so it
    /// reads as a reference pitch cue rather than another layer of click.
    private static func writeGuidePulse(into channel: UnsafeMutablePointer<Float>, frameCount: Int, startFrame: Int, accent: Bool) {
        let frequency: Double = accent ? 440 : 330
        let amplitude: Float = 0.5
        let pulseFrames = Int(0.09 * sampleRate)

        for i in 0..<pulseFrames {
            let frame = startFrame + i
            guard frame < frameCount else { break }
            let t = Double(i) / sampleRate
            let envelope = Float(exp(-t / 0.03))
            channel[frame] = amplitude * envelope * Float(sin(2.0 * Double.pi * frequency * t))
        }
    }
}

private extension ClickSound {
    var tickDurationSeconds: Double {
        switch self {
        case .classic: return 0.016
        case .woodblock: return 0.02
        case .digital: return 0.012
        case .clave: return 0.01
        }
    }

    var decayConstant: Double {
        switch self {
        case .classic: return 0.004
        case .woodblock: return 0.006
        case .digital: return 0.003
        case .clave: return 0.0025
        }
    }

    func waveform(frequency: Double, t: Double) -> Float {
        switch self {
        case .classic:
            return Float(sin(2.0 * Double.pi * frequency * t))
        case .digital:
            return sin(2.0 * Double.pi * frequency * t) >= 0 ? 1 : -1
        case .woodblock:
            let fundamental = sin(2.0 * Double.pi * frequency * t)
            let overtone = 0.3 * sin(2.0 * Double.pi * frequency * 2 * t)
            return Float(fundamental + overtone)
        case .clave:
            return Float.random(in: -1...1)
        }
    }
}
