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
                    .frame(height: 44)
            } else {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        HStack(spacing: 2) {
                            ForEach(song.sortedSections) { section in
                                sectionBlock(section, totalBars: max(song.totalBars, 1), totalWidth: geo.size.width)
                            }
                        }
                        if engine.isPlaying {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 2)
                                .offset(x: playheadOffset(totalWidth: geo.size.width))
                        }
                    }
                }
                .frame(height: 44)
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

    private func sectionBlock(_ section: SongSection, totalBars: Int, totalWidth: CGFloat) -> some View {
        let widthFraction = Double(section.lengthBars) / Double(totalBars)
        return RoundedRectangle(cornerRadius: 4)
            .fill(color(for: section.colorName))
            .frame(width: max(totalWidth * widthFraction - 2, 4), height: 44)
            .overlay(
                Text(section.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.black.opacity(0.8))
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            )
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
