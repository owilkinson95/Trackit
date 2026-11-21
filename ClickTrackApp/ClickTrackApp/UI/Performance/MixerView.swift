import SwiftUI
import SwiftData

/// The bottom mixer strip — Click, each stem Track, and Master, each a
/// vertical fader with solo/mute. Track volume/mute/solo are fully real
/// and persisted, ready for real stem audio; until the app can import and
/// play actual stem files, moving a Track's fader has no audible effect of
/// its own — only Click and Master are wired to anything audible right now.
struct MixerView: View {
    @ObservedObject var engine: ClickEngine
    @Bindable var song: Song
    @Environment(\.modelContext) private var modelContext

    @State private var newTrackName = ""
    @State private var showingAddTrack = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !song.tracks.isEmpty {
                Text("Track faders are ready for real stem audio — they're silent until that's added.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 14) {
                    FaderStrip(
                        name: "Click",
                        color: .green,
                        volume: Binding(get: { engine.clickVolume }, set: { engine.clickVolume = $0 }),
                        isMuted: Binding(get: { engine.clickMuted }, set: { engine.clickMuted = $0 }),
                        isSoloed: .constant(false),
                        showsSolo: false,
                        onRename: nil,
                        onDelete: nil
                    )

                    ForEach(song.sortedTracks) { track in
                        FaderStrip(
                            name: track.name,
                            color: .blue,
                            volume: Binding(get: { track.volume }, set: { track.volume = $0 }),
                            isMuted: Binding(get: { track.isMuted }, set: { track.isMuted = $0 }),
                            isSoloed: Binding(get: { track.isSoloed }, set: { track.isSoloed = $0 }),
                            showsSolo: true,
                            onRename: { track.name = $0 },
                            onDelete: { modelContext.delete(track) }
                        )
                    }

                    Button {
                        showingAddTrack = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill").font(.title2)
                            Text("Track").font(.caption2)
                        }
                        .frame(width: 70, height: 160)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    FaderStrip(
                        name: "Master",
                        color: .white,
                        volume: Binding(get: { engine.masterVolume }, set: { engine.masterVolume = $0 }),
                        isMuted: .constant(false),
                        isSoloed: .constant(false),
                        showsSolo: false,
                        showsMute: false,
                        onRename: nil,
                        onDelete: nil
                    )
                }
                .padding(.horizontal)
            }
        }
        .alert("New Track", isPresented: $showingAddTrack) {
            TextField("Name (e.g. Drums)", text: $newTrackName)
            Button("Cancel", role: .cancel) { newTrackName = "" }
            Button("Add") {
                let trimmed = newTrackName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                let track = Track(name: trimmed, order: song.tracks.count, song: song)
                modelContext.insert(track)
                newTrackName = ""
            }
        }
    }
}

private struct FaderStrip: View {
    let name: String
    let color: Color
    @Binding var volume: Double
    @Binding var isMuted: Bool
    @Binding var isSoloed: Bool
    var showsSolo: Bool = true
    var showsMute: Bool = true
    var onRename: ((String) -> Void)?
    var onDelete: (() -> Void)?

    @State private var nameText = ""

    var body: some View {
        VStack(spacing: 8) {
            if showsSolo {
                Button {
                    isSoloed.toggle()
                } label: {
                    Text("S")
                        .font(.caption.bold())
                        .frame(width: 24, height: 24)
                        .background(isSoloed ? Color.yellow : Color.gray.opacity(0.3))
                        .foregroundColor(isSoloed ? .black : .white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 24, height: 24)
            }

            Slider(value: $volume, in: 0...1)
                .frame(width: 120)
                .rotationEffect(.degrees(-90))
                .frame(width: 36, height: 120)
                .tint(color)

            if showsMute {
                Button {
                    isMuted.toggle()
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.caption)
                        .frame(width: 24, height: 24)
                        .background(isMuted ? Color.red : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 24, height: 24)
            }

            if onRename != nil {
                TextField("Name", text: $nameText, onCommit: { onRename?(nameText) })
                    .multilineTextAlignment(.center)
                    .font(.caption2)
                    .frame(width: 70)
            } else {
                Text(name).font(.caption2).lineLimit(1)
            }

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 70)
        .onAppear { nameText = name }
    }
}
