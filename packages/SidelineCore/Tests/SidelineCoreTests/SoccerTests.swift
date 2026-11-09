import Foundation
import Testing
@testable import SidelineCore

@Suite struct SoccerTests {
    let t0 = Date(timeIntervalSince1970: 2_000_000)

    func newGame(_ format: SoccerFormat = .nineASide) -> SoccerGame {
        SoccerGame(home: TeamInfo(name: "Eagles"), away: TeamInfo(name: "Hawks"), format: format, focus: .home)
    }

    /// Parses and appends a call at `minute` minutes after t0 (wall clock).
    @discardableResult
    func call(_ s: String, _ g: inout SoccerGame, at minute: Double = 0) -> ParsedSoccerCall {
        let r = SoccerVoiceParser.parse(s, game: g)
        if let a = r.action {
            g.append(SoccerEvent(action: a, source: .voice, status: .confirmed, transcript: s,
                                 wallTime: t0.addingTimeInterval(minute * 60)))
        }
        return r
    }

    func action(_ s: String, _ g: SoccerGame = SoccerGame(home: TeamInfo(name: "Eagles"), away: TeamInfo(name: "Hawks"))) -> SoccerAction? {
        SoccerVoiceParser.parse(s, game: g).action
    }

    // MARK: Grammar

    @Test func goalsWithScorerAndAssist() {
        for s in ["goal 9 assist 7", "goal by 9, assisted by 7", "9 scores from 7", "7 to 9, goal", "number nine scores, assist seven"] {
            let a = action(s)
            #expect(a?.kind == .goal && a?.player == 9 && a?.assist == 7 && a?.team == .home, "\(s)")
        }
        let p = action("penalty goal 10")
        #expect(p?.penalty == true && p?.player == 10 && p?.assist == nil)
        #expect(action("header goal 5 from 11")?.header == true)
        #expect(action("header goal 5 from 11")?.assist == 11)
        #expect(action("Hawks goal, 10")?.team == .away)
        #expect(action("they scored, 14")?.team == .away)
        #expect(action("goal kick")?.kind != .goal)
        #expect(action("shot on goal 8")?.kind == .shot)
    }

    @Test func ownGoalGoesToTheOtherTeam() {
        let a = action("own goal by their 4")
        #expect(a?.kind == .goal && a?.ownGoal == true && a?.team == .home && a?.player == 4)
        let b = action("own goal 3 Eagles")
        #expect(b?.team == .away && b?.player == 3)
        // No team named: the opponent put it in their own net.
        #expect(action("own goal")?.team == .home)
    }

    @Test func shotsAndSaves() {
        let a = action("shot 10 saved by 1")
        #expect(a?.kind == .shot && a?.player == 10 && a?.shotResult == .saved && a?.savedBy == 1)
        #expect(action("9 shoots wide")?.shotResult == .wide)
        #expect(action("shot blocked")?.shotResult == .blocked)
        #expect(action("off the post, 8")?.shotResult == .woodwork)
        #expect(action("off the post, 8")?.player == 8)
        #expect(action("their 11 shot on target")?.team == .away)
        // The team word after "saved by" is the keeper's.
        #expect(action("shot 10 saved by their 1")?.team == .home)
        #expect(action("shot 10 saved by our 1")?.team == .away)
        #expect(action("Hawks shot 10 saved by 1")?.team == .away)
        let save = action("great save 1")
        #expect(save?.kind == .save && save?.player == 1 && save?.team == .home)
    }

    @Test func setPiecesFoulsCardsSubsOffside() {
        #expect(action("corner us")?.kind == .corner && action("corner us")?.team == .home)
        #expect(action("corner Hawks")?.team == .away)
        let f = action("foul by 14 on 6")
        #expect(f?.kind == .foul && f?.player == 14 && f?.fouled == 6 && f?.team == .away)  // no team: the opponent fouled
        #expect(action("free kick for us")?.team == .away)
        #expect(action("foul on our 7")?.team == .away && action("foul on our 7")?.fouled == 7)
        let y = action("yellow card 4 away")
        #expect(y?.kind == .card && y?.card == .yellow && y?.player == 4 && y?.team == .away)
        #expect(action("red card their 5")?.card == .red)
        #expect(action("second yellow 5")?.card == .secondYellow)
        let sub = action("12 on for 7")
        #expect(sub?.kind == .substitution && sub?.player == 12 && sub?.playerOff == 7)
        #expect(action("sub 12 for 7")?.playerOff == 7)
        #expect(action("7 out 12 in")?.player == 12 && action("7 out 12 in")?.playerOff == 7)
        let o = action("offside 9")
        #expect(o?.kind == .offside && o?.team == .away)          // usually the other team's attacker
        #expect(action("offside our 9")?.team == .home)
    }

    @Test func periodsAndCommands() {
        var g = newGame()
        #expect(action("kickoff", g)?.kind == .periodStart && action("kickoff", g)?.period == 1)
        call("kickoff", &g)
        #expect(action("half time", g)?.kind == .periodEnd && action("half time", g)?.period == 1)
        call("halftime", &g, at: 30)
        #expect(action("start of the second half", g)?.period == 2)
        #expect(action("kickoff", g)?.period == 2)             // after a break, kickoff starts the next period
        call("second half underway", &g, at: 40)
        #expect(action("full time", g)?.period == 2)
        #expect(SoccerVoiceParser.parse("scratch that", game: g).command == .undo)
        #expect(SoccerVoiceParser.parse("redo", game: g).command == .redo)
        #expect(SoccerVoiceParser.parse("what a game", game: g).isEmpty)
    }

    @Test func unnamedTeamIsAssumedAndNoted() {
        let r = SoccerVoiceParser.parse("goal 9", game: newGame())
        #expect(r.confidence < 1 && r.notes.contains { $0.contains("Eagles") })
        #expect(SoccerVoiceParser.parse("goal home 9", game: newGame()).confidence == 1)
    }

    // MARK: Game

    @Test func scoreMinutesStatsAndRecap() {
        var g = newGame()
        call("kickoff", &g)
        call("shot 10 saved by 1 hawks", &g, at: 4)          // Hawks #10, saved by our keeper #1
        call("goal 9 assist 7", &g, at: 22.5)
        call("corner us", &g, at: 25)
        call("they scored 14", &g, at: 28)
        call("half time", &g, at: 30)
        call("start of the second half", &g, at: 40)
        call("goal 9 from 10", &g, at: 52)
        call("yellow card 4 away", &g, at: 55)
        call("full time", &g, at: 70)
        g.ended = true

        let s = g.state
        #expect(s.goals(.home) == 2 && s.goals(.away) == 1 && !s.running && s.period == 2)
        let goals = g.activeEvents.filter { $0.action.kind == .goal }
        #expect(goals.map { g.minute(of: $0) } == [23, 29, 43])     // second half starts at 31′ (9v9: 2×30)
        let box = g.boxScore()
        let nine = box.players[PlayerKey(team: .home, jersey: 9)]!
        #expect(nine.goals == 2 && nine.shots == 2 && nine.shotsOnTarget == 2)
        #expect(box.players[PlayerKey(team: .home, jersey: 7)]?.assists == 1)
        #expect(box.team(.home).corners == 1 && box.team(.away).yellowCards == 1)
        #expect(g.goalLog().first == "23′ Eagles · #9, assist #7 — 1–0")
        let recap = g.recap()
        #expect(recap.hasPrefix("Final: Eagles 2, Hawks 1."))
        #expect(recap.contains("Eagles: #9 ×2"))
        #expect(recap.contains("Hawks: #14"))
    }

    @Test func shotSaveCountsForTheKeeperTeam() {
        var g = newGame()
        call("shot 10 saved by 1", &g)
        let box = g.boxScore()
        #expect(box.team(.home).shotsOnTarget == 1 && box.team(.away).saves == 1)
        #expect(box.players[PlayerKey(team: .away, jersey: 1)]?.saves == 1)
        call("save 1", &g)                                    // our keeper saves: their shot on target
        let b2 = g.boxScore()
        #expect(b2.team(.home).saves == 1 && b2.team(.away).shotsOnTarget == 1)
    }

    @Test func secondYellowSendsOffAndUndoFixesState() {
        var g = newGame()
        call("yellow card 4 away", &g)
        call("yellow card 4 away", &g)
        #expect(g.state.sentOff[.away]?.contains(4) == true)
        g.rejectLast()
        #expect(g.state.sentOff[.away]?.contains(4) == false)
        call("goal 9", &g)
        g.rejectLast()
        #expect(g.state.goals(.home) == 0)
    }

    @Test func summariesAndHUD() {
        var g = newGame()
        g.home.roster = Roster(players: [9: .init(name: "Ava Lee")])
        call("kickoff", &g)
        call("goal 9 assist 7", &g, at: 12)
        #expect(g.summary(g.events[1]) == "Goal Eagles · #9 Ava Lee, assist #7")
        let hud = SoccerHUD(game: g, now: t0.addingTimeInterval(14.2 * 60))
        #expect(hud.scoreLine == "HAWKS 0  –  EAGLES 1")
        #expect(hud.situationLine == "1st half · 15′")
        #expect(hud.lastPlay == "Goal Eagles · #9 Ava Lee, assist #7")
        call("half time", &g, at: 30)
        #expect(SoccerHUD(game: g).situationLine == "Half time")
        #expect(SoccerHUD(game: newGame()).situationLine == "Before kickoff")
        #expect(g.summary(g.events.last!) == "Half time")
    }

    @Test func codableRoundTrip() throws {
        var g = newGame(.quarters)
        call("kickoff", &g)
        call("goal 9", &g, at: 3)
        let data = try JSONEncoder().encode(g)
        #expect(try JSONDecoder().decode(SoccerGame.self, from: data) == g)
        #expect(SoccerFormat.quarters.periodName(3) == "Q3" && SoccerFormat.full.periodName(3) == "ET 1")
    }
}
