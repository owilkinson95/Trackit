import SwiftUI

/// The full setlist performance screen — song carousel, arrangement
/// timeline, transport, and mixer — matching Playback's performance view.
/// Transport controls and settings live in the navigation bar rather than a
/// separate toolbar row, leaving more vertical room for the song carousel
/// and the arrangement timeline below it.
struct PerformanceView: View {
    @EnvironmentObject private var engine: ClickEngine
    @Bindable var setlist: Setlist

    @State private var currentSong: Song?
    @State private var showingRouting = false
    @State private var showingEditor = false
    @State private var showingClickSettings = false

    private var songs: [Song] {
        setlist.sortedItems.compactMap { $0.song }
    }

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.035, blue: 0.04).ignoresSafeArea()

            VStack(spacing: 14) {
                if let currentSong {
                    songHeader(for: currentSong)

                    SongCarouselView(songs: songs, currentSong: Binding(
                        get: { currentSong },
                        set: { selectSong($0) }
                    ))

                    TimelineView(song: currentSong, engine: engine)
                        .padding(.horizontal)

                    MixerView(engine: engine, song: currentSong)
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer()
                    Text("Add songs to this setlist to start a performance.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.top, 10)
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
        .sheet(isPresented: $showingClickSettings) {
            ClickGuideSettingsView()
        }
        .sheet(isPresented: $showingEditor) {
            if let currentSong {
                NavigationStack {
                    SongEditorView(song: currentSong, isNew: false)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarIconButton("gobackward") { restart() }

                Button {
                    engine.isPlaying ? engine.stop() : engine.start()
                } label: {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(engine.isPlaying ? Color.red : Color.green)
                        .frame(width: 72, height: 40)
                        .overlay(
                            Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .buttonStyle(.plain)

                toolbarIconButton("metronome") { showingClickSettings = true }
                toolbarIconButton("slider.horizontal.3") { showingRouting = true }
                toolbarIconButton("pencil") { showingEditor = true }
            }
        }
    }

    /// Tempo/time-signature/elapsed for the current song — part of the song
    /// area rather than a separate toolbar, since it's information about
    /// *this song*, not a transport control.
    private func songHeader(for song: Song) -> some View {
        HStack(spacing: 16) {
            statStack(formatted(song.bpm), "BPM")
            divider
            statStack("\(song.beatsPerBar)/4", "TIME")
            divider
            statStack(elapsedText, totalText)
            Spacer()
        }
        .padding(.horizontal)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 28)
    }

    private func statStack(_ primary: String, _ secondary: String) -> some View {
        VStack(spacing: 2) {
            Text(primary)
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text(secondary)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .tracking(0.5)
        }
    }

    private func toolbarIconButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15))
                .frame(width: 32, height: 32)
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
