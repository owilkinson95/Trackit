import SwiftUI
import SwiftData

@main
struct ClickTrackApp: App {
    @StateObject private var engine = ClickEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .preferredColorScheme(.dark)
                #if os(macOS)
                .frame(minWidth: 560, minHeight: 640)
                #endif
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
        .modelContainer(for: [Song.self, Setlist.self, SetlistItem.self])
        .commands {
            CommandMenu("Playback") {
                Button(engine.isPlaying ? "Stop" : "Play") {
                    engine.isPlaying ? engine.stop() : engine.start()
                }
                .keyboardShortcut(.space, modifiers: [])
            }
        }
    }
}
