import Foundation

/// GetSongBPM (https://getsongbpm.com) is the only tempo-lookup service with a
/// documented, free, name-based API. Its data is CC BY 4.0, and its terms
/// require a visible attribution link back to the site wherever results are
/// shown — see `TempoSearchView`'s footer.
///
/// Parsing here is deliberately defensive (plain JSON dictionaries, multiple
/// key fallbacks) rather than a strict Codable model: the public docs don't
/// pin down every field name precisely, and a shape we didn't anticipate
/// should degrade to "skip this result," not crash the search.
struct GetSongBPMSource: TempoSource {
    var apiKey: String

    private static let baseURL = URL(string: "https://api.getsong.co/search/")!

    func search(title: String, artist: String) async throws -> [TempoResult] {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw TempoSourceError.missingAPIKey
        }

        let hasArtist = !artist.trimmingCharacters(in: .whitespaces).isEmpty
        // Per https://getsongbpm.com/api: combining a title with an artist
        // requires type=both and a "song:X artist:Y" lookup string; a
        // title-only search uses type=song with no prefix.
        let type = hasArtist ? "both" : "song"
        let lookup = hasArtist ? "song:\(title) artist:\(artist)" : title

        var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "lookup", value: lookup),
            URLQueryItem(name: "limit", value: "10"),
        ]

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(from: components.url!)
        } catch {
            throw TempoSourceError.network(error)
        }

        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rows = root["search"] as? [[String: Any]]
        else {
            throw TempoSourceError.invalidResponse
        }

        return rows.compactMap(Self.parseResult)
    }

    private static func parseResult(_ row: [String: Any]) -> TempoResult? {
        guard let bpmString = (row["tempo"] as? String) ?? (row["tempo"] as? NSNumber)?.stringValue,
              let bpm = Double(bpmString) else {
            return nil
        }

        let title = (row["title"] as? String) ?? (row["song_title"] as? String) ?? "Unknown"

        var artistName = ""
        if let artistDict = row["artist"] as? [String: Any] {
            artistName = (artistDict["name"] as? String) ?? ""
        } else if let artistString = row["artist"] as? String {
            artistName = artistString
        }

        let key = (row["key_of"] as? String) ?? (row["key"] as? String) ?? ""
        let id = (row["id"] as? String) ?? UUID().uuidString
        let uriString = (row["uri"] as? String)

        return TempoResult(
            id: id,
            title: title,
            artist: artistName,
            bpm: bpm,
            key: key,
            sourceURL: uriString.flatMap(URL.init(string:))
        )
    }
}
