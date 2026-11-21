import SwiftUI
import SwiftData

struct SetlistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Setlist.date, order: .reverse) private var setlists: [Setlist]
    @Binding var selectedTab: AppTab

    @State private var newSetlistName = ""
    @State private var showingNewSetlistPrompt = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(setlists) { setlist in
                    NavigationLink {
                        SetlistDetailView(setlist: setlist, selectedTab: $selectedTab)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(setlist.name).font(.headline)
                            Text("\(setlist.items.count) songs · \(setlist.date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(setlists[index]) }
                }
            }
            .navigationTitle("Setlists")
            .toolbar {
                ToolbarItem {
                    Button {
                        showingNewSetlistPrompt = true
                    } label: {
                        Label("Add Setlist", systemImage: "plus")
                    }
                }
            }
            .alert("New Setlist", isPresented: $showingNewSetlistPrompt) {
                TextField("Name (e.g. Sunday Service)", text: $newSetlistName)
                Button("Cancel", role: .cancel) { newSetlistName = "" }
                Button("Create") {
                    let trimmed = newSetlistName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    modelContext.insert(Setlist(name: trimmed))
                    newSetlistName = ""
                }
            }
            .overlay {
                if setlists.isEmpty {
                    ContentUnavailableView("No Setlists Yet", systemImage: "list.bullet.rectangle", description: Text("Tap + to plan your first service."))
                }
            }
        }
    }
}
