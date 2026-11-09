import SidelineCore
import SwiftUI

/// Every saved game, the season view for a team, and each game's summary page.
struct LibraryView: View {
    @Environment(ScorebookModel.self) private var model
    @Environment(SoccerScorebookModel.self) private var soccer
    @AppStorage("sport") private var sport = Sport.football
    @State private var pendingDelete: ScorebookModel.SavedGame?

    var body: some View {
        NavigationStack {
            List {
                let teams = SeasonStats.teamNames(in: model.library.map(\.game))
                if !teams.isEmpty {
                    Section("Season") {
                        ForEach(teams.prefix(4), id: \.self) { team in
                            NavigationLink {
                                SeasonView(team: team)
                            } label: {
                                let s = SeasonStats(team: team, games: model.library.map(\.game))
                                LabeledContent(team, value: "\(s.record) · \(s.games) game\(s.games == 1 ? "" : "s")")
                            }
                        }
                    }
                }
                Section("Games") {
                    if model.library.isEmpty { Text("No saved games yet.").foregroundStyle(.secondary) }
                    ForEach(model.library) { saved in
                        NavigationLink {
                            GameSummaryView(game: saved.game)
                        } label: {
                            GameRow(game: saved.game, isOpen: saved.id == model.game.id && sport == .football)
                        }
                        .swipeActions {
                            if saved.id != model.game.id {
                                Button("Delete", role: .destructive) { pendingDelete = saved }
                            }
                        }
                    }
                }
                Section("Soccer games") {
                    if soccer.library.isEmpty { Text("No soccer games yet.").foregroundStyle(.secondary) }
                    ForEach(soccer.library) { g in
                        NavigationLink {
                            SoccerGameDetail(game: g)
                                .toolbar {
                                    if g.id != soccer.game.id || sport != .soccer {
                                        Button("Open in scorebook") {
                                            if sport == .football, model.hud.isActive { model.toggleHUD(deviceID: nil) }
                                            soccer.openGame(g.id)
                                            sport = .soccer
                                        }
                                    }
                                }
                        } label: {
                            SoccerGameRow(game: g, isOpen: g.id == soccer.game.id && sport == .soccer)
                        }
                        .swipeActions {
                            if g.id != soccer.game.id {
                                Button("Delete", role: .destructive) { soccer.deleteGame(g.id) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.exportWebLibrary() }
                    } label: {
                        Label("Export web library", systemImage: "globe")
                    }
                    .disabled(model.webExportRunning || model.library.isEmpty)
                }
            }
            .safeAreaInset(edge: .top) {
                if let status = model.webExportStatus {
                    WebExportBanner(status: status, running: model.webExportRunning, zip: model.webExportZip) {
                        model.webExportStatus = nil
                    }
                }
            }
            .onAppear { model.refreshLibrary(); soccer.refreshLibrary() }
            .alert("Delete this game?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                   presenting: pendingDelete) { saved in
                Button("Delete game and videos", role: .destructive) { model.deleteGame(saved.id) }
                Button("Cancel", role: .cancel) {}
            } message: { saved in
                Text("\(saved.game.away.name) at \(saved.game.home.name), \(saved.game.date.formatted(date: .abbreviated, time: .omitted)). Its plays, clips and videos are removed from this phone. This can't be undone.")
            }
        }
    }
}

/// Progress of a web export, then the zip to share.
private struct WebExportBanner: View {
    let status: String
    let running: Bool
    let zip: URL?
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if running { ProgressView().controlSize(.small) }
                Text(status).font(.subheadline)
                Spacer()
                if !running {
                    Button("Close", systemImage: "xmark", action: dismiss).labelStyle(.iconOnly).foregroundStyle(.secondary)
                }
            }
            if let zip, !running {
                ShareLink(item: zip) { Label("Share website (.zip)", systemImage: "square.and.arrow.up") }
                Text("Unzip and open index.html, or upload the folder to any static host (GitHub Pages, Netlify). The unzipped site is also in Files → On My iPhone → SidelineProbe → web.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

private struct GameRow: View {
    let game: FootballGame
    let isOpen: Bool

    var body: some View {
        let s = game.state
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(game.away.name) \(s.points(.away)) – \(game.home.name) \(s.points(.home))").font(.headline)
                Spacer()
                if isOpen { Text("Open").font(.caption.bold()).foregroundStyle(.blue) }
            }
            Text("\(game.date.formatted(date: .abbreviated, time: .shortened)) · "
                 + (game.isOver ? "Final" : "In progress") + " · \(game.events.filter { $0.status != .rejected }.count) plays")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// The game page: score by quarter, recap, scoring, leaders, key plays.
struct GameSummaryView: View {
    @Environment(ScorebookModel.self) private var model
    let game: FootballGame
    @State private var playingClip: PlayingClip?

    var body: some View {
        let summary = GameSummary(game: game)
        let isOpen = game.id == model.game.id
        List {
            Section {
                QuarterTable(summary: summary)
                Text(summary.recap).font(.callout)
            } header: {
                Text(game.date.formatted(date: .complete, time: .omitted))
            }
            if !isOpen {
                Section {
                    Button("Open in Scorebook", systemImage: "list.clipboard") { model.openGame(game.id) }
                }
            }
            if !summary.scoring.isEmpty {
                Section("Scoring") {
                    ForEach(Array(summary.scoring.enumerated()), id: \.offset) { _, p in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Q\(p.quarter) · \(game.team(p.team).name)").font(.caption.bold())
                            Text(p.description)
                            Text("\(summary.away) \(p.away) – \(summary.home) \(p.home)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if !summary.leaders.isEmpty {
                Section("Leaders") {
                    ForEach(summary.leaders) { l in
                        LabeledContent {
                            Text(l.line).monospacedDigit()
                        } label: {
                            Text(l.category).font(.caption).foregroundStyle(.secondary)
                            Text(l.name + " (\(game.team(l.player.team).name))")
                        }
                    }
                }
            }
            if !summary.keyPlays.isEmpty {
                Section("Key plays") {
                    ForEach(summary.keyPlays) { e in
                        let ready = isOpen && (e.videoRefs.first.map(model.clipIsReady) ?? false)
                        EventRow(event: e, clipReady: ready) { ref in
                            playingClip = PlayingClip(url: model.clipURL(ref), ref: ref, title: e.summary)
                        }
                    }
                }
            }
        }
        .navigationTitle("\(game.away.name) at \(game.home.name)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $playingClip) { ClipPlayerView(clip: $0) }
    }
}

private struct QuarterTable: View {
    let summary: GameSummary

    var body: some View {
        let n = max(4, summary.byQuarter[.home]?.count ?? 4)
        Grid(alignment: .trailing, horizontalSpacing: 14, verticalSpacing: 4) {
            GridRow {
                Text("").gridColumnAlignment(.leading)
                ForEach(0..<n, id: \.self) { i in Text(i < 4 ? "\(i + 1)" : "OT").font(.caption).foregroundStyle(.secondary) }
                Text("T").font(.caption.bold())
            }
            ForEach([TeamSide.away, .home], id: \.self) { side in
                GridRow {
                    Text(side == .home ? summary.home : summary.away).lineLimit(1).gridColumnAlignment(.leading)
                    ForEach(0..<n, id: \.self) { i in
                        Text("\(summary.byQuarter[side]?[safe: i] ?? 0)").monospacedDigit()
                    }
                    Text("\(summary.score[side] ?? 0)").bold().monospacedDigit()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// One team's season: record and per-player totals.
struct SeasonView: View {
    @Environment(ScorebookModel.self) private var model
    let team: String

    var body: some View {
        let s = SeasonStats(team: team, games: model.library.map(\.game))
        List {
            Section {
                LabeledContent("Record", value: s.record)
                LabeledContent("Points", value: "\(s.pointsFor) for · \(s.pointsAgainst) against")
            }
            stat("Passing", s.players.filter { $0.stats.passAttempts > 0 }) {
                "\($0.passCompletions)/\($0.passAttempts), \($0.passYards) yds, \($0.passTouchdowns) TD, \($0.interceptionsThrown) INT"
            }
            stat("Rushing", s.players.filter { $0.stats.rushAttempts > 0 }.sorted { $0.stats.rushYards > $1.stats.rushYards }) {
                "\($0.rushAttempts) car, \($0.rushYards) yds, \($0.rushTouchdowns) TD"
            }
            stat("Receiving", s.players.filter { $0.stats.targets > 0 }.sorted { $0.stats.receivingYards > $1.stats.receivingYards }) {
                "\($0.receptions)/\($0.targets), \($0.receivingYards) yds, \($0.receivingTouchdowns) TD"
            }
            stat("Defense", s.players.filter { $0.stats.totalTackles + $0.stats.interceptions > 0 || $0.stats.sacks > 0 }
                    .sorted { $0.stats.totalTackles > $1.stats.totalTackles }) {
                "\($0.totalTackles) tkl, \($0.sacks.formatted()) sk, \($0.interceptions) int"
            }
        }
        .navigationTitle(team)
    }

    @ViewBuilder
    private func stat(_ title: String, _ players: [SeasonStats.Player], line: @escaping (FootballPlayerStats) -> String) -> some View {
        if !players.isEmpty {
            Section(title) {
                ForEach(players) { p in
                    LabeledContent {
                        Text(line(p.stats)).font(.callout.monospacedDigit())
                    } label: {
                        Text(p.label)
                        Text("\(p.games) game\(p.games == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

/// One soccer game in the library list.
private struct SoccerGameRow: View {
    let game: SoccerGame
    let isOpen: Bool

    var body: some View {
        let s = game.state
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "soccerball").foregroundStyle(.secondary)
                Text("\(game.home.name) \(s.goals(.home)) – \(s.goals(.away)) \(game.away.name)").font(.headline)
                if isOpen { Text("open").font(.caption2.bold()).foregroundStyle(.tint) }
            }
            Text("\(game.date.formatted(date: .abbreviated, time: .omitted)) · \(game.isOver ? "Final" : "In progress") · \(game.format.label)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
