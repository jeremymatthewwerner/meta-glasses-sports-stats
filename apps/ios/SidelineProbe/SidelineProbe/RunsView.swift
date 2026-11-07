import SwiftUI

/// Lists saved run folders. Files are also visible in the Files app under
/// On My iPhone > Sideline Probe > runs (UIFileSharingEnabled).
struct RunsView: View {
    @State private var folders: [URL] = []

    var body: some View {
        List {
            if folders.isEmpty {
                Text("No runs yet.").foregroundStyle(.secondary)
            }
            ForEach(folders, id: \.self) { folder in
                let files = Self.shareableFiles(in: folder)
                VStack(alignment: .leading, spacing: 6) {
                    Text(folder.lastPathComponent).font(.footnote.monospaced())
                    if let line = Self.summaryLine(folder) {
                        Text(line).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        ShareLink("Share logs", items: files.filter { $0.pathExtension != "mov" })
                        if let video = files.first(where: { $0.pathExtension == "mov" }) {
                            Spacer()
                            ShareLink("Share video", item: video)
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }
            .onDelete { idx in
                for i in idx { try? FileManager.default.removeItem(at: folders[i]) }
                load()
            }
        }
        .navigationTitle("Past runs")
        .onAppear(perform: load)
    }

    private func load() {
        let dir = ProbeRunner.runsDirectory
        let items = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        folders = items.filter { $0.hasDirectoryPath }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    static func shareableFiles(in folder: URL) -> [URL] {
        ["summary.json", "samples.csv", "events.csv", "video.mov"]
            .map { folder.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func summaryLine(_ folder: URL) -> String? {
        guard
            let data = try? Data(contentsOf: folder.appendingPathComponent("summary.json")),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let s = json["summary"] as? [String: Any]
        else { return nil }
        let streaming = (s["streamingSeconds"] as? Double).map { LiveRunView.clock($0) } ?? "?"
        let stop = s["stopReason"] as? String ?? "?"
        let type = (json["device"] as? [String: Any])?["glassesType"] as? String ?? "?"
        return "\(type) · streamed \(streaming) · \(stop)"
    }
}
