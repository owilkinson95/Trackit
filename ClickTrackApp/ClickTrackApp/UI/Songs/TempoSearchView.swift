import SwiftUI

/// Search GetSongBPM for a song's tempo/key and apply it to the song being edited.
/// Falls back to asking for a free API key the first time it's used.
struct TempoSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("getSongBPMAPIKey") private var apiKey: String = ""

    @State private var titleQuery: String
    @State private var artistQuery: String
    @State private var results: [TempoResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var keyInput: String = ""

    /// Called with the chosen result when the user taps one; the caller applies
    /// it to the song and this view dismisses itself.
    var onApply: (TempoResult) -> Void

    init(initialTitle: String, initialArtist: String, onApply: @escaping (TempoResult) -> Void) {
        _titleQuery = State(initialValue: initialTitle)
        _artistQuery = State(initialValue: initialArtist)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Group {
                if apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
                    apiKeySetup
                } else {
                    searchForm
                }
            }
            .navigationTitle("Search Tempo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var apiKeySetup: some View {
        Form {
            Section {
                Text("Tempo search uses GetSongBPM's free API. Get a key at getsongbpm.com/api, then paste it below.")
                    .foregroundStyle(.secondary)
                Link("Get a free API key", destination: URL(string: "https://getsongbpm.com/api")!)
                TextField("API Key", text: $keyInput)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                Button("Save Key") {
                    apiKey = keyInput.trimmingCharacters(in: .whitespaces)
                }
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var searchForm: some View {
        VStack(spacing: 0) {
            Form {
                Section("Search") {
                    TextField("Song title", text: $titleQuery)
                    TextField("Artist (optional)", text: $artistQuery)
                    Button {
                        Task { await runSearch() }
                    } label: {
                        if isSearching {
                            ProgressView()
                        } else {
                            Text("Search")
                        }
                    }
                    .disabled(titleQuery.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                if !results.isEmpty {
                    Section("Results — tap to apply") {
                        ForEach(results) { result in
                            Button {
                                onApply(result)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(result.title).font(.headline)
                                    HStack(spacing: 8) {
                                        if !result.artist.isEmpty { Text(result.artist) }
                                        Text("\(Int(result.bpm)) BPM")
                                        if !result.key.isEmpty { Text("Key \(result.key)") }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Text("Tempo data from [GetSongBPM.com](https://getsongbpm.com)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        }
    }

    private func runSearch() async {
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        let source = GetSongBPMSource(apiKey: apiKey)
        do {
            let found = try await source.search(title: titleQuery, artist: artistQuery)
            results = found
            if found.isEmpty {
                errorMessage = "No matches. Try a different spelling, or enter the tempo manually."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
