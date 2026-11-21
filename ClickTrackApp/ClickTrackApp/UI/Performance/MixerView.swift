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

    private static let trackColors: [Color] = [.cyan, .orange, .purple, .pink, .mint, .indigo, .teal]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !song.tracks.isEmpty {
                Text("Track faders are ready for real stem audio — they're silent until that's added.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 10) {
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

                    Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 170)

                    ForEach(Array(song.sortedTracks.enumerated()), id: \.element.id) { index, track in
                        FaderStrip(
                            name: track.name,
                            color: Self.trackColors[index % Self.trackColors.count],
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
                            Image(systemName: "plus.circle.fill").font(.title3)
                            Text("Track").font(.caption2)
                        }
                        .frame(width: 56, height: 170)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 170)

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
                .padding(.vertical, 12)
            }
            .background(Color(white: 0.08))
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
        VStack(spacing: 6) {
            if showsSolo {
                Button {
                    isSoloed.toggle()
                } label: {
                    Text("S")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 20, height: 20)
                        .background(isSoloed ? Color.yellow : Color.white.opacity(0.12))
                        .foregroundColor(isSoloed ? .black : .white.opacity(0.7))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 20, height: 20)
            }

            FaderControl(value: $volume, tint: color)

            if showsMute {
                Button {
                    isMuted.toggle()
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.system(size: 10))
                        .frame(width: 20, height: 20)
                        .background(isMuted ? Color.red : Color.white.opacity(0.12))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 20, height: 20)
            }

            if onRename != nil {
                TextField("Name", text: $nameText, onCommit: { onRename?(nameText) })
                    .multilineTextAlignment(.center)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                    .frame(width: 56)
            } else {
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(color == .white ? .white.opacity(0.85) : color)
                    .lineLimit(1)
            }

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 56)
        .onAppear { nameText = name }
    }
}

/// A real mixer fader — a thin track with a horizontal cap, not a stock
/// iOS slider knob — so the mixer actually reads as pro-audio chrome.
private struct FaderControl: View {
    @Binding var value: Double
    var tint: Color
    var trackHeight: CGFloat = 130

    private let capSize = CGSize(width: 30, height: 10)

    private var travel: CGFloat { trackHeight - capSize.height }
    private var capOffset: CGFloat { (1 - CGFloat(value)) * travel }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.white.opacity(0.15))
                .frame(width: 3, height: trackHeight)
                .frame(maxWidth: .infinity)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(tint.opacity(0.8))
                .frame(width: 3, height: max(travel - capOffset + capSize.height / 2, 0))
                .frame(maxWidth: .infinity)
                .offset(y: capOffset + capSize.height / 2)

            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.white)
                .frame(width: capSize.width, height: capSize.height)
                .overlay(RoundedRectangle(cornerRadius: 2.5).stroke(Color.black.opacity(0.25), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1)
                .offset(y: capOffset)
        }
        .frame(width: 36, height: trackHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    let y = min(max(drag.location.y - capSize.height / 2, 0), travel)
                    value = Double(1 - y / travel)
                }
        )
    }
}
