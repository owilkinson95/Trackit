import SwiftUI
import SwiftData

/// The arrangement timeline — colored blocks per section, sized
/// proportionally to each section's bar length, with a playhead that
/// sweeps across while playing. There's no audio file to show a real
/// waveform of, so sections (not amplitude) are what's actually visualized.
struct TimelineView: View {
    @Bindable var song: Song
    @ObservedObject var engine: ClickEngine
    @Environment(\.modelContext) private var modelContext

    @State private var newSectionLabel = ""
    @State private var showingAddSection = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Arrangement").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingAddSection = true
                } label: {
                    Label("Add Section", systemImage: "plus")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }

            if song.sections.isEmpty {
                Text("No sections yet — tap Add Section to sketch out the arrangement.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(height: 56)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
            } else {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        HStack(spacing: 2) {
                            ForEach(Array(song.sortedSections.enumerated()), id: \.element.id) { index, section in
                                sectionBlock(section, index: index, totalBars: max(song.totalBars, 1), totalWidth: geo.size.width)
                            }
                        }
                        if engine.isPlaying {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 2)
                                .shadow(color: .white.opacity(0.6), radius: 3)
                                .offset(x: playheadOffset(totalWidth: geo.size.width))
                        }
                    }
                }
                .frame(height: 56)
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

    private func sectionBlock(_ section: SongSection, index: Int, totalBars: Int, totalWidth: CGFloat) -> some View {
        let widthFraction = Double(section.lengthBars) / Double(totalBars)
        let blockWidth = max(totalWidth * widthFraction - 2, 4)
        return VStack(spacing: 3) {
            Text("\(index + 1)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 16, height: 16)
                .background(Circle().fill(color(for: section.colorName)))

            RoundedRectangle(cornerRadius: 4)
                .fill(color(for: section.colorName).opacity(0.35))
                .overlay(tickTexture(color: color(for: section.colorName)))
                .overlay(
                    Text(section.label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                )
                .frame(width: blockWidth, height: 32)
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
}
