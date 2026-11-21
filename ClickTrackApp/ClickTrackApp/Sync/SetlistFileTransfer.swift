import Foundation
import SwiftData

/// Moves the song library and setlists between devices via a plain JSON
/// file — shared through AirDrop or Files — since CloudKit sync needs a
/// paid Apple Developer account this project doesn't have yet. Once that's
/// in place, this stays as a useful one-off transfer/backup even with
/// automatic sync running.
enum SetlistFileTransfer {

    struct ExportedSong: Codable {
        var title: String
        var artist: String
        var key: String
        var bpm: Double
        var beatsPerBar: Int
        var notes: String
    }

    struct ExportedSetlistItem: Codable {
        var position: Int
        var songIndex: Int
    }

    struct ExportedSetlist: Codable {
        var name: String
        var date: Date
        var notes: String
        var items: [ExportedSetlistItem]
    }

    struct Package: Codable {
        var version: Int
        var songs: [ExportedSong]
        var setlists: [ExportedSetlist]
    }

    enum TransferError: Error, LocalizedError {
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                return "This file was exported by a newer version of the app (format \(version))."
            }
        }
    }

    static func export(songs: [Song], setlists: [Setlist]) -> Data {
        let songIndex = Dictionary(uniqueKeysWithValues: songs.enumerated().map { ($1.persistentModelID, $0) })

        let exportedSongs = songs.map { song in
            ExportedSong(
                title: song.title, artist: song.artist, key: song.key,
                bpm: song.bpm, beatsPerBar: song.beatsPerBar,
                notes: song.notes
            )
        }

        let exportedSetlists = setlists.map { setlist -> ExportedSetlist in
            let items = setlist.sortedItems.compactMap { item -> ExportedSetlistItem? in
                guard let song = item.song, let index = songIndex[song.persistentModelID] else { return nil }
                return ExportedSetlistItem(position: item.position, songIndex: index)
            }
            return ExportedSetlist(name: setlist.name, date: setlist.date, notes: setlist.notes, items: items)
        }

        let package = Package(version: 1, songs: exportedSongs, setlists: exportedSetlists)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(package)) ?? Data()
    }

    /// Imports as new songs/setlists alongside whatever's already in the
    /// library — it doesn't try to de-duplicate matches by name. Importing
    /// the same file twice will create a second copy of everything.
    @discardableResult
    static func importPackage(from data: Data, into context: ModelContext) throws -> (songs: Int, setlists: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let package = try decoder.decode(Package.self, from: data)

        guard package.version <= 1 else {
            throw TransferError.unsupportedVersion(package.version)
        }

        var createdSongs: [Song] = []
        for exported in package.songs {
            let song = Song(
                title: exported.title, artist: exported.artist, key: exported.key,
                bpm: exported.bpm, beatsPerBar: exported.beatsPerBar,
                notes: exported.notes
            )
            context.insert(song)
            createdSongs.append(song)
        }

        for exportedSetlist in package.setlists {
            let setlist = Setlist(name: exportedSetlist.name, date: exportedSetlist.date, notes: exportedSetlist.notes)
            context.insert(setlist)
            for exportedItem in exportedSetlist.items where createdSongs.indices.contains(exportedItem.songIndex) {
                let item = SetlistItem(position: exportedItem.position, song: createdSongs[exportedItem.songIndex], setlist: setlist)
                context.insert(item)
            }
        }

        return (createdSongs.count, package.setlists.count)
    }
}
