import SwiftUI
import SwiftData

/// One wide, horizontally scrollable timeline — the infinite click's
/// rhythm running the full width as a continuous tick "waveform," with the
/// arrangement's section blocks layered on top of it — matching Playback,
/// where the click and the arrangement share a single scrollable strip
/// rather than two separate boxes. Sections are fixed-width per bar rather
/// than squeezed to fit the screen, so a long arrangement scrolls instead
/// of shrinking illegibly, and the click ticks share that same per-bar
/// grid so the two stay aligned. There's no audio file to show a real
/// waveform of, so the ticks (not amplitude) are what's actually
/// visualized.
struct TimelineView: View {
    @Bindable var song: Song
    @ObservedObject var engine: ClickEngine
    @Environment(\.modelContext) private var modelContext

    @State private var newSectionLabel = ""
    @State private var showingAddSection = false

    /// Pixels per bar — fixed, not proportional to the available width, so
    /// sections and ticks stay a readable size and the strip scrolls
    /// instead of shrinking when the arrangement runs long.
    private static let barWidth: CGFloat = 40
    private static let sectionBlockHeight: CGFloat = 70
    private static let badgeSize: CGFloat = 28
    private static let laneHeight: CGFloat = 112
    /// How many bars wide the strip is when there's no arrangement yet, so
    /// the click's infinite loop still reads as a long scrollable wave
    /// rather than a tiny empty box.
    private static let minimumBars = 32

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Arrangement").font(.subheadline).foregroundStyle(.secondary)
                Image(systemName: "infinity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingAddSection = true
                } label: {
                    Label("Add Section", systemImage: "plus")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }

            let totalBars = max(song.totalBars, Self.minimumBars)
            let contentWidth = CGFloat(totalBars) * Self.barWidth

            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .leading) {
                    clickTicks(totalBars: totalBars)

                    if song.sections.isEmpty {
                        Text("No sections yet — tap Add Section to sketch out the arrangement.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .frame(height: Self.laneHeight, alignment: .leading)
                    } else {
                        HStack(spacing: 2) {
                            ForEach(Array(song.sortedSections.enumerated()), id: \.element.id) { index, section in
                                sectionBlock(section, index: index)
                            }
                        }
                        .frame(height: Self.laneHeight, alignment: .bottom)
                    }

                    if engine.isPlaying {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2)
                            .shadow(color: .white.opacity(0.6), radius: 3)
                            .offset(x: playheadOffset(totalWidth: contentWidth))
                    }
                }
                .frame(width: contentWidth, height: Self.laneHeight, alignment: .leading)
            }
            .frame(height: Self.laneHeight)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
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
                .fill(color(for: section.colorName).opacity(0.3))
                .overlay(
                    Text(section.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color(for: section.colorName).opacity(0.6), lineWidth: 1)
                )
                .frame(width: blockWidth, height: Self.sectionBlockHeight)
        }
        .frame(width: blockWidth)
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

    // MARK: - Click ticks

    /// The infinite click's rhythm, drawn as a continuous tick "waveform"
    /// across the whole strip, one bar at a time on the same per-bar grid
    /// as the section blocks above it — so the two stay aligned as you
    /// scroll. The click always generates a fixed sixteenth-note grid (see
    /// `ClickGenerator`), so this always shows all four tiers — Accent,
    /// 1/4, 1/8, 1/16 — regardless of which mixer faders are turned up.
    /// This is a generated illustration of the loop's rhythm, not a
    /// rendering of real audio.
    private static let ticksPerBeat = 4

    private func clickTicks(totalBars: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<totalBars, id: \.self) { _ in
                clickBar
            }
        }
    }

    private var clickBar: some View {
        let ticksPerBar = max(engine.pattern.beatsPerBar * Self.ticksPerBeat, 1)
        return HStack(spacing: 3) {
            ForEach(0..<ticksPerBar, id: \.self) { tick in
                clickTick(tick: tick)
            }
        }
        .frame(width: Self.barWidth, height: Self.laneHeight)
    }

    private func clickTick(tick: Int) -> some View {
        let isAccent = engine.pattern.accentFirstBeat && tick == 0
        let posInBeat = tick % Self.ticksPerBeat
        let height: CGFloat = isAccent ? 46 : (posInBeat == 0 ? 30 : (posInBeat == 2 ? 22 : 14))
        let color: Color = isAccent ? .green.opacity(0.8) : .white.opacity(posInBeat == 0 ? 0.45 : (posInBeat == 2 ? 0.3 : 0.18))
        return RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .frame(width: 3, height: height)
            .frame(height: Self.laneHeight, alignment: .center)
    }
}
