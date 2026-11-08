import Foundation
import Testing
@testable import SidelineCore

@Suite struct PlayerCuesTests {
    func event(_ s: String, _ game: FootballGame) -> FootballEvent {
        let r = FootballVoiceParser.parse(s)
        return FootballEvent(offense: r.situation?.possession ?? game.state.possession, play: r.play,
                             situation: r.situation, source: .voice, status: .confirmed, transcript: s)
    }

    /// Appends the call and returns (event, state before).
    @discardableResult
    func call(_ s: String, _ g: inout FootballGame) -> (FootballEvent, FootballGameState) {
        let before = g.state
        let e = event(s, g)
        g.append(e)
        return (e, before)
    }

    func newGame() -> FootballGame {
        FootballGame(home: TeamInfo(name: "Eagles"), away: TeamInfo(name: "Hawks"), openingKickoff: .away)
    }

    let t0 = Date(timeIntervalSince1970: 1_000_000)

    // MARK: Clock

    @Test func clockCountsDownAndClampsAtZero() {
        var c = PlayClock()
        #expect(c.remaining(at: t0) == nil && !c.isRunning)
        c.start(40, at: t0)
        #expect(c.remaining(at: t0.addingTimeInterval(12.5)) == 27.5)
        #expect(c.display(at: t0.addingTimeInterval(12.5)) == 28)
        #expect(c.remaining(at: t0.addingTimeInterval(60)) == 0)
        c.stop()
        #expect(c.display(at: t0) == nil)
    }

    @Test func lensShowsCoarseStepsSoItRarelyResends() {
        var c = PlayClock()
        #expect(c.lensText(at: t0) == nil)
        c.start(40, at: t0)
        let texts = stride(from: 0.0, through: 41, by: 0.5).map { c.lensText(at: t0.addingTimeInterval($0))! }
        var changes: [String] = []
        for t in texts where t != changes.last { changes.append(t) }
        #expect(changes == ["40", "under 30", "under 20", "under 10", "under 5", "TIME"])
        c.start(25, at: t0)
        #expect(c.lensText(at: t0) == "25")
        #expect(c.lensText(at: t0.addingTimeInterval(6)) == "under 20")
    }

    @Test func marksAreSpokenOnceEachAsTheyAreCrossed() {
        var c = PlayClock()
        c.start(25, at: t0)
        let marks = [20, 10, 5, 4, 3, 2, 1, 0]
        #expect(c.marksCrossed(marks, from: t0, to: t0.addingTimeInterval(4.9)) == [])
        #expect(c.marksCrossed(marks, from: t0.addingTimeInterval(4.9), to: t0.addingTimeInterval(5.0)) == [20])
        #expect(c.marksCrossed(marks, from: t0.addingTimeInterval(5.0), to: t0.addingTimeInterval(5.2)) == [])
        // A late tick (app was busy) catches up on everything it skipped.
        #expect(c.marksCrossed(marks, from: t0.addingTimeInterval(19.9), to: t0.addingTimeInterval(22.1)) == [5, 4, 3])
        #expect(c.marksCrossed(marks, from: t0.addingTimeInterval(24.9), to: t0.addingTimeInterval(25.3)) == [0])
        #expect(c.marksCrossed(marks, from: t0.addingTimeInterval(25.3), to: t0.addingTimeInterval(26)) == [])
    }

    @Test func fortyAfterOrdinaryPlaysTwentyFiveAfterStops() {
        var g = newGame()
        let rule = CueSettings.ClockRule.fortyTwentyFive
        func length(_ s: String) -> TimeInterval {
            let (e, before) = call(s, &g)
            return PlayClock.length(after: e, before: before, after: g.state, rule: rule)
        }
        #expect(length("kickoff touchback") == 25)
        #expect(length("22 run for 4") == 40)
        #expect(length("11 incomplete to 80") == 40)
        #expect(length("holding on 72, 10 yards") == 25)
        #expect(length("start of the second quarter") == 25)
        #expect(length("11 to 80 for 30 touchdown") == 25)
        #expect(length("extra point good") == 25)
        var youth = newGame()
        let (e, before) = call("22 run for 4", &youth)
        #expect(PlayClock.length(after: e, before: before, after: youth.state, rule: .twentyFive) == 25)
    }

    @Test func clockVoiceCommands() {
        for s in ["start the play clock", "play clock", "start clock", "clock"] {
            #expect(FootballVoiceParser.parse(s).command == .clock, "\(s)")
        }
        for s in ["25 clock", "start a twenty five second clock", "clock 25"] {
            #expect(FootballVoiceParser.parse(s).command == .clock25, "\(s)")
        }
        #expect(FootballVoiceParser.parse("40 second clock").command == .clock40)
        for s in ["stop the clock", "stop clock", "clock off", "cancel the play clock"] {
            #expect(FootballVoiceParser.parse(s).command == .stopClock, "\(s)")
        }
        // Plays and undo still parse as before.
        #expect(FootballVoiceParser.parse("cancel").command == .undo)
        #expect(FootballVoiceParser.parse("22 run for 4").play?.yards == 4)
    }

    // MARK: Spoken text

    @Test func situationReadsNaturally() {
        var g = newGame()
        #expect(CueComposer.situation(g) == "Hawks kicking off.")
        call("kickoff touchback", &g)
        #expect(CueComposer.situation(g) == "Eagles ball. First and 10 at the Eagles 20.")
        call("22 run for 40", &g)
        #expect(CueComposer.situation(g) == "Eagles ball. First and 10 at the Hawks 40.")
        call("22 run for 15", &g)
        call("22 run for 3", &g)
        #expect(CueComposer.situation(g) == "Eagles ball. Second and 7 at the Hawks 22.")
    }

    @Test func scoreChangeNamesTheScoreAndLeader() {
        var g = newGame()
        call("kickoff touchback", &g)
        var (e, before) = call("11 to 80 for 75 touchdown", &g)
        #expect(CueComposer.scoreChange(g, before: before, event: e) == "Touchdown Eagles. Eagles 6, Hawks 0.")
        (e, before) = call("extra point good", &g)
        #expect(CueComposer.scoreChange(g, before: before, event: e) == "Extra point Eagles. Eagles 7, Hawks 0.")
        (e, before) = call("22 run for 3", &g)
        #expect(CueComposer.scoreChange(g, before: before, event: e) == nil)
    }

    @Test func myStatsOnlyWhenTheWearerIsInThePlay() {
        var g = newGame()
        let me = PlayerKey(team: .home, jersey: 80)
        call("kickoff touchback", &g)
        var (e, _) = call("11 to 80 for 12", &g)
        #expect(CueComposer.myStats(g, event: e, me: me) == "You: 1 catch, 12 yards.")
        (e, _) = call("11 to 80 for 30 touchdown", &g)
        #expect(CueComposer.myStats(g, event: e, me: me) == "You: 2 catches, 42 yards, 1 touchdown.")
        (e, _) = call("22 run for 3", &g)
        #expect(CueComposer.myStats(g, event: e, me: me) == nil)
        // Same number on the other team isn't the wearer.
        #expect(CueComposer.myStats(g, event: e, me: PlayerKey(team: .away, jersey: 80)) == nil)
    }

    @Test func afterEventCombinesEnabledCuesInOrder() {
        var g = newGame()
        var settings = CueSettings()
        settings.me = PlayerKey(team: .home, jersey: 22)
        call("kickoff touchback", &g)
        let (e, before) = call("22 run for 75 touchdown", &g)
        #expect(CueComposer.afterEvent(e, game: g, before: before, settings: settings)
                == "Touchdown Eagles. Eagles 6, Hawks 0. You: 1 carry, 75 yards, 1 touchdown. Eagles try after touchdown.")
        settings.announceSituation = false
        settings.announceScore = false
        settings.announceMyStats = false
        #expect(CueComposer.afterEvent(e, game: g, before: before, settings: settings) == nil)
    }

    @Test func settingsRoundTripAndOldDataDecodes() throws {
        var s = CueSettings()
        s.me = PlayerKey(team: .away, jersey: 7)
        s.clockRule = .twentyFive
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(CueSettings.self, from: data) == s)
    }
}
