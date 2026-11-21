import SwiftUI
import SwiftData

struct SetlistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var engine: ClickEngine
    @Query(sort: \Song.title) private var allSongs: [Song]

    @Bindable var setlist: Setlist
    @Binding var selectedTab: AppTab

    @State private var showingAddSongs = false

    private var songsNotInSetlist: [Song] {
        let existing = Set(setlist.items.compactMap { $0.song?.persistentModelID })
        return allSongs.filter { !existing.contains($0.persistentModelID) }
    }

    var body: some View {
        List {
            if !setlist.items.isEmpty {
                NavigationLink {
                    PerformanceView(setlist: setlist)
                } label: {
                    Label("Start Performance", systemImage: "play.rectangle.fill")
                        .foregroundStyle(.green)
                }
            }
            ForEach(setlist.sortedItems) { item in
                if let song = item.song {
                    Button {
                        engine.loadSong(song)
                        selectedTab = .transport
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(song.title).font(.headline)
                                Text("\(Int(song.bpm)) BPM" + (song.key.isEmpty ? "" : " · Key \(song.key)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.circle")
                                .foregroundStyle(.green)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .onDelete(perform: removeItems)
            .onMove(perform: moveItems)
        }
        .navigationTitle(setlist.name)
        .toolbar {
            #if os(iOS)
            ToolbarItem { EditButton() }
            #endif
            ToolbarItem {
                Button {
                    showingAddSongs = true
                } label: {
                    Label("Add Songs", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSongs) {
            NavigationStack {
                List(songsNotInSetlist) { song in
                    Button {
                        addSong(song)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(song.title)
                            Text("\(Int(song.bpm)) BPM").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Add Songs")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingAddSongs = false }
                    }
                }
                .overlay {
                    if songsNotInSetlist.isEmpty {
                        ContentUnavailableView("All Songs Added", systemImage: "checkmark.circle")
                    }
                }
            }
        }
    }

    private func addSong(_ song: Song) {
        let item = SetlistItem(position: setlist.items.count, song: song, setlist: setlist)
        modelContext.insert(item)
    }

    private func removeItems(at offsets: IndexSet) {
        let sorted = setlist.sortedItems
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        renumber()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var sorted = setlist.sortedItems
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, item) in sorted.enumerated() {
            item.position = index
        }
    }

    private func renumber() {
        for (index, item) in setlist.sortedItems.enumerated() {
            item.position = index
        }
    }
}
