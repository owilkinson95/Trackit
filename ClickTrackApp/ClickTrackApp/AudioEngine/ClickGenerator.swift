import AVFoundation

/// Builds a seamless, loopable click buffer for a given tempo pattern.
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

    /// One bar of audio, click-per-subdivision, at the given pattern.
    static func buffer(for pattern: Pattern) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
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
            channelData[1][frame] = 0
        }

        for tick in 0..<ticksPerBar {
            let isAccent = pattern.accentFirstBeat && tick % pattern.subdivision == 0 && tick == 0
            let isBeat = tick % pattern.subdivision == 0
            let startFrame = Int(Double(tick) * secondsPerTick * sampleRate)
            writeTick(into: channelData, frameCount: frameCount, startFrame: startFrame, accent: isAccent, strong: isBeat)
        }

        return buffer
    }

    /// A short, decaying sine burst — a clean, unmistakable metronome "tick".
    private static func writeTick(into channelData: UnsafePointer<UnsafeMutablePointer<Float>>, frameCount: Int, startFrame: Int, accent: Bool, strong: Bool) {
        let frequency: Double = accent ? 1760 : (strong ? 1320 : 1000)
        let amplitude: Float = accent ? 0.9 : (strong ? 0.7 : 0.45)
        let durationSeconds = 0.016
        let tickFrames = Int(durationSeconds * sampleRate)

        for i in 0..<tickFrames {
            let frame = startFrame + i
            guard frame < frameCount else { break }
            let t = Double(i) / sampleRate
            let envelope = Float(exp(-t / 0.004))
            let sample = amplitude * envelope * Float(sin(2.0 * Double.pi * frequency * t))
            channelData[0][frame] = sample
            channelData[1][frame] = sample
        }
    }
}
