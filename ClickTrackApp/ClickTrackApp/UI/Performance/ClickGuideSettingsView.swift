import SwiftUI

/// Settings for the click's sound and the Guide layer's behavior — separate
/// from Output Routing, which only controls which physical channels carry
/// the audio. Volume for each (Accent, Beat, Guide) lives on its own mixer
/// fader; this sheet controls sound and *when* the guide sounds.
struct ClickGuideSettingsView: View {
    @EnvironmentObject private var engine: ClickEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Sound", selection: $engine.clickSound) {
                        ForEach(ClickSound.allCases) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    }
                } header: {
                    Text("Click Sound")
                } footer: {
                    Text("Applies to the Accent, 1/4, 1/8, and 1/16 faders in the mixer.")
                }

                Section {
                    Picker("Guide", selection: $engine.guideMode) {
                        ForEach(GuideMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Guide")
                } footer: {
                    Text("\(engine.guideMode.footnote) Use the Guide fader in the mixer to set its volume — turn it all the way down to mute it, or up to make it prominent.")
                }
            }
            .navigationTitle("Click & Guide")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
