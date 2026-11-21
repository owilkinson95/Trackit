import Foundation
import SwiftData

/// A mixer channel for one audio stem of a song (Guide, Drums, Keys, etc).
///
/// No real audio file is attached yet — the app doesn't have a stem-import
/// pipeline built. Volume/mute/solo are fully real and persisted so the
/// mixer is ready to use the moment that lands; until then, moving these
/// faders has no audible effect of its own (the UI makes this honest via
/// a one-line note rather than pretending otherwise).
@Model
final class Track {
    var name: String
    var order: Int
    var volume: Double
    var isMuted: Bool
    var isSoloed: Bool
    var song: Song?

    init(name: String, order: Int, volume: Double = 0.8, isMuted: Bool = false, isSoloed: Bool = false, song: Song? = nil) {
        self.name = name
        self.order = order
        self.volume = volume
        self.isMuted = isMuted
        self.isSoloed = isSoloed
        self.song = song
    }
}
