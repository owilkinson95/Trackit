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
        var accentFirstBeat: Bool

        static let `default` = Pattern(bpm: 120, beatsPerBar: 4, accentFirstBeat: true)
    }

    /// Which click layer a tick belongs to. Each layer plays on its own
    /// `AVAudioPlayerNode` so it gets its own mixer fader — matching
    /// Playback's separate Accent/1⁄4/1⁄8/1⁄16 click controls. The click
    /// always generates a full sixteenth-note grid, every tier always
    /// ticking — the mixer faders are the *only* thing that decides what's
    /// actually audible, so they always work regardless of any other
    /// setting (there's no separate "subdivision" mode to silently gate
    /// them, which is what made them seem broken before).
    enum Layer {
        case accent
        case quarter
        case eighth
        case sixteenth
    }

    /// Ticks per quarter-note beat — a fixed sixteenth-note grid, always.
    private static let ticksPerBeat = 4

    /// Which layer a given tick (0-based, within the bar) belongs to, on
    /// the fixed sixteenth-note grid: position 0 is the beat itself
    /// (Accent on the bar's first beat, Quarter otherwise), position 2 is
    /// the "and" (Eighth), and positions 1/3 are the "e"/"a" (Sixteenth).
    private static func layer(forTick tick: Int, pattern: Pattern) -> Layer {
        if pattern.accentFirstBeat && tick == 0 { return .accent }
        switch tick % ticksPerBeat {
        case 0: return .quarter
        case 2: return .eighth
        default: return .sixteenth
        }
    }

    /// One bar of audio for a single click layer, on the fixed
    /// sixteenth-note grid — ticks belonging to another layer are left
    /// silent. Mono — `ChannelRouter` expands this to however many output
    /// channels the active device/routing assignment calls for.
    static func buffer(for pattern: Pattern, layer requestedLayer: Layer, sound: ClickSound) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let secondsPerBeat = 60.0 / pattern.bpm
        let ticksPerBar = pattern.beatsPerBar * ticksPerBeat
        let secondsPerTick = secondsPerBeat / Double(ticksPerBeat)
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
            let isStrongBeat = tick % ticksPerBeat == 0
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
        let ticksPerBar = pattern.beatsPerBar * ticksPerBeat
        let secondsPerTick = secondsPerBeat / Double(ticksPerBeat)
        let totalFrames = AVAudioFrameCount(secondsPerTick * Double(ticksPerBar) * sampleRate)

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(totalFrames, 1))!
        buffer.frameLength = buffer.frameCapacity

        guard let channelData = buffer.floatChannelData else { return buffer }
        let frameCount = Int(buffer.frameLength)
        for frame in 0..<frameCount {
            channelData[0][frame] = 0
        }
        guard mode != .off else { return buffer }

        for tick in 0..<ticksPerBar where tick % ticksPerBeat == 0 {
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
        case .cowbell: return 0.05
        case .hiHat: return 0.028
        case .rimshot: return 0.022
        case .beep: return 0.05
        }
    }

    var decayConstant: Double {
        switch self {
        case .classic: return 0.004
        case .woodblock: return 0.006
        case .digital: return 0.003
        case .clave: return 0.0025
        case .cowbell: return 0.016
        case .hiHat: return 0.006
        case .rimshot: return 0.005
        case .beep: return 0.018
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
        case .cowbell:
            // Two square tones at an inharmonic ratio sum into a metallic
            // clank — the classic analog-drum-machine cowbell trick.
            let a = sin(2.0 * Double.pi * frequency * t) >= 0 ? 1.0 : -1.0
            let b = sin(2.0 * Double.pi * frequency * 1.47 * t) >= 0 ? 1.0 : -1.0
            return Float((a + b) / 2)
        case .hiHat:
            // Same noise burst as Clave, but shorter and quieter (see
            // tickDurationSeconds/decayConstant) so it reads as a closed
            // hi-hat tick rather than a sharp wood-block snap.
            return Float.random(in: -1...1)
        case .rimshot:
            // A noise crack layered over a low thump, like a snare rim click.
            let noise = Double.random(in: -1...1)
            let thump = sin(2.0 * Double.pi * 180 * t)
            return Float(noise * 0.6 + thump * 0.4)
        case .beep:
            return Float(sin(2.0 * Double.pi * frequency * t))
        }
    }
}
