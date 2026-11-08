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

@Suite struct UndoRedoTests {
    func event(_ s: String, _ game: FootballGame, status: EventStatus = .proposed) -> FootballEvent {
        let r = FootballVoiceParser.parse(s)
        return FootballEvent(offense: game.state.possession, play: r.play, situation: r.situation,
                             source: .voice, status: status, transcript: s)
    }

    @Test func redoRestoresPreviousStatusInOrder() {
        var g = FootballGame(home: TeamInfo(name: "A"), away: TeamInfo(name: "B"), openingKickoff: .away)
        var h = UndoHistory()
        g.append(event("kickoff touchback", g, status: .confirmed))
        g.append(event("22 run for 4", g))
        let afterRun = g.state

        h.undo(in: &g)          // rejects the run
        h.undo(in: &g)          // rejects the kickoff
        #expect(g.state.phase == .kickoff)
        #expect(h.redoTarget(in: g)?.id == g.events[0].id)

        h.redo(in: &g)          // kickoff back, still confirmed
        #expect(g.events[0].status == .confirmed)
        h.redo(in: &g)          // run back, still proposed
        #expect(g.events[1].status == .proposed)
        #expect(g.state == afterRun)
        #expect(!h.canRedo)
        #expect(h.redo(in: &g) == nil)
    }

    @Test func newPlayClearsRedo() {
        var g = FootballGame(home: TeamInfo(name: "A"), away: TeamInfo(name: "B"))
        var h = UndoHistory()
        g.append(event("kickoff touchback", g))
        h.undo(in: &g)
        h.clearRedo()
        #expect(!h.canRedo)
        #expect(h.redoTarget(in: g) == nil)
    }

    @Test func redoSkipsPlaysRestoredByHand() {
        var g = FootballGame(home: TeamInfo(name: "A"), away: TeamInfo(name: "B"))
        var h = UndoHistory()
        g.append(event("kickoff touchback", g))
        g.append(event("22 run for 4", g))
        h.undo(in: &g)                                  // run
        h.undo(in: &g)                                  // kickoff
        g.setStatus(.confirmed, for: g.events[0].id)    // kickoff swiped back by hand
        let restored = h.redo(in: &g)
        #expect(restored?.id == g.events[1].id)         // skips straight to the run
    }

    @Test func hudShowsRedoTarget() {
        var g = FootballGame(home: TeamInfo(name: "A"), away: TeamInfo(name: "B"))
        var h = UndoHistory()
        g.append(event("kickoff touchback", g))
        h.undo(in: &g)
        let hud = FootballHUD(game: g, redo: h.redoTarget(in: g))
        #expect(hud.lastPlay == nil)
        #expect(hud.redoPlay != nil)
    }

    @Test func redoVoiceCommands() {
        for s in ["redo", "put it back", "bring that back", "undo the undo", "Redo."] {
            #expect(FootballVoiceParser.parse(s).command == .redo, "\(s)")
        }
        #expect(FootballVoiceParser.parse("scratch that").command == .undo)
    }
}
