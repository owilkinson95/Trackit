import SwiftUI

/// A horizontal strip of upcoming songs in the setlist, current song
/// enlarged — matching Playback's song-switcher carousel. Cards use a
/// generated color instead of real album art, since there's no artwork yet.
struct SongCarouselView: View {
    let songs: [Song]
    @Binding var currentSong: Song?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 12) {
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
        let size: CGFloat = isCurrent ? 210 : 150

        return VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(
                    colors: [
                        Color(hue: song.cardHue, saturation: 0.6, brightness: 0.55),
                        Color(hue: song.cardHue, saturation: 0.8, brightness: 0.28),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: size, height: size)
                .overlay(
                    Text(song.title.first.map(String.init) ?? "?")
                        .font(.system(size: isCurrent ? 76 : 52, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(isCurrent ? Color.white : .clear, lineWidth: 3)
                )

            Text(song.title)
                .font(isCurrent ? .title3 : .callout)
                .fontWeight(isCurrent ? .bold : .regular)
                .lineLimit(1)
            if !song.key.isEmpty {
                Text("(\(song.key))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: max(size, 120))
    }
}
