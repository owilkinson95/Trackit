import AVFoundation

/// Expands a mono buffer into an N-channel buffer, with the signal placed
/// only in the assigned channels and silence everywhere else. This is how
/// "send the click to channel 2 only" is implemented: no exotic Core Audio
/// channel-map APIs needed, just an output-format-shaped buffer where the
/// unwanted channels are zero. Works identically on macOS and iOS.
enum ChannelRouter {
    static func expand(mono buffer: AVAudioPCMBuffer, toChannelCount channelCount: Int, activeChannels: Set<Int>, sampleRate: Double) -> AVAudioPCMBuffer {
        guard channelCount > 1, let monoData = buffer.floatChannelData?[0] else {
            return buffer
        }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: AVAudioChannelCount(channelCount)) else {
            return buffer
        }

        let expanded = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: buffer.frameCapacity)!
        expanded.frameLength = buffer.frameLength
        guard let expandedData = expanded.floatChannelData else { return buffer }

        let frameCount = Int(buffer.frameLength)
        for channel in 0..<channelCount {
            let targetChannel = expandedData[channel]
            if activeChannels.contains(channel) {
                for frame in 0..<frameCount {
                    targetChannel[frame] = monoData[frame]
                }
            } else {
                for frame in 0..<frameCount {
                    targetChannel[frame] = 0
                }
            }
        }

        return expanded
    }
}
