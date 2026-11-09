import Foundation
import Testing
@testable import SidelineCore

@Suite struct SoccerGalleryTests {
    func game(_ calls: [String]) -> SoccerGame {
        var g = SoccerGame(home: TeamInfo(name: "Eagles", roster: Roster.parse("9, Ava Lee").roster),
                           away: TeamInfo(name: "Hawks"), focus: .home)
        for (i, s) in calls.enumerated() {
            let a = try! #require(SoccerVoiceParser.parse(s, game: g).action, "\(s)")
            g.append(SoccerEvent(action: a, source: .voice, status: .confirmed, transcript: s,
                                 wallTime: Date(timeIntervalSince1970: Double(i) * 60)))
        }
        return g
    }

    @Test func playersAndRoles() {
        let g = game(["kickoff", "goal 9, assist 7", "shot 9 saved by their 1", "foul by 14 on 9", "own goal by their 4", "12 on for 7"])
        let gallery = SoccerGallery(game: g)
        let ava = try! #require(gallery.players.first { $0.player == PlayerKey(team: .home, jersey: 9) })
        #expect(ava.name == "Ava Lee")
        #expect(ava.roles[.goal] == 1 && ava.roles[.shot] == 1 && ava.roles[.fouled] == 1)
        #expect(ava.events.count == 3)
        #expect(ava.roleSummary == "1 goal · 1 shot · fouled once")
        let keeper = gallery.players.first { $0.player == PlayerKey(team: .away, jersey: 1) }
        #expect(keeper?.roles[.save] == 1)
        let og = gallery.players.first { $0.player == PlayerKey(team: .away, jersey: 4) }
        #expect(og?.roles[.ownGoal] == 1)
        #expect(gallery.players.contains { $0.player == PlayerKey(team: .home, jersey: 12) && $0.roles[.subOn] == 1 })
    }

    @Test func tags() {
        let g = game(["kickoff", "goal 9", "shot 10 wide", "shot 8 saved", "corner us", "yellow card 4 away", "offside 9", "half time"])
        let gallery = SoccerGallery(game: g)
        #expect(gallery.byTag[.goal]?.count == 1)
        #expect(gallery.byTag[.chance]?.count == 3)
        #expect(gallery.byTag[.save]?.count == 1)
        #expect(gallery.byTag[.corner]?.count == 1)
        #expect(gallery.byTag[.card]?.count == 1)
        #expect(gallery.byTag[.foul]?.count == 1)
        #expect(g.events.filter(\.action.wantsClip).count == 6)
    }

    @Test func rejectedEventsLeaveTheGallery() {
        var g = game(["goal 9"])
        g.rejectLast()
        #expect(SoccerGallery(game: g).players.isEmpty)
    }

    @Test func soccerClipsStartBeforeTheCall() {
        let ref = ClipPolicy.soccer.clip(assetID: "game-01.mov", anchor: 100)
        #expect(ref.start == 80 && ref.end == 104)
        #expect(ClipPolicy.soccer.clip(assetID: "game-01.mov", anchor: 5).start == 0)
    }
}
