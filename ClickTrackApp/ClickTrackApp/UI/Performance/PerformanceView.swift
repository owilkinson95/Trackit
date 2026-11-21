import SwiftUI

/// The full setlist performance screen — song carousel, arrangement
/// timeline, transport, and mixer — matching Playback's performance view.
struct PerformanceView: View {
    @EnvironmentObject private var engine: ClickEngine
    @Bindable var setlist: Setlist

    @State private var currentSong: Song?

    private var songs: [Song] {
        setlist.sortedItems.compactMap { $0.song }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                header
                    .padding(.horizontal)
                    .padding(.top, 8)

                if let currentSong {
                    SongCarouselView(songs: songs, currentSong: Binding(
                        get: { currentSong },
                        set: { selectSong($0) }
                    ))

                    TimelineView(song: currentSong, engine: engine)
                        .padding(.horizontal)

                    Spacer(minLength: 0)

                    MixerView(engine: engine, song: currentSong)
                        .padding(.bottom, 12)
                } else {
                    Spacer()
                    Text("Add songs to this setlist to start a performance.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .foregroundColor(.white)
        .navigationTitle(setlist.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if currentSong == nil {
                selectSong(songs.first)
            }
        }
        .onDisappear {
            engine.stop()
        }
    }

    private var header: some View {
        HStack {
            if let currentSong {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentSong.title).font(.headline)
                    Text("\(formatted(currentSong.bpm)) BPM · \(currentSong.beatsPerBar)/\(currentSong.subdivision == 1 ? 4 : currentSong.beatsPerBar)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(elapsedText)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
            playStopButton
        }
    }

    private var elapsedText: String {
        let elapsed = Int(engine.elapsedSeconds)
        return String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    private var playStopButton: some View {
        Button {
            engine.isPlaying ? engine.stop() : engine.start()
        } label: {
            Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(engine.isPlaying ? Color.red : Color.green)
                .foregroundColor(.white)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func selectSong(_ song: Song?) {
        guard let song else { return }
        if engine.isPlaying { engine.stop() }
        currentSong = song
        engine.loadSong(song)
    }

    private func formatted(_ bpm: Double) -> String {
        bpm.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(bpm)) : String(format: "%.1f", bpm)
    }
}
