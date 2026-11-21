import Foundation
import SwiftData

@Model
final class Song {
    var title: String
    var artist: String
    var key: String
    var bpm: Double
    var beatsPerBar: Int
    var subdivision: Int
    var notes: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SetlistItem.song)
    var setlistItems: [SetlistItem] = []

    @Relationship(deleteRule: .cascade, inverse: \Track.song)
    var tracks: [Track] = []

    @Relationship(deleteRule: .cascade, inverse: \SongSection.song)
    var sections: [SongSection] = []

    init(
        title: String,
        artist: String = "",
        key: String = "",
        bpm: Double = 120,
        beatsPerBar: Int = 4,
        subdivision: Int = 1,
        notes: String = ""
    ) {
        self.title = title
        self.artist = artist
        self.key = key
        self.bpm = bpm
        self.beatsPerBar = beatsPerBar
        self.subdivision = subdivision
        self.notes = notes
        self.createdAt = Date()
    }

    var pattern: ClickGenerator.Pattern {
        ClickGenerator.Pattern(bpm: bpm, beatsPerBar: beatsPerBar, subdivision: subdivision, accentFirstBeat: true)
    }

    var sortedTracks: [Track] {
        tracks.sorted { $0.order < $1.order }
    }

    var sortedSections: [SongSection] {
        sections.sorted { $0.order < $1.order }
    }

    /// Total bars across all sections, used to derive a nominal song length
    /// (there's no audio file yet to read a real duration from).
    var totalBars: Int {
        sections.reduce(0) { $0 + $1.lengthBars }
    }

    var nominalDurationSeconds: Double {
        Double(totalBars) * (60.0 / bpm) * Double(beatsPerBar)
    }

    /// A deterministic, song-specific hue so each setlist carousel card gets
    /// a distinct color without needing real album art.
    var cardHue: Double {
        let hash = title.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        return Double(abs(hash) % 360) / 360.0
    }
}
