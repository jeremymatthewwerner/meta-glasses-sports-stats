import Foundation
import Testing
@testable import SidelineCore

@Suite struct SummaryTests {
    func event(_ s: String, _ game: FootballGame) -> FootballEvent {
        let r = FootballVoiceParser.parse(s)
        return FootballEvent(offense: r.situation?.possession ?? game.state.possession, play: r.play,
                             situation: r.situation, source: .voice, status: .confirmed, transcript: s)
    }

    func sampleGame(ended: Bool = true) -> FootballGame {
        var roster = Roster()
        roster.players[22] = .init(name: "Jane Smith")
        roster.players[11] = .init(name: "Alex Kim")
        var g = FootballGame(home: TeamInfo(name: "Eagles", roster: roster), away: TeamInfo(name: "Hawks"),
                             openingKickoff: .away)
        for s in ["kickoff touchback", "22 run for 12", "11 to 80 for 25", "22 run for 43 touchdown", "extra point good",
                  "kickoff touchback", "start of the second quarter", "5 run for 4, tackle by 54", "9 pass intercepted by 31",
                  "11 to 22 for 30 touchdown", "extra point no good"] {
            g.append(event(s, g))
        }
        g.ended = ended
        return g
    }

    @Test func scoreByQuarterAndScoringSummary() {
        let s = GameSummary(game: sampleGame())
        #expect(s.score[.home] == 13 && s.score[.away] == 0)
        #expect(s.byQuarter[.home] == [7, 6, 0, 0])
        #expect(s.scoring.map(\.points) == [6, 1, 6])
        #expect(s.scoring.last?.home == 13 && s.scoring.last?.quarter == 2)
    }

    @Test func leadersUseRosterNames() {
        let s = GameSummary(game: sampleGame())
        let rush = s.leaders.first { $0.category == "Rushing" && $0.player.team == .home }
        #expect(rush?.name == "#22 Jane Smith")
        #expect(rush?.line == "2 car, 55 yds, 1 TD")
        let pass = s.leaders.first { $0.category == "Passing" && $0.player.team == .home }
        #expect(pass?.line == "2/2, 55 yds, 1 TD")
        #expect(s.leaders.contains { $0.category == "Tackles" && $0.player == PlayerKey(team: .home, jersey: 54) })
    }

    @Test func recapReadsLikeASentence() {
        let final = GameSummary(game: sampleGame()).recap
        #expect(final.hasPrefix("Eagles beat Hawks 13–0."))
        #expect(final.contains("#22 Jane Smith ran for 55 yards on 2 carries and a touchdown"))
        #expect(final.contains("#11 Alex Kim threw for 55 yards and a touchdown"))
        #expect(final.contains("Biggest play: #22 run for 43"))
        #expect(final.contains("Turnovers: Eagles 0, Hawks 1."))
        let live = GameSummary(game: sampleGame(ended: false)).recap
        #expect(live.hasPrefix("Eagles lead Hawks 13–0 in the 2nd quarter."))
        #expect(GameSummary(game: FootballGame(home: TeamInfo(name: "A"), away: TeamInfo(name: "B"))).recap == "No plays yet.")
    }

    @Test func keyPlaysAreTouchdownsTurnoversAndBigPlays() {
        let s = GameSummary(game: sampleGame())
        #expect(s.keyPlays.count == 4)                       // 25-yd pass, 43-yd TD run, interception, 30-yd TD pass
        #expect(s.keyPlays.allSatisfy { !$0.tags.intersection([.touchdown, .turnover, .bigPlay]).isEmpty })
    }

    @Test func seasonTotalsAcrossGames() {
        let g1 = sampleGame()
        var g2 = FootballGame(home: TeamInfo(name: "Lions"), away: TeamInfo(name: "eagles"), openingKickoff: .home)
        g2.append(event("kickoff touchback", g2))            // Lions kick; Eagles (away) ball
        g2.append(event("22 run for 10", g2))
        g2.ended = true
        let season = SeasonStats(team: "Eagles", games: [g1, g2, FootballGame(home: TeamInfo(name: "X"), away: TeamInfo(name: "Y"))])
        #expect(season.games == 2)
        #expect(season.record == "1–0–1")                    // a 13–0 win and a 0–0 tie
        #expect(season.pointsFor == 13 && season.pointsAgainst == 0)
        let jane = season.players.first { $0.jersey == 22 }
        #expect(jane?.games == 2 && jane?.stats.rushYards == 65 && jane?.label == "#22 Jane Smith")
        #expect(SeasonStats.teamNames(in: [g1, g2]).first == "Eagles")
        let unnamed = FootballGame(home: TeamInfo(name: "Home"), away: TeamInfo(name: "Away"))
        #expect(SeasonStats.teamNames(in: [unnamed]).isEmpty)
    }
}
