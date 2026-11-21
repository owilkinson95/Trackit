import SwiftUI
import SwiftData

/// The bottom mixer strip — Accent, 1/4, 1/8, 1/16, Guide, each stem
/// Track, and Master, each a vertical fader with solo/mute. Accent/1-4/
/// 1-8/1-16 split the click into its downbeat and subdivision tiers so
/// each can be balanced on its own, matching Playback's separate click
/// faders — whichever tiers aren't part of the current subdivision
/// setting are simply silent, so their faders have no audible effect
/// until a finer subdivision is chosen. Guide is a reference pulse, off by
/// default (see `GuideMode` in Click & Guide settings). Track volume/mute/
/// solo are fully real and persisted, ready for real stem audio; until the
/// app can import and play actual stem files, moving a Track's fader has
/// no audible effect of its own.
///
/// Fills whatever vertical space its parent gives it — Playback's mixer is
/// a full console filling most of the screen, not a thin strip pinned to
/// the bottom with the rest of the screen left empty.
struct MixerView: View {
    @ObservedObject var engine: ClickEngine
    @Bindable var song: Song
    @Environment(\.modelContext) private var modelContext

    @State private var newTrackName = ""
    @State private var showingAddTrack = false

    private static let trackColors: [Color] = [.cyan, .orange, .purple, .pink, .mint, .indigo, .teal]
    /// Fixed-height chrome around each fader (solo button, mute button,
    /// label, spacing) that isn't available for the fader's own travel.
    private static let stripChrome: CGFloat = 132

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !song.tracks.isEmpty {
                Text("Track faders are ready for real stem audio — they're silent until that's added.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            GeometryReader { geo in
                let faderHeight = max(geo.size.height - Self.stripChrome, 90)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 18) {
                        FaderStrip(
                            name: "Accent",
                            color: .green,
                            volume: Binding(get: { engine.accentVolume }, set: { engine.accentVolume = $0 }),
                            isMuted: Binding(get: { engine.accentMuted }, set: { engine.accentMuted = $0 }),
                            isSoloed: .constant(false),
                            showsSolo: false,
                            faderHeight: faderHeight,
                            onRename: nil,
                            onDelete: nil
                        )

                        FaderStrip(
                            name: "1/4",
                            color: .white,
                            volume: Binding(get: { engine.quarterVolume }, set: { engine.quarterVolume = $0 }),
                            isMuted: Binding(get: { engine.quarterMuted }, set: { engine.quarterMuted = $0 }),
                            isSoloed: .constant(false),
                            showsSolo: false,
                            faderHeight: faderHeight,
                            onRename: nil,
                            onDelete: nil
                        )

                        FaderStrip(
                            name: "1/8",
                            color: .white.opacity(0.75),
                            volume: Binding(get: { engine.eighthVolume }, set: { engine.eighthVolume = $0 }),
                            isMuted: Binding(get: { engine.eighthMuted }, set: { engine.eighthMuted = $0 }),
                            isSoloed: .constant(false),
                            showsSolo: false,
                            faderHeight: faderHeight,
                            onRename: nil,
                            onDelete: nil
                        )

                        FaderStrip(
                            name: "1/16",
                            color: .white.opacity(0.55),
                            volume: Binding(get: { engine.sixteenthVolume }, set: { engine.sixteenthVolume = $0 }),
                            isMuted: Binding(get: { engine.sixteenthMuted }, set: { engine.sixteenthMuted = $0 }),
                            isSoloed: .constant(false),
                            showsSolo: false,
                            faderHeight: faderHeight,
                            onRename: nil,
                            onDelete: nil
                        )

                        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1).frame(maxHeight: .infinity)

                        FaderStrip(
                            name: "Guide",
                            color: .yellow,
                            volume: Binding(get: { engine.guideVolume }, set: { engine.guideVolume = $0 }),
                            isMuted: Binding(get: { engine.guideMuted }, set: { engine.guideMuted = $0 }),
                            isSoloed: .constant(false),
                            showsSolo: false,
                            faderHeight: faderHeight,
                            onRename: nil,
                            onDelete: nil
                        )

                        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1).frame(maxHeight: .infinity)

                        ForEach(Array(song.sortedTracks.enumerated()), id: \.element.id) { index, track in
                            FaderStrip(
                                name: track.name,
                                color: Self.trackColors[index % Self.trackColors.count],
                                volume: Binding(get: { track.volume }, set: { track.volume = $0 }),
                                isMuted: Binding(get: { track.isMuted }, set: { track.isMuted = $0 }),
                                isSoloed: Binding(get: { track.isSoloed }, set: { track.isSoloed = $0 }),
                                showsSolo: true,
                                faderHeight: faderHeight,
                                onRename: { track.name = $0 },
                                onDelete: { modelContext.delete(track) }
                            )
                        }

                        Button {
                            showingAddTrack = true
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill").font(.title)
                                Text("Track").font(.callout)
                            }
                            .frame(width: 72, height: faderHeight + Self.stripChrome)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)

                        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1).frame(maxHeight: .infinity)

                        FaderStrip(
                            name: "Master",
                            color: .white,
                            volume: Binding(get: { engine.masterVolume }, set: { engine.masterVolume = $0 }),
                            isMuted: .constant(false),
                            isSoloed: .constant(false),
                            showsSolo: false,
                            showsMute: false,
                            faderHeight: faderHeight,
                            onRename: nil,
                            onDelete: nil
                        )
                    }
                    .padding(.horizontal)
                    .frame(minHeight: geo.size.height)
                }
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
    var faderHeight: CGFloat
    var onRename: ((String) -> Void)?
    var onDelete: (() -> Void)?

    @State private var nameText = ""

    var body: some View {
        VStack(spacing: 10) {
            if showsSolo {
                Button {
                    isSoloed.toggle()
                } label: {
                    Text("S")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(isSoloed ? Color.yellow : Color.white.opacity(0.12))
                        .foregroundColor(isSoloed ? .black : .white.opacity(0.7))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 28, height: 28)
            }

            FaderControl(value: $volume, tint: color, trackHeight: faderHeight)

            if showsMute {
                Button {
                    isMuted.toggle()
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.system(size: 13))
                        .frame(width: 28, height: 28)
                        .background(isMuted ? Color.red : Color.white.opacity(0.12))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 28, height: 28)
            }

            if onRename != nil {
                TextField("Name", text: $nameText, onCommit: { onRename?(nameText) })
                    .multilineTextAlignment(.center)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .frame(width: 72)
                    .onAppear { nameText = name }
            } else {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color == .white ? .white.opacity(0.85) : color)
                    .lineLimit(1)
            }

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 72)
    }
}

/// A real mixer fader — a thin track with a horizontal cap, not a stock
/// iOS slider knob — so the mixer actually reads as pro-audio chrome.
private struct FaderControl: View {
    @Binding var value: Double
    var tint: Color
    var trackHeight: CGFloat

    private let capSize = CGSize(width: 38, height: 13)

    private var travel: CGFloat { trackHeight - capSize.height }
    private var capOffset: CGFloat { (1 - CGFloat(value)) * travel }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.15))
                .frame(width: 4, height: trackHeight)
                .frame(maxWidth: .infinity)

            RoundedRectangle(cornerRadius: 2)
                .fill(tint.opacity(0.8))
                .frame(width: 4, height: max(travel - capOffset + capSize.height / 2, 0))
                .frame(maxWidth: .infinity)
                .offset(y: capOffset + capSize.height / 2)

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white)
                .frame(width: capSize.width, height: capSize.height)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.25), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                .offset(y: capOffset)
        }
        .frame(width: 44, height: trackHeight)
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
