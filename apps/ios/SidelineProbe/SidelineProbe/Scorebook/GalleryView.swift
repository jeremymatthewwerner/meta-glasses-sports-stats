import AVKit
import SidelineCore
import SwiftUI

/// The game's plays by player and by event type, with clips and highlight reels.
struct GalleryView: View {
    @Environment(ScorebookModel.self) private var model
    @State private var mode = Mode.players

    enum Mode: String, CaseIterable { case players = "Players", events = "Events" }

    var body: some View {
        let gallery = model.gallery
        NavigationStack {
            List {
                Picker("Show", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                switch mode {
                case .players:
                    if gallery.players.isEmpty {
                        Text("Players show up here once plays name them (“22 run for 7, tackle by 54”).")
                            .foregroundStyle(.secondary)
                    }
                    ForEach([TeamSide.away, .home], id: \.self) { side in
                        let entries = gallery.players.filter { $0.player.team == side }
                        if !entries.isEmpty {
                            Section(model.game.team(side).name) {
                                ForEach(entries) { entry in
                                    NavigationLink {
                                        PlayListView(title: model.game.displayName(entry.player), events: entry.plays)
                                    } label: {
                                        PlayerRow(entry: entry, name: model.game.displayName(entry.player))
                                    }
                                }
                            }
                        }
                    }
                case .events:
                    Section {
                        ForEach(PlayTag.allCases) { tag in
                            let events = gallery.byTag[tag] ?? []
                            NavigationLink {
                                PlayListView(title: tag.label, events: events)
                            } label: {
                                LabeledContent(tag.label, value: "\(events.count)")
                            }
                            .disabled(events.isEmpty)
                        }
                    } footer: {
                        Text("Big plays: gains of \(PlayTag.bigGain)+ yards or returns of \(PlayTag.bigReturn)+.")
                    }
                }
            }
            .navigationTitle("Gallery")
        }
    }
}

private struct PlayerRow: View {
    let entry: FootballGallery.PlayerEntry
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.headline)
            Text(roleSummary).font(.caption).foregroundStyle(.secondary)
            if entry.clipCount > 0 {
                Label("\(entry.clipCount) clip\(entry.clipCount == 1 ? "" : "s")", systemImage: "film")
                    .font(.caption2).foregroundStyle(.blue)
            }
        }
    }

    private var roleSummary: String {
        PlayInvolvement.Role.allCases.compactMap { role in
            entry.roles[role].map { role.counted($0) }
        }.joined(separator: " · ")
    }
}

/// A list of plays with their clips, and a button to turn them into one reel.
struct PlayListView: View {
    @Environment(ScorebookModel.self) private var model
    let title: String
    let events: [FootballEvent]
    @State private var playingClip: PlayingClip?
    @State private var reel: URL?
    @State private var making = false
    @State private var error: String?

    private var readyClips: Int {
        events.filter { $0.videoRefs.first.map(model.clipIsReady) ?? false }.count
    }

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
                if let reel {
                    Button("Play reel", systemImage: "play.rectangle") {
                        playingClip = PlayingClip(url: reel, ref: VideoRef(assetID: reel.lastPathComponent, start: 0, end: 24 * 3600),
                                                  title: title)
                    }
                    ShareLink("Share reel", item: reel)
                }
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            } footer: {
                if readyClips == 0 {
                    Text("Reels use clips from game mode (Record game video), once the video is stopped.")
                }
            }
            Section("\(events.count) play\(events.count == 1 ? "" : "s")") {
                ForEach(events) { event in
                    EventRow(event: event, clipReady: event.videoRefs.first.map(model.clipIsReady) ?? false) { ref in
                        playingClip = PlayingClip(url: model.clipURL(ref), ref: ref, title: event.summary)
                    }
                }
            }
        }
        .navigationTitle(title)
        .sheet(item: $playingClip) { ClipPlayerView(clip: $0) }
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

/// Paste or import rosters: one player per line, e.g. "22,Jane Smith,RB".
struct RosterEditorView: View {
    @Environment(ScorebookModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var home = ""
    @State private var away = ""
    @State private var problems: [String] = []
    @State private var importing: TeamSide?

    var body: some View {
        NavigationStack {
            Form {
                section(.home, text: $home)
                section(.away, text: $away)
                if !problems.isEmpty {
                    Section("Couldn't read") {
                        ForEach(problems, id: \.self) { Text($0).font(.footnote) }
                    }
                }
            }
            .navigationTitle("Rosters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        problems = model.setRoster(.home, text: home) + model.setRoster(.away, text: away)
                        if problems.isEmpty { dismiss() }
                    }
                }
            }
            .onAppear {
                home = model.game.home.roster?.csv ?? ""
                away = model.game.away.roster?.csv ?? ""
            }
            .fileImporter(isPresented: Binding(get: { importing != nil }, set: { if !$0 { importing = nil } }),
                          allowedContentTypes: [.commaSeparatedText, .plainText, .tabSeparatedText]) { result in
                guard case .success(let url) = result else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    if importing == .home { home = text } else { away = text }
                }
            }
        }
    }

    private func section(_ side: TeamSide, text: Binding<String>) -> some View {
        Section {
            TextEditor(text: text)
                .font(.callout.monospaced())
                .frame(minHeight: 120)
                .accessibilityIdentifier("roster-\(side.rawValue)")
            Button("Import CSV…", systemImage: "square.and.arrow.down") { importing = side }
        } header: {
            Text(model.game.team(side).name)
        } footer: {
            Text("One player per line: number, name, position (optional). Pasting from a spreadsheet works.")
        }
    }
}
