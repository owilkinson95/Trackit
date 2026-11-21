import SwiftUI
import SwiftData

/// Add/edit form for a single song. Works for both a brand-new, unsaved
/// Song (inserted into the context only on Save) and an existing one.
struct SongEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var song: Song
    var isNew: Bool

    @State private var tapTempo = TapTempo()
    @State private var bpmText: String = ""
    @State private var showingTempoSearch = false

    private let subdivisionLabels = ["1/4", "1/8", "1/8T", "1/16"]

    var body: some View {
        Form {
            Section("Song") {
                TextField("Title", text: $song.title)
                TextField("Artist", text: $song.artist)
                TextField("Key (e.g. G, Eb, Bbm)", text: $song.key)
            }

            Section("Tempo") {
                HStack {
                    TextField("BPM", text: $bpmText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .onSubmit(commitBPMText)
                    Button("Tap") {
                        if let newBPM = tapTempo.tap() {
                            song.bpm = newBPM.rounded()
                            bpmText = formatted(song.bpm)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showingTempoSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                }

                Stepper("Beats per bar: \(song.beatsPerBar)", value: $song.beatsPerBar, in: 1...12)

                Picker("Subdivision", selection: $song.subdivision) {
                    ForEach(Array(subdivisionLabels.enumerated()), id: \.offset) { index, label in
                        Text(label).tag(index + 1)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Notes") {
                TextField("Notes", text: $song.notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .onAppear { bpmText = formatted(song.bpm) }
        .sheet(isPresented: $showingTempoSearch) {
            TempoSearchView(initialTitle: song.title, initialArtist: song.artist) { result in
                song.bpm = result.bpm
                bpmText = formatted(result.bpm)
                if !result.key.isEmpty { song.key = result.key }
                if song.artist.isEmpty && !result.artist.isEmpty { song.artist = result.artist }
            }
        }
        .navigationTitle(isNew ? "New Song" : "Edit Song")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    commitBPMText()
                    if isNew {
                        modelContext.insert(song)
                    }
                    dismiss()
                }
                .disabled(song.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if isNew {
                        modelContext.delete(song)
                    }
                    dismiss()
                }
            }
        }
    }

    private func commitBPMText() {
        if let value = Double(bpmText), value > 0 {
            song.bpm = value
        }
    }

    private func formatted(_ bpm: Double) -> String {
        bpm.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(bpm)) : String(format: "%.1f", bpm)
    }
}
