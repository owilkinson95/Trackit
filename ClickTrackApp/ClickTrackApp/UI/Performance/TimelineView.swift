import SwiftUI
import SwiftData

/// The arrangement timeline — a slim "Click" lane showing the infinite
/// click loop, above a bigger, horizontally scrollable row of arrangement
/// section blocks sized proportionally to each section's bar length, with
/// a playhead that sweeps across while playing. Sections are fixed-width
/// per bar rather than squeezed to fit the screen, so a long arrangement
/// scrolls instead of shrinking illegibly. There's no audio file to show a
/// real waveform of, so the click lane and sections (not amplitude) are
/// what's actually visualized.
struct TimelineView: View {
    @Bindable var song: Song
    @ObservedObject var engine: ClickEngine
    @Environment(\.modelContext) private var modelContext

    @State private var newSectionLabel = ""
    @State private var showingAddSection = false

    /// Pixels per bar in the arrangement row — fixed, not proportional to
    /// the available width, so sections stay a readable size and the row
    /// scrolls instead of shrinking when the arrangement runs long.
    private static let barWidth: CGFloat = 40
    private static let sectionBlockHeight: CGFloat = 86
    private static let badgeSize: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            clickLane

            HStack {
                Text("Arrangement").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingAddSection = true
                } label: {
                    Label("Add Section", systemImage: "plus")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }

            if song.sections.isEmpty {
                Text("No sections yet — tap Add Section to sketch out the arrangement.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(height: Self.sectionBlockHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            } else {
                let totalBars = max(song.totalBars, 1)
                let contentWidth = CGFloat(totalBars) * Self.barWidth

                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .leading) {
                        HStack(spacing: 2) {
                            ForEach(Array(song.sortedSections.enumerated()), id: \.element.id) { index, section in
                                sectionBlock(section, index: index)
                            }
                        }
                        if engine.isPlaying {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 2)
                                .shadow(color: .white.opacity(0.6), radius: 3)
                                .offset(x: playheadOffset(totalWidth: contentWidth))
                        }
                    }
                    .frame(width: contentWidth, alignment: .leading)
                }
                .frame(height: Self.sectionBlockHeight + Self.badgeSize + 8)
            }
        }
        .alert("New Section", isPresented: $showingAddSection) {
            TextField("Label (e.g. Verse 1)", text: $newSectionLabel)
            Button("Cancel", role: .cancel) { newSectionLabel = "" }
            Button("Add") {
                let trimmed = newSectionLabel.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                let colorName = SongSection.colorNames[song.sections.count % SongSection.colorNames.count]
                let section = SongSection(label: trimmed, order: song.sections.count, lengthBars: 8, colorName: colorName, song: song)
                modelContext.insert(section)
                newSectionLabel = ""
            }
        }
    }

    private func sectionBlock(_ section: SongSection, index: Int) -> some View {
        let blockWidth = max(CGFloat(section.lengthBars) * Self.barWidth - 2, 4)
        return VStack(spacing: 4) {
            Text("\(index + 1)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.black)
                .frame(width: Self.badgeSize, height: Self.badgeSize)
                .background(Circle().fill(color(for: section.colorName)))

            RoundedRectangle(cornerRadius: 6)
                .fill(color(for: section.colorName).opacity(0.35))
                .overlay(tickTexture(color: color(for: section.colorName)))
                .overlay(
                    Text(section.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                )
                .frame(width: blockWidth, height: Self.sectionBlockHeight)
        }
        .frame(width: blockWidth)
    }

    /// Purely decorative repeating tick marks to suggest the dense,
    /// grid-like texture of Playback's arrangement bands — not a rendering
    /// of real audio, since there's no audio file to analyze yet.
    private func tickTexture(color: Color) -> some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(0..<max(Int(geo.size.width / 5), 0), id: \.self) { _ in
                    Rectangle().fill(color.opacity(0.4)).frame(width: 1)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func playheadOffset(totalWidth: CGFloat) -> CGFloat {
        let total = song.nominalDurationSeconds
        guard total > 0 else { return 0 }
        let fraction = min(engine.elapsedSeconds / total, 1.0)
        return totalWidth * CGFloat(fraction)
    }

    private func color(for name: String) -> Color {
        switch name {
        case "yellow": return .yellow
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        default: return .gray
        }
    }

    // MARK: - Click lane

    /// A slim, always-present, horizontally scrollable lane visualizing the
    /// infinite click loop — tiled indefinitely rather than tied to the
    /// song's bar count, since the click keeps looping regardless of the
    /// arrangement. Bar height encodes each tick's role (accent, beat,
    /// subdivision), colored to match the Accent/Beat mixer faders. This is
    /// a generated illustration of the loop's rhythm, not a rendering of
    /// real audio.
    private var clickLane: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Click").font(.subheadline).foregroundStyle(.secondary)
                Image(systemName: "infinity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(0..<Self.clickLaneRepeatCount, id: \.self) { _ in
                        clickBar
                    }
                }
            }
            .frame(height: Self.clickLaneHeight)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
        }
    }

    private static let clickLaneHeight: CGFloat = 32
    private static let clickLaneRepeatCount = 24

    private var clickBar: some View {
        let ticksPerBar = max(engine.pattern.beatsPerBar * engine.pattern.subdivision, 1)
        return HStack(spacing: 3) {
            ForEach(0..<ticksPerBar, id: \.self) { tick in
                clickTick(tick: tick)
            }
        }
        .padding(.horizontal, 4)
    }

    private func clickTick(tick: Int) -> some View {
        let isAccent = engine.pattern.accentFirstBeat && tick == 0
        let isStrong = tick % engine.pattern.subdivision == 0
        let height: CGFloat = isAccent ? 24 : (isStrong ? 16 : 9)
        let color: Color = isAccent ? .green : .white.opacity(isStrong ? 0.7 : 0.3)
        return RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .frame(width: 3, height: height)
            .frame(height: Self.clickLaneHeight, alignment: .center)
    }
}
