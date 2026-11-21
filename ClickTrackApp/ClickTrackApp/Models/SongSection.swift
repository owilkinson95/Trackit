import Foundation
import SwiftData

/// An arrangement marker on the performance timeline (Verse 1, Chorus, etc),
/// with a length in bars so the timeline can lay sections out proportionally
/// and derive a nominal song length — there's no audio file yet to read a
/// real duration from.
///
/// Named `SongSection` rather than `Section` to avoid colliding with
/// SwiftUI's own `Section` view, used throughout the Form-based screens.
@Model
final class SongSection {
    var label: String
    var order: Int
    var lengthBars: Int
    var colorName: String
    var song: Song?

    init(label: String, order: Int, lengthBars: Int = 8, colorName: String = SongSection.colorNames[0], song: Song? = nil) {
        self.label = label
        self.order = order
        self.lengthBars = lengthBars
        self.colorName = colorName
        self.song = song
    }

    static let colorNames = ["yellow", "blue", "green", "orange", "purple", "pink", "teal"]
}
