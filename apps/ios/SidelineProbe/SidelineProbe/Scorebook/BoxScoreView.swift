import SidelineCore
import SwiftUI

struct BoxScoreView: View {
    let game: FootballGame
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let box = game.boxScore()
        NavigationStack {
            List {
                Section("Team") {
                    teamRow("Points", box) { $0.points }
                    teamRow("Total yards", box) { $0.totalYards }
                    teamRow("Rushing yards", box) { $0.rushYards }
                    teamRow("Passing yards", box) { $0.passYards }
                    teamRow("First downs", box) { $0.firstDowns }
                    teamRow("3rd down", box, text: { "\($0.thirdDownConversions)/\($0.thirdDownAttempts)" })
                    teamRow("Turnovers", box) { $0.turnovers }
                    teamRow("Penalties", box, text: { "\($0.penalties)-\($0.penaltyYards)" })
                }
                ForEach([TeamSide.away, .home], id: \.self) { side in
                    let players = box.players(of: side)
                    Section(game.team(side).name) {
                        if players.isEmpty { Text("No player stats yet").foregroundStyle(.secondary) }
                        statLines("Passing", players.filter { $0.stats.passAttempts > 0 }) {
                            "\($0.passCompletions)/\($0.passAttempts), \($0.passYards) yds, \($0.passTouchdowns) TD, \($0.interceptionsThrown) INT"
                        }
                        statLines("Rushing", players.filter { $0.stats.rushAttempts > 0 }) {
                            "\($0.rushAttempts) car, \($0.rushYards) yds, \($0.rushTouchdowns) TD"
                        }
                        statLines("Receiving", players.filter { $0.stats.targets > 0 }) {
                            "\($0.receptions) rec (\($0.targets) tgt), \($0.receivingYards) yds, \($0.receivingTouchdowns) TD"
                        }
                        statLines("Defense", players.filter {
                            $0.stats.totalTackles > 0 || $0.stats.sacks > 0 || $0.stats.interceptions > 0 || $0.stats.forcedFumbles > 0 || $0.stats.fumbleRecoveries > 0
                        }) {
                            var parts = ["\($0.soloTackles)+\($0.assistedTackles) tkl"]
                            if $0.sacks > 0 { parts.append("\($0.sacks.formatted()) sk") }
                            if $0.interceptions > 0 { parts.append("\($0.interceptions) INT") }
                            if $0.forcedFumbles > 0 { parts.append("\($0.forcedFumbles) FF") }
                            if $0.fumbleRecoveries > 0 { parts.append("\($0.fumbleRecoveries) FR") }
                            if $0.defensiveTouchdowns > 0 { parts.append("\($0.defensiveTouchdowns) TD") }
                            return parts.joined(separator: ", ")
                        }
                        statLines("Kicking", players.filter { $0.stats.fieldGoalsAttempted + $0.stats.extraPointsAttempted + $0.stats.punts + $0.stats.kickoffs > 0 }) {
                            var parts: [String] = []
                            if $0.fieldGoalsAttempted > 0 { parts.append("FG \($0.fieldGoalsMade)/\($0.fieldGoalsAttempted)") }
                            if $0.extraPointsAttempted > 0 { parts.append("XP \($0.extraPointsMade)/\($0.extraPointsAttempted)") }
                            if $0.punts > 0 { parts.append("\($0.punts) punts, \($0.puntYards) yds") }
                            if $0.kickoffs > 0 { parts.append("\($0.kickoffs) KO") }
                            return parts.joined(separator: ", ")
                        }
                    }
                }
                Section {
                    Text("Stats are recomputed from the play log under \(box.ruleSet.name) rules. Rejected plays don't count; proposed plays do until rejected.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("\(game.away.name) \(box.team(.away).points) – \(box.team(.home).points) \(game.home.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func teamRow(_ label: String, _ box: FootballBoxScore, _ value: (FootballTeamTotals) -> Int) -> some View {
        teamRow(label, box, text: { "\(value($0))" })
    }

    private func teamRow(_ label: String, _ box: FootballBoxScore, text: (FootballTeamTotals) -> String) -> some View {
        HStack {
            Text(text(box.team(.away))).monospacedDigit().frame(width: 70, alignment: .leading)
            Spacer()
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(text(box.team(.home))).monospacedDigit().frame(width: 70, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func statLines(_ title: String, _ rows: [(jersey: Int, stats: FootballPlayerStats)],
                           _ line: @escaping (FootballPlayerStats) -> String) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(rows, id: \.jersey) { row in
                    HStack(alignment: .top) {
                        Text("#\(row.jersey)").font(.body.monospacedDigit().bold()).frame(width: 44, alignment: .leading)
                        Text(line(row.stats)).font(.callout)
                    }
                }
            }
        }
    }
}
