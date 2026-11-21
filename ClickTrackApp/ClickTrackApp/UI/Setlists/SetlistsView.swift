import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SetlistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Setlist.date, order: .reverse) private var setlists: [Setlist]
    @Query private var allSongs: [Song]
    @Binding var selectedTab: AppTab

    @State private var newSetlistName = ""
    @State private var showingNewSetlistPrompt = false
    @State private var exportDocument: TransferDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var transferMessage: String?

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
                    Menu {
                        Button {
                            exportDocument = TransferDocument(data: SetlistFileTransfer.export(songs: allSongs, setlists: setlists))
                            showingExporter = true
                        } label: {
                            Label("Export All to File…", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            showingImporter = true
                        } label: {
                            Label("Import from File…", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Label("Transfer", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                ToolbarItem {
                    Button {
                        showingNewSetlistPrompt = true
                    } label: {
                        Label("Add Setlist", systemImage: "plus")
                    }
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "ClickTrackLibrary"
            ) { result in
                if case .failure(let error) = result {
                    transferMessage = "Export failed: \(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    importFile(at: url)
                case .failure(let error):
                    transferMessage = "Import failed: \(error.localizedDescription)"
                }
            }
            .alert("Transfer", isPresented: Binding(
                get: { transferMessage != nil },
                set: { if !$0 { transferMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(transferMessage ?? "")
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

    private func importFile(at url: URL) {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let result = try SetlistFileTransfer.importPackage(from: data, into: modelContext)
            transferMessage = "Imported \(result.songs) song\(result.songs == 1 ? "" : "s") and \(result.setlists) setlist\(result.setlists == 1 ? "" : "s")."
        } catch {
            transferMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}
