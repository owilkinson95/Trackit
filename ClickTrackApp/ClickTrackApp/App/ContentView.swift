import SwiftUI

enum AppTab: Hashable {
    case transport, songs, setlists
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .transport

    var body: some View {
        TabView(selection: $selectedTab) {
            TransportView()
                .tabItem { Label("Transport", systemImage: "metronome") }
                .tag(AppTab.transport)

            SongLibraryView(selectedTab: $selectedTab)
                .tabItem { Label("Songs", systemImage: "music.note.list") }
                .tag(AppTab.songs)

            SetlistsView(selectedTab: $selectedTab)
                .tabItem { Label("Setlists", systemImage: "list.bullet.rectangle") }
                .tag(AppTab.setlists)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ClickEngine())
        .modelContainer(for: [Song.self, Setlist.self, SetlistItem.self, Track.self, SongSection.self], inMemory: true)
}
