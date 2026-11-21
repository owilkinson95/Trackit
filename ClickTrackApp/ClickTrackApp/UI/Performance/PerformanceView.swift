import SwiftUI

/// The full setlist performance screen — song carousel, arrangement
/// timeline, transport, and mixer — matching Playback's performance view.
struct PerformanceView: View {
    @EnvironmentObject private var engine: ClickEngine
    @Bindable var setlist: Setlist

    @State private var currentSong: Song?
    @State private var showingRouting = false
    @State private var showingEditor = false

    private var songs: [Song] {
        setlist.sortedItems.compactMap { $0.song }
    }

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.035, blue: 0.04).ignoresSafeArea()

            VStack(spacing: 14) {
                toolbar
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
        .sheet(isPresented: $showingRouting) {
            OutputRoutingView()
        }
        .sheet(isPresented: $showingEditor) {
            if let currentSong {
                NavigationStack {
                    SongEditorView(song: currentSong, isNew: false)
                }
            }
        }
    }

    /// One dense dark bar — tempo, elapsed/total, transport, and quick
    /// actions — matching Playback's compact toolbar rather than floating
    /// text on a bare background.
    private var toolbar: some View {
        HStack(spacing: 16) {
            if let currentSong {
                statStack(formatted(currentSong.bpm), "BPM")
                divider
                statStack("\(currentSong.beatsPerBar)/4", "TIME")
                divider
            }

            statStack(elapsedText, totalText)

            Spacer()

            toolbarIconButton("gobackward") { restart() }

            Button {
                engine.isPlaying ? engine.stop() : engine.start()
            } label: {
                RoundedRectangle(cornerRadius: 10)
                    .fill(engine.isPlaying ? Color.red : Color.green)
                    .frame(width: 56, height: 40)
                    .overlay(
                        Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .buttonStyle(.plain)

            toolbarIconButton("slider.horizontal.3") { showingRouting = true }
            toolbarIconButton("pencil") { showingEditor = true }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 28)
    }

    private func statStack(_ primary: String, _ secondary: String) -> some View {
        VStack(spacing: 1) {
            Text(primary)
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text(secondary)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .tracking(0.5)
        }
    }

    private func toolbarIconButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .foregroundColor(.white.opacity(0.85))
        }
        .buttonStyle(.plain)
    }

    private var elapsedText: String {
        let elapsed = Int(engine.elapsedSeconds)
        return String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    private var totalText: String {
        guard let currentSong, currentSong.nominalDurationSeconds > 0 else { return "--:--" }
        let total = Int(currentSong.nominalDurationSeconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func restart() {
        guard engine.isPlaying else { return }
        engine.stop()
        engine.start()
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
