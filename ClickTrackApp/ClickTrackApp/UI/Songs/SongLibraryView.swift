import SwiftUI
import SwiftData

struct SongLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var engine: ClickEngine
    @Query(sort: \Song.title) private var songs: [Song]

    @State private var newSong: Song?
    @State private var searchText = ""
    @Binding var selectedTab: AppTab

    private var filteredSongs: [Song] {
        guard !searchText.isEmpty else { return songs }
        return songs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.artist.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredSongs) { song in
                    NavigationLink {
                        SongEditorView(song: song, isNew: false)
                    } label: {
                        row(for: song)
                    }
                    .swipeActions {
                        Button("Load") {
                            engine.loadSong(song)
                            selectedTab = .transport
                        }
                        .tint(.green)
                    }
                }
                .onDelete(perform: deleteSongs)
            }
            .searchable(text: $searchText, prompt: "Search songs")
            .navigationTitle("Songs")
            .toolbar {
                ToolbarItem {
                    Button {
                        newSong = Song(title: "")
                    } label: {
                        Label("Add Song", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $newSong) { song in
                NavigationStack {
                    SongEditorView(song: song, isNew: true)
                }
            }
            .overlay {
                if songs.isEmpty {
                    ContentUnavailableView("No Songs Yet", systemImage: "music.note.list", description: Text("Tap + to add your first song."))
                }
            }
        }
    }

    private func row(for song: Song) -> some View {
        VStack(alignment: .leading) {
            Text(song.title).font(.headline)
            HStack(spacing: 8) {
                if !song.artist.isEmpty { Text(song.artist) }
                Text("\(Int(song.bpm)) BPM")
                if !song.key.isEmpty { Text("Key \(song.key)") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func deleteSongs(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredSongs[index])
        }
    }
}
