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
}
