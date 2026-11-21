import SwiftUI

/// Lets the user pick exactly which output channel(s) carry the click —
/// e.g. channel 2 only, so an audio interface can send it to in-ears while
/// leaving the other channel(s) free for a future track/pad feed to the house.
struct OutputRoutingView: View {
    @EnvironmentObject private var engine: ClickEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Output Device")
                        Spacer()
                        Text("\(engine.deviceChannelCount) channel\(engine.deviceChannelCount == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                    }
                    Button("Refresh") {
                        engine.refreshDeviceChannelCount()
                    }
                } footer: {
                    Text("If you just plugged in an audio interface, tap Refresh to pick up its channels.")
                }

                Section {
                    ForEach(0..<engine.deviceChannelCount, id: \.self) { index in
                        Toggle("Channel \(index + 1)", isOn: Binding(
                            get: { engine.clickChannels.contains(index) },
                            set: { isOn in
                                if isOn {
                                    engine.clickChannels.insert(index)
                                } else {
                                    engine.clickChannels.remove(index)
                                }
                            }
                        ))
                    }
                } header: {
                    Text("Click Output Channels")
                } footer: {
                    Text("Choose which channel(s) the click plays on. If your audio interface has channels 3 & 4 wired to in-ears, select only those.")
                }
            }
            .navigationTitle("Output Routing")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
