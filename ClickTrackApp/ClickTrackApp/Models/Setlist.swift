import Foundation
import SwiftData

@Model
final class Setlist {
    var name: String
    var date: Date
    var notes: String

    @Relationship(deleteRule: .cascade, inverse: \SetlistItem.setlist)
    var items: [SetlistItem] = []

    init(name: String, date: Date = Date(), notes: String = "") {
        self.name = name
        self.date = date
        self.notes = notes
    }

    var sortedItems: [SetlistItem] {
        items.sorted { $0.position < $1.position }
    }
}

/// Join model giving each (setlist, song) pairing an explicit order,
/// since SwiftData doesn't preserve array order across relationships on its own.
@Model
final class SetlistItem {
    var position: Int
    var song: Song?
    var setlist: Setlist?

    init(position: Int, song: Song?, setlist: Setlist?) {
        self.position = position
        self.song = song
        self.setlist = setlist
    }
}
