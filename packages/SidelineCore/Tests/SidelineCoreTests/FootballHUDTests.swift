import Foundation
import Testing
@testable import SidelineCore

@Suite struct FootballHUDTests {
    func event(_ s: String, _ game: FootballGame, status: EventStatus = .proposed) -> FootballEvent {
        let r = FootballVoiceParser.parse(s)
        return FootballEvent(offense: game.state.possession, play: r.play, situation: r.situation,
                             source: .voice, status: status, transcript: s)
    }

    @Test func emptyGame() {
        let g = FootballGame(home: TeamInfo(name: "Eagles"), away: TeamInfo(name: "Hawks"), openingKickoff: .away)
        let hud = FootballHUD(game: g)
        #expect(hud.scoreLine == "HAWKS 0  –  EAGLES 0")
        #expect(hud.situationLine == "Q1 · HAWKS kicking · Kickoff")
        #expect(hud.lastPlay == nil)
        #expect(!hud.lastPlayNeedsConfirm)
        #expect(hud.pendingCount == 0)
    }

    @Test func lastPlayAndPossession() {
        var g = FootballGame(home: TeamInfo(name: "Eagles"), away: TeamInfo(name: "Hawks"), openingKickoff: .away)
        g.append(event("kickoff by 3 for 50, returned by 22 for 20", g, status: .confirmed))
        g.append(event("22 run for 4, tackle by 54", g))
        let hud = FootballHUD(game: g)
        #expect(hud.scoreLine == "HAWKS 0  –  EAGLES 0")
        #expect(hud.situationLine == "Q1 · EAGLES ball · 2nd & 6 at own 34")
        #expect(hud.lastPlay?.contains("22") == true)
        #expect(hud.lastPlayID == g.events.last?.id)
        #expect(hud.lastPlayNeedsConfirm)
        #expect(hud.pendingCount == 1)
    }

    @Test func rejectedPlayFallsBackToPrevious() {
        var g = FootballGame(home: TeamInfo(name: "A"), away: TeamInfo(name: "B"), openingKickoff: .away)
        g.append(event("kickoff touchback", g, status: .confirmed))
        g.append(event("22 run for 4", g))
        _ = g.rejectLast()
        let hud = FootballHUD(game: g)
        #expect(hud.lastPlayID == g.events.first?.id)
        #expect(!hud.lastPlayNeedsConfirm)
        #expect(hud.situationLine == "Q1 · A ball · 1st & 10 at own 20")
    }

    @Test func longNamesAreShortened() {
        let g = FootballGame(home: TeamInfo(name: "Springfield Isotopes"), away: TeamInfo(name: ""))
        let hud = FootballHUD(game: g)
        #expect(hud.scoreLine.hasPrefix("TEAM 0"))
        #expect(hud.scoreLine.contains("SPRINGFIE…"))
    }
}
