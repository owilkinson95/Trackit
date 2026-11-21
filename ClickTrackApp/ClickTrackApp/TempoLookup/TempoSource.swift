import Foundation

struct TempoResult: Identifiable, Equatable {
    var id: String
    var title: String
    var artist: String
    var bpm: Double
    var key: String
    /// Link back to the source page — required by GetSongBPM's attribution terms,
    /// and generally useful for double-checking a match before trusting it.
    var sourceURL: URL?
}

enum TempoSourceError: Error, LocalizedError {
    case missingAPIKey
    case network(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add a free GetSongBPM API key to search for tempos."
        case .network(let error):
            return "Couldn't reach GetSongBPM: \(error.localizedDescription)"
        case .invalidResponse:
            return "GetSongBPM returned something unexpected."
        }
    }
}

/// Abstracts where tempo lookups come from, so a second source (e.g. Planning
/// Center, once the church migrates to it) can be added later without
/// touching the search UI.
protocol TempoSource {
    func search(title: String, artist: String) async throws -> [TempoResult]
}
