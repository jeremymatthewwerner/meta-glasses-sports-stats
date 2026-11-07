import SidelineCore
import SwiftUI

struct LiveRunView: View {
    @Environment(ProbeRunner.self) private var runner
    @State private var customNote = ""

    private let quickNotes = ["Glasses into case", "Glasses out of case", "Halftime", "Swapped glasses", "Took glasses off", "Put glasses on"]

    var body: some View {
        List {
            Section {
                previewBox
                    .listRowInsets(EdgeInsets())
            }

            if let error = runner.startError {
                Section { Text(error).foregroundStyle(.red) }
            }

            Section(runner.isRunning ? "Live" : "Finished") {
                let s = runner.latest
                LabeledContent("Elapsed", value: Self.clock(s?.elapsed ?? 0))
                LabeledContent("Stream", value: s?.streamState ?? "–")
                LabeledContent("Session", value: s?.sessionState ?? "–")
                LabeledContent("FPS (5 s)", value: s.map { String(format: "%.1f", $0.measuredFps) } ?? "–")
                LabeledContent("Frames", value: s.map { "\($0.framesTotal)" } ?? "–")
                LabeledContent("Recorded", value: s.map { ByteCountFormatter.string(fromByteCount: $0.bytesWritten, countStyle: .file) } ?? "–")
                LabeledContent("Glasses battery", value: s?.glassesBattery.map { "\($0)%" } ?? "–")
                LabeledContent("Glasses thermal", value: s?.glassesThermal ?? "–")
                LabeledContent("Phone battery", value: s?.phoneBattery.map { "\(Int($0 * 100))%" } ?? "–")
                LabeledContent("Phone thermal", value: s?.phoneThermal ?? "–")
            }

            if runner.isRunning {
                Section("Notes (for the test log)") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(quickNotes, id: \.self) { note in
                                Button(note) { runner.addNote(note) }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                    HStack {
                        TextField("Custom note", text: $customNote)
                        Button("Add") {
                            runner.addNote(customNote)
                            customNote = ""
                        }
                        .disabled(customNote.isEmpty)
                    }
                }
            } else if let run = runner.run {
                Section("Summary") { SummaryRows(summary: run.summary) }
            }

            Section("Events") {
                ForEach(Array(runner.recentEvents.reversed().enumerated()), id: \.offset) { _, e in
                    VStack(alignment: .leading) {
                        Text("\(Self.clock(e.elapsed))  \(e.kind.rawValue)").font(.caption.monospaced())
                        Text(e.detail).font(.footnote)
                    }
                }
            }
        }
        .navigationTitle(runner.run?.config.label ?? "Run")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if runner.isRunning {
                Button("Stop", role: .destructive) { Task { await runner.stop() } }
            }
        }
    }

    @ViewBuilder private var previewBox: some View {
        ZStack {
            Color.black
            if let image = runner.preview {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Text(runner.run?.config.codec == .hevc ? "Recording HEVC (preview off)" : "Waiting for frames…")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(height: 280)
    }

    static func clock(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
    }
}

struct SummaryRows: View {
    let summary: ProbeSummary

    var body: some View {
        LabeledContent("Streaming time", value: LiveRunView.clock(summary.streamingSeconds))
        LabeledContent("Longest continuous", value: LiveRunView.clock(summary.longestContinuousStreamingSeconds))
        LabeledContent("Mean FPS", value: String(format: "%.1f", summary.meanFpsWhileStreaming))
        LabeledContent("Battery", value: "\(summary.glassesBatteryStart.map(String.init) ?? "?") → \(summary.glassesBatteryEnd.map(String.init) ?? "?")%")
        LabeledContent("Drain / hour", value: summary.glassesBatteryDrainPerHour.map { String(format: "%.0f pts", $0) } ?? "–")
        LabeledContent("First thermal warning", value: summary.firstThermalWarningSeconds.map { LiveRunView.clock($0) } ?? "none")
        LabeledContent("Max thermal", value: summary.maxThermal)
        LabeledContent("Stalls / pauses / errors", value: "\(summary.stallCount) / \(summary.pauseCount) / \(summary.errorCount)")
        LabeledContent("Stop reason", value: summary.stopReason ?? "–")
    }
}
