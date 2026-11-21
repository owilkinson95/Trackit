import SwiftUI

/// The performance screen — big, readable from across a stage, dark background,
/// matching the on-stage-at-a-glance feel of Playback's transport screen.
struct TransportView: View {
    @EnvironmentObject private var engine: ClickEngine
    @State private var tapTempo = TapTempo()
    @State private var bpmText: String = "120"
    @State private var showingRouting = false

    private let subdivisionLabels = ["1/4", "1/8", "1/8T", "1/16"]

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.035, blue: 0.04).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                if let title = engine.currentSongTitle {
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)
                }

                bpmDisplay

                beatIndicator

                HStack(spacing: 16) {
                    stepper(title: "Beats/Bar", value: engine.pattern.beatsPerBar, range: 1...12) { newValue in
                        apply { $0.beatsPerBar = newValue }
                    }
                    subdivisionPicker
                }

                playStopButton

                tapTempoButton

                Spacer()
            }
            .padding(32)
        }
        .foregroundColor(.white)
        .overlay(alignment: .topTrailing) {
            Button {
                showingRouting = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .padding()
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingRouting) {
            OutputRoutingView()
        }
    }

    private var bpmDisplay: some View {
        VStack(spacing: 4) {
            TextField("BPM", text: $bpmText, onCommit: commitBPMText)
                .multilineTextAlignment(.center)
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .frame(width: 280)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            Text("BPM")
                .font(.headline)
                .foregroundColor(.gray)
        }
        .onChange(of: engine.pattern.bpm) { _, newValue in
            bpmText = formatted(newValue)
        }
        .onAppear { bpmText = formatted(engine.pattern.bpm) }
    }

    private var beatIndicator: some View {
        HStack(spacing: 10) {
            ForEach(0..<engine.pattern.beatsPerBar, id: \.self) { beat in
                Circle()
                    .fill(engine.isPlaying && beat == engine.currentBeat ? (beat == 0 ? Color.green : Color.white) : Color.gray.opacity(0.25))
                    .frame(width: 14, height: 14)
            }
        }
        .animation(.easeOut(duration: 0.1), value: engine.currentBeat)
    }

    private var subdivisionPicker: some View {
        Picker("Subdivision", selection: Binding(
            get: { engine.pattern.subdivision },
            set: { newValue in apply { $0.subdivision = newValue } }
        )) {
            ForEach(Array(subdivisionLabels.enumerated()), id: \.offset) { index, label in
                Text(label).tag(index + 1)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 220)
    }

    private func stepper(title: String, value: Int, range: ClosedRange<Int>, onChange: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundColor(.gray)
            Stepper("\(value)", value: Binding(
                get: { value },
                set: { onChange(min(max($0, range.lowerBound), range.upperBound)) }
            ), in: range)
            .fixedSize()
        }
    }

    private var playStopButton: some View {
        Button {
            engine.isPlaying ? engine.stop() : engine.start()
        } label: {
            Text(engine.isPlaying ? "STOP" : "PLAY")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .frame(width: 220, height: 80)
                .background(engine.isPlaying ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    private var tapTempoButton: some View {
        Button {
            if let newBPM = tapTempo.tap() {
                apply { $0.bpm = newBPM.rounded() }
            }
        } label: {
            Text("TAP TEMPO")
                .font(.headline)
                .frame(width: 180, height: 50)
                .background(Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func apply(_ mutate: (inout ClickGenerator.Pattern) -> Void) {
        var newPattern = engine.pattern
        mutate(&newPattern)
        engine.update(pattern: newPattern)
    }

    private func commitBPMText() {
        guard let value = Double(bpmText), value > 0 else {
            bpmText = formatted(engine.pattern.bpm)
            return
        }
        apply { $0.bpm = value }
    }

    private func formatted(_ bpm: Double) -> String {
        bpm.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(bpm)) : String(format: "%.1f", bpm)
    }
}

#Preview {
    TransportView()
        .environmentObject(ClickEngine())
}
