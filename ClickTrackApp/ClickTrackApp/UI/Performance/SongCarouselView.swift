import SwiftUI

/// A horizontal strip of upcoming songs in the setlist, all the same size
/// — matching Playback's song-switcher carousel, where every card reads at
/// a glance rather than only the current one. Each card shows its own
/// tempo/time-signature/key, since those belong to that song, not just the
/// one currently loaded. Cards use a generated color instead of real album
/// art, since there's no artwork yet.
struct SongCarouselView: View {
    let songs: [Song]
    @Binding var currentSong: Song?

    private static let cardSize: CGFloat = 168

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(songs) { song in
                    Button {
                        currentSong = song
                    } label: {
                        card(for: song)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private func card(for song: Song) -> some View {
        let isCurrent = song.persistentModelID == currentSong?.persistentModelID

        return VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [
                        Color(hue: song.cardHue, saturation: 0.6, brightness: 0.55),
                        Color(hue: song.cardHue, saturation: 0.8, brightness: 0.28),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: Self.cardSize, height: Self.cardSize)
                .overlay(
                    Text(song.title.first.map(String.init) ?? "?")
                        .font(.system(size: 58, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isCurrent ? Color.white : .clear, lineWidth: 3)
                )

            Text(song.title)
                .font(.callout)
                .fontWeight(isCurrent ? .bold : .regular)
                .lineLimit(1)

            Text(cardSubtitle(for: song))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: Self.cardSize)
    }

    private func cardSubtitle(for song: Song) -> String {
        var parts = ["\(formatted(song.bpm)) BPM", "\(song.beatsPerBar)/4"]
        if !song.key.isEmpty { parts.append(song.key) }
        return parts.joined(separator: " · ")
    }

    private func formatted(_ bpm: Double) -> String {
        bpm.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(bpm)) : String(format: "%.1f", bpm)
    }
}
