import SidelineCore
import SwiftUI

/// The match's events by player and by category, with clips and highlight reels.
struct SoccerGalleryView: View {
    @Environment(SoccerScorebookModel.self) private var model
    @State private var mode = GalleryView.Mode.players

    var body: some View {
        let gallery = model.gallery
        NavigationStack {
            List {
                Picker("Show", selection: $mode) {
                    ForEach(GalleryView.Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                switch mode {
                case .players:
                    if gallery.players.isEmpty {
                        Text("Players show up here once calls name them (“goal 9, assist 7”).")
                            .foregroundStyle(.secondary)
                    }
                    ForEach([model.game.focus, model.game.focus.opponent], id: \.self) { side in
                        let entries = gallery.players.filter { $0.player.team == side }
                        if !entries.isEmpty {
                            Section(model.game.team(side).name) {
                                ForEach(entries) { entry in
                                    NavigationLink {
                                        SoccerEventListView(title: model.game.displayName(side, entry.player.jersey), events: entry.events)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(model.game.displayName(side, entry.player.jersey)).font(.headline)
                                            Text(entry.roleSummary).font(.caption).foregroundStyle(.secondary)
                                            if entry.clipCount > 0 {
                                                Label("\(entry.clipCount) clip\(entry.clipCount == 1 ? "" : "s")", systemImage: "film")
                                                    .font(.caption2).foregroundStyle(.blue)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                case .events:
                    Section {
                        ForEach(SoccerTag.allCases) { tag in
                            let events = gallery.byTag[tag] ?? []
                            NavigationLink {
                                SoccerEventListView(title: tag.label, events: events)
                            } label: {
                                LabeledContent(tag.label, value: "\(events.count)")
                            }
                            .disabled(events.isEmpty)
                        }
                    }
                }
            }
            .navigationTitle("Gallery")
        }
    }
}

/// Soccer events with their clips, and a button to turn them into one reel.
struct SoccerEventListView: View {
    @Environment(SoccerScorebookModel.self) private var model
    let title: String
    let events: [SoccerEvent]
    @State private var playing: PlayingClip?
    @State private var reel: URL?
    @State private var making = false
    @State private var error: String?

    private var readyClips: Int { events.filter { model.reelClip($0) != nil }.count }

    var body: some View {
        List {
            Section {
                Button {
                    Task { await makeReel() }
                } label: {
                    Label(making ? "Making reel…" : "Make highlight reel (\(readyClips) clip\(readyClips == 1 ? "" : "s"))",
                          systemImage: "film.stack")
                }
                .disabled(readyClips == 0 || making)
                .accessibilityIdentifier("soccerMakeReel")
                if let reel {
                    Button("Play reel", systemImage: "play.rectangle") {
                        playing = PlayingClip(url: reel, ref: VideoRef(assetID: reel.lastPathComponent, start: 0, end: 24 * 3600),
                                              title: title)
                    }
                    ShareLink("Share reel", item: reel)
                }
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            } footer: {
                Text(readyClips == 0
                     ? "Reels use glasses video (Record match video, once stopped) or an imported camera video (Game videos…)."
                     : "Each event uses its glasses clip, or the camera clip when there's no glasses video.")
            }
            Section("\(events.count) event\(events.count == 1 ? "" : "s")") {
                ForEach(events) { e in
                    SoccerEventRow(game: model.game, event: e, glassesReady: e.videoRefs.first.map(model.clipIsReady) ?? false,
                                   camera: model.cameraClip(at: e.wallTime)) { ref in
                        playing = PlayingClip(url: model.videoURL(ref), ref: ref, title: model.game.summary(e))
                    }
                }
            }
        }
        .navigationTitle(title)
        .sheet(item: $playing) { ClipPlayerView(clip: $0) }
    }

    private func makeReel() async {
        making = true
        error = nil
        defer { making = false }
        do {
            reel = try await model.makeReel(title: title, events: events)
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }
}
