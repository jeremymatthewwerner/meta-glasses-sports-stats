import Foundation
import Testing
@testable import SidelineCore

@Suite struct VoiceParserTests {
    func play(_ s: String) -> FootballPlay {
        let r = FootballVoiceParser.parse(s)
        guard let p = r.play else { Issue.record("no play parsed from: \(s) → \(r.normalized)"); return FootballPlay(kind: .penalty) }
        return p
    }

    @Test func rushWithTackle() {
        let p = play("22 run for 7, tackle by 54")
        #expect(p.kind == .rush)
        #expect(p.ballCarrier == 22)
        #expect(p.yards == 7)
        #expect(p.tacklers == [54])
    }

    @Test func bareCarrierAndNumberWords() {
        let p = play("Twenty two for seven")
        #expect(p.kind == .rush)
        #expect(p.ballCarrier == 22)
        #expect(p.yards == 7)
    }

    @Test func rushNoGainAndLoss() {
        #expect(play("22 up the middle for no gain").yards == 0)
        let loss = play("number 5 keeper for a loss of 3, tackled by 90 and 44")
        #expect(loss.ballCarrier == 5)
        #expect(loss.yards == -3)
        #expect(loss.tacklers == [90, 44])
    }

    @Test func completedPassTouchdown() {
        let p = play("11 to 80 for 15 yards, touchdown!")
        #expect(p.kind == .pass)
        #expect(p.passer == 11)
        #expect(p.receiver == 80)
        #expect(p.passResult == .complete)
        #expect(p.yards == 15)
        #expect(p.touchdown)
    }

    @Test func passWithoutPasserNumber() {
        // Stat-keepers often skip the QB: "to 80 for 54, touchdown".
        let p = play("to 80 for 54, touchdown!")
        #expect(p.kind == .pass)
        #expect(p.passResult == .complete)
        #expect(p.receiver == 80)
        #expect(p.passer == nil)
        #expect(p.yards == 54)
        #expect(p.touchdown)
    }

    @Test func incompletePass() {
        let p = play("incomplete pass intended for 80")
        #expect(p.kind == .pass)
        #expect(p.passResult == .incomplete)
        #expect(p.receiver == 80)
    }

    @Test func interceptionWithReturn() {
        let p = play("Pass picked off by 24, returned for 30")
        #expect(p.passResult == .intercepted)
        #expect(p.interceptedBy == 24)
        #expect(p.returnYards == 30)
        #expect(p.isTurnover)
    }

    @Test func sharedSack() {
        let p = play("sack by 90 and 55 for a loss of 8")
        #expect(p.kind == .sack)
        #expect(p.sackers == [90, 55])
        #expect(p.yards == -8)
    }

    @Test func kicks() {
        let fg = play("Field goal is good from 32")
        #expect(fg.kind == .fieldGoal)
        #expect(fg.kickResult == .good)
        #expect(fg.kickDistance == 32)

        let xp = play("PAT no good")
        #expect(xp.kind == .extraPoint)
        #expect(xp.kickResult == .missed)

        let punt = play("punt by 4 for 38, returned by 10 for 6")
        #expect(punt.kind == .punt)
        #expect(punt.kicker == 4)
        #expect(punt.kickDistance == 38)
        #expect(punt.returner == 10)
        #expect(punt.returnYards == 6)

        let ko = play("Kickoff by 3, returned by 22 for 25")
        #expect(ko.kind == .kickoff)
        #expect(ko.kicker == 3)
        #expect(ko.returner == 22)
        #expect(ko.returnYards == 25)
    }

    @Test func twoPointConversion() {
        let p = play("two point conversion good, 11 to 80")
        #expect(p.kind == .twoPoint)
        #expect(p.kickResult == .good)
        #expect(p.receiver == 80)
    }

    @Test func penaltyOnly() {
        let p = play("Holding on 72, 10 yards")
        #expect(p.kind == .penalty)
        #expect(p.penalty?.on == .offense)
        #expect(p.penalty?.yards == 10)
        #expect(p.penalty?.player == 72)
    }

    @Test func penaltyDoesNotBecomeYardage() {
        let p = play("22 run for 4, flag, offside defense 5 yards")
        #expect(p.kind == .rush)
        #expect(p.yards == 4)
        #expect(p.penalty?.on == .defense)
        #expect(p.penalty?.yards == 5)
    }

    @Test func fumbleLost() {
        let p = play("22 fumbles, forced by 40, recovered by 55")
        #expect(p.fumbledBy == 22)
        #expect(p.forcedFumbleBy == 40)
        #expect(p.fumbleRecoveredBy == 55)
        #expect(p.fumbleLost)
    }

    @Test func situationAndCommands() {
        let s = FootballVoiceParser.parse("Second and 7, ball on their 35")
        #expect(s.play == nil)
        #expect(s.situation?.down == 2)
        #expect(s.situation?.distance == 7)
        #expect(s.situation?.ballOn == 65)

        #expect(FootballVoiceParser.parse("scratch that").command == .undo)
        #expect(FootballVoiceParser.parse("start of the third quarter").situation?.quarter == 3)
        #expect(FootballVoiceParser.parse("um").isEmpty)
    }

    @Test func confidenceDropsWhenGuessing() {
        let sure = FootballVoiceParser.parse("22 run for 7")
        let guess = FootballVoiceParser.parse("22 run")   // no yards
        #expect(sure.confidence > guess.confidence)
        #expect(guess.notes.contains("yards not heard"))
    }
}

@Suite struct GameStateTests {
    func event(_ s: String, _ game: FootballGame) -> FootballEvent {
        let r = FootballVoiceParser.parse(s)
        return FootballEvent(offense: game.state.possession, play: r.play, situation: r.situation, source: .typed, transcript: s)
    }

    @Test func driveScoringAndKickoffFlow() {
        var g = FootballGame(home: TeamInfo(name: "Eagles"), away: TeamInfo(name: "Hawks"), openingKickoff: .away)
        // Away kicks to home; return to home 30.
        g.append(event("kickoff by 3 for 50, returned by 22 for 20", g))
        #expect(g.state.possession == .home)
        #expect(g.state.down == 1)
        #expect(g.state.ballOn == 30)

        g.append(event("22 run for 4", g))
        #expect(g.state.down == 2)
        #expect(g.state.distance == 6)
        #expect(g.state.ballOn == 34)

        g.append(event("11 to 80 for 12", g))
        #expect(g.state.down == 1)
        #expect(g.state.distance == 10)
        #expect(g.state.ballOn == 46)

        g.append(event("11 to 80 for 54 touchdown", g))
        #expect(g.state.points(.home) == 6)
        #expect(g.state.phase == .tryAfterTD)

        g.append(event("extra point good", g))
        #expect(g.state.points(.home) == 7)
        #expect(g.state.phase == .kickoff)
        #expect(g.state.possession == .home)   // home kicks off next
    }

    @Test func pickSixScoresForDefense() {
        var g = FootballGame(home: TeamInfo(name: "A"), away: TeamInfo(name: "B"), openingKickoff: .home)
        g.append(event("kickoff touchback", g))     // away ball at own 20
        #expect(g.state.possession == .away)
        #expect(g.state.ballOn == 20)
        g.append(event("interception by 24 returned for 20 touchdown", g))
        #expect(g.state.points(.home) == 6)
        #expect(g.state.points(.away) == 0)
        #expect(g.state.possession == .home)
    }

    @Test func turnoverOnDownsAndUndo() {
        var g = FootballGame(home: TeamInfo(name: "A"), away: TeamInfo(name: "B"))
        g.append(event("home ball, first and 10, ball on our 40", g))
        for _ in 0..<4 { g.append(event("22 run for 1", g)) }
        #expect(g.state.possession == .away)
        #expect(g.state.ballOn == 56)   // home 44 = away 56

        g.rejectLast()
        #expect(g.state.possession == .home)
        #expect(g.state.down == 4)
        #expect(g.state.distance == 7)
    }

    @Test func goalToGoAndSafety() {
        var g = FootballGame(home: TeamInfo(name: "A"), away: TeamInfo(name: "B"))
        g.append(event("home ball, first and 10, ball on their 15", g))
        g.append(event("22 run for 8", g))
        #expect(g.state.situationText == "2nd & 2 at opp 7")
        g.append(event("22 run for 2", g))
        #expect(g.state.down == 1)
        #expect(g.state.goalToGo)
        #expect(g.state.distance == 5)
        #expect(g.state.situationText == "1st & Goal at opp 5")

        var h = FootballGame(home: TeamInfo(name: "A"), away: TeamInfo(name: "B"))
        h.append(event("home ball, first and 10, ball on our 2", h))
        h.append(event("22 run for a loss of 3, safety", h))
        #expect(h.state.points(.away) == 2)
        #expect(h.state.phase == .kickoff)
        #expect(h.state.possession == .home)
    }
}

@Suite struct BoxScoreTests {
    func game(_ calls: [String], ruleSet: FootballRuleSet = .nfhs) -> FootballGame {
        var g = FootballGame(home: TeamInfo(name: "Eagles"), away: TeamInfo(name: "Hawks"), ruleSet: ruleSet, openingKickoff: .away)
        for c in calls {
            let r = FootballVoiceParser.parse(c)
            g.append(FootballEvent(offense: g.state.possession, play: r.play, situation: r.situation, source: .typed, transcript: c))
        }
        return g
    }

    @Test func offenseAndDefenseCredit() {
        let g = game([
            "kickoff by 3 for 50, returned by 22 for 20",
            "22 run for 4, tackle by 54",
            "11 to 80 for 12, tackled by 54 and 21",
            "11 incomplete to 80",
            "11 to 80 for 54 touchdown",
            "extra point good by 7",
        ])
        let box = g.boxScore()
        let qb = box.players[PlayerKey(team: .home, jersey: 11)]!
        #expect(qb.passCompletions == 2)
        #expect(qb.passAttempts == 3)
        #expect(qb.passYards == 66)
        #expect(qb.passTouchdowns == 1)

        let wr = box.players[PlayerKey(team: .home, jersey: 80)]!
        #expect(wr.receptions == 2)
        #expect(wr.targets == 3)
        #expect(wr.receivingYards == 66)
        #expect(wr.points == 6)

        let rb = box.players[PlayerKey(team: .home, jersey: 22)]!
        #expect(rb.rushAttempts == 1)
        #expect(rb.rushYards == 4)

        let lb = box.players[PlayerKey(team: .away, jersey: 54)]!
        #expect(lb.soloTackles == 1)
        #expect(lb.assistedTackles == 1)
        #expect(box.players[PlayerKey(team: .away, jersey: 21)]?.assistedTackles == 1)

        #expect(box.players[PlayerKey(team: .home, jersey: 7)]?.extraPointsMade == 1)
        #expect(box.team(.home).points == 7)
        #expect(box.team(.home).totalYards == 70)
        #expect(box.team(.home).firstDowns == 2)   // the 12-yard catch, and the TD past the line to gain
    }

    @Test func sackCreditDependsOnRuleSet() {
        let calls = [
            "away ball, first and 10, ball on our 30",
            "11 sacked by 90 for a loss of 7, fumbles, recovered by 90",
        ]
        let ncaa = game(calls, ruleSet: .ncaa).boxScore()
        let nfl = game(calls, ruleSet: .nfl).boxScore()

        // NCAA: sack-fumble gets no sack credit; NFL credits it.
        #expect(ncaa.players[PlayerKey(team: .home, jersey: 90)]?.sacks ?? 0 == 0)
        #expect(nfl.players[PlayerKey(team: .home, jersey: 90)]?.sacks == 1)
        // NCAA charges sack yards to the passer's rushing; NFL doesn't.
        #expect(ncaa.players[PlayerKey(team: .away, jersey: 11)]?.rushYards == -7)
        #expect(nfl.players[PlayerKey(team: .away, jersey: 11)]?.rushYards == 0)
        #expect(ncaa.players[PlayerKey(team: .home, jersey: 90)]?.fumbleRecoveries == 1)
        #expect(ncaa.team(.away).turnovers == 1)
    }

    @Test func halfSacksAndRejectedEventsIgnored() {
        var g = game([
            "away ball, first and 10, ball on our 30",
            "sack by 90 and 55 for a loss of 8",
            "22 run for 50",
        ])
        g.rejectLast()
        let box = g.boxScore()
        #expect(box.players[PlayerKey(team: .home, jersey: 90)]?.sacks == 0.5)
        #expect(box.players[PlayerKey(team: .home, jersey: 55)]?.sacks == 0.5)
        #expect(box.players[PlayerKey(team: .away, jersey: 22)] == nil)
    }
}
