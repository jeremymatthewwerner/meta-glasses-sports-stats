import AVKit
import SidelineCore
import SwiftUI
import UniformTypeIdentifiers

/// A scorebook that can take imported camera videos (football and soccer).
@MainActor
protocol GameVideoHost: AnyObject {
    var recording: GameRecording { get }
    var gameFolder: URL { get }
    var syncAnchors: [SyncAnchor] { get }
    var firstEventDate: Date? { get }
    var clipPolicy: ClipPolicy { get }
    var videoStatus: String? { get set }
    var importingVideo: Bool { get set }
    func setRecording(_ recording: GameRecording)
    /// Events worth checking the sync against: (title, wall time), oldest first.
    var syncCheckEvents: [(id: UUID, title: String, date: Date)] { get }
}

extension GameVideoHost {
    func importVideo(from url: URL) async {
        importingVideo = true
        defer { importingVideo = false }
        let name = recording.nextImportName(extension: url.pathExtension)
        do {
            let imported = try await VideoImporter.importVideo(
                from: url, into: gameFolder, name: name, anchors: syncAnchors, firstEvent: firstEventDate
            ) { [weak self] line in Task { @MainActor in self?.videoStatus = line } }
            var r = recording
            r.segments.append(imported.segment)
            setRecording(r)
            let w = imported.whistles.count
            videoStatus = "\(imported.segment.sync?.summary ?? "Imported") · \(w) whistle\(w == 1 ? "" : "s") heard"
        } catch {
            videoStatus = "Import failed: \(error.localizedDescription)"
        }
    }

    func nudge(_ file: String, by seconds: TimeInterval) {
        guard let s = recording.segments.first(where: { $0.file == file }) else { return }
        var r = recording
        let old = s.sync ?? VideoSync(videoStart: s.startedAt, method: .manual)
        r.setSync(VideoSync(videoStart: s.startedAt.addingTimeInterval(seconds), method: .manual,
                            matched: old.matched, anchors: old.anchors), for: file)
        setRecording(r)
    }

    func resync(_ file: String) {
        guard let s = recording.segments.first(where: { $0.file == file }) else { return }
        if let sync = VideoImporter.resync(s, folder: gameFolder, anchors: syncAnchors) {
            var r = recording
            r.setSync(sync, for: file)
            setRecording(r)
            videoStatus = sync.summary
        } else {
            videoStatus = "The whistles still don't line up with the logged events; the current sync stays."
        }
    }

    func deleteVideo(_ file: String) {
        let url = gameFolder.appendingPathComponent(file)
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: VideoImporter.whistlesFile(for: url))
        var r = recording
        r.segments.removeAll { $0.file == file }
        setRecording(r)
    }

    func cameraClip(at date: Date) -> VideoRef? { recording.importedClip(at: date, policy: clipPolicy) }
    func videoURL(_ ref: VideoRef) -> URL { gameFolder.appendingPathComponent(ref.assetID) }

    static var importTypes: [UTType] { [.movie, .mpeg4Movie, .quickTimeMovie] }
}

/// Imported camera videos for the open game: how each was synced, nudge
/// buttons, and clips of logged events to check it against.
struct GameVideosView: View {
    let host: any GameVideoHost
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var playing: PlayingClip?
    @State private var pendingDelete: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        importing = true
                    } label: {
                        Label("Import a game video…", systemImage: "square.and.arrow.down")
                    }
                    .disabled(host.importingVideo)
                    if host.importingVideo { ProgressView().controlSize(.small) }
                    if let status = host.videoStatus { Text(status).font(.footnote).foregroundStyle(.secondary) }
                } footer: {
                    Text("A Veo download, a phone on a tripod, any camera. It's lined up with the game by matching the referee's whistles to the plays and kickoffs you logged; a phone video's recording time is the first guess.")
                }
                ForEach(host.recording.importedSegments) { seg in
                    Section(seg.source.replacingOccurrences(of: "Imported: ", with: "")) {
                        if let sync = seg.sync { Text(sync.summary).font(.subheadline) }
                        LabeledContent("Video starts", value: seg.startedAt.formatted(date: .omitted, time: .standard))
                        LabeledContent("Length", value: ScorebookView.clock(seg.duration ?? 0))
                        HStack {
                            Text("Shift").font(.footnote).foregroundStyle(.secondary)
                            Spacer()
                            ForEach([-10.0, -1, 1, 10], id: \.self) { d in
                                Button(d > 0 ? "+\(Int(d))s" : "\(Int(d))s") { host.nudge(seg.file, by: d) }
                                    .buttonStyle(.bordered).font(.footnote.monospacedDigit())
                            }
                        }
                        Text("If clips start too early, shift the video later (+); too late, earlier (−).")
                            .font(.caption2).foregroundStyle(.secondary)
                        Button("Re-sync with whistles") { host.resync(seg.file) }
                        Button("Remove video", role: .destructive) { pendingDelete = seg.file }
                    }
                }
                if !host.recording.importedSegments.isEmpty {
                    Section("Check against logged events") {
                        let events = host.syncCheckEvents
                        if events.isEmpty { Text("No logged events yet").foregroundStyle(.secondary) }
                        ForEach(events, id: \.id) { e in
                            if let ref = host.cameraClip(at: e.date) {
                                Button {
                                    playing = PlayingClip(url: host.videoURL(ref), ref: ref, title: e.title)
                                } label: {
                                    LabeledContent(e.title, value: ScorebookView.clock(ref.start))
                                }
                            } else {
                                LabeledContent(e.title, value: "outside the video").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Game videos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie]) { result in
                if case .success(let url) = result { Task { await host.importVideo(from: url) } }
            }
            .sheet(item: $playing) { ClipPlayerView(clip: $0) }
            .alert("Remove this video?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                Button("Remove", role: .destructive) { if let f = pendingDelete { host.deleteVideo(f) } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The imported copy on this phone is deleted. The original file isn't touched.")
            }
        }
    }
}
