import Foundation
import Testing
@testable import SidelineCore

@Suite struct GalleryTests {
    func event(_ s: String, _ game: FootballGame, status: EventStatus = .confirmed) -> FootballEvent {
        let r = FootballVoiceParser.parse(s)
        return FootballEvent(offense: game.state.possession, play: r.play, situation: r.situation,
                             source: .voice, status: status, transcript: s)
    }

    func sampleGame() -> FootballGame {
        var roster = Roster()
        roster.players[22] = .init(name: "Jane Smith", position: "RB")
        var g = FootballGame(home: TeamInfo(name: "Eagles", roster: roster), away: TeamInfo(name: "Hawks"),
                             openingKickoff: .away)
        g.append(event("kickoff by 3 for 50, returned by 22 for 25", g))   // away kicks, home 22 returns 25
        g.append(event("22 run for 18, tackle by 54", g))
        g.append(event("11 to 80 for 6, tackled by 54 and 21", g))
        g.append(event("11 pass intercepted by 24", g))
        g.append(event("22 run for 3", g, status: .rejected))
        return g
    }

    @Test func involvementsHaveSidesAndRoles() {
        let g = sampleGame()
        let ko = g.events[0].involvements
        #expect(ko.contains(PlayInvolvement(player: PlayerKey(team: .away, jersey: 3), role: .kicker)))
        #expect(ko.contains(PlayInvolvement(player: PlayerKey(team: .home, jersey: 22), role: .returner)))
        let pass = g.events[2].involvements
        #expect(pass.contains(PlayInvolvement(player: PlayerKey(team: .home, jersey: 80), role: .receiver)))
        #expect(pass.contains(PlayInvolvement(player: PlayerKey(team: .away, jersey: 21), role: .tackler)))
    }

    @Test func galleryGroupsByPlayerSkippingRejected() {
        let g = sampleGame()
        let gallery = FootballGallery(game: g)
        let jane = gallery.entry(for: PlayerKey(team: .home, jersey: 22))
        #expect(jane?.name == "Jane Smith")
        #expect(jane?.plays.count == 2)            // return + 18-yd run; the rejected run is excluded
        #expect(jane?.roles[.carrier] == 1)
        #expect(jane?.roles[.returner] == 1)
        let tackler = gallery.entry(for: PlayerKey(team: .away, jersey: 54))
        #expect(tackler?.plays.count == 2)
        #expect(g.displayName(PlayerKey(team: .home, jersey: 22)) == "#22 Jane Smith")
        #expect(g.displayName(PlayerKey(team: .away, jersey: 54)) == "#54")
    }

    @Test func tags() {
        let g = sampleGame()
        let gallery = FootballGallery(game: g)
        #expect(gallery.byTag[.bigPlay]?.count == 2)      // 25-yd return, 18-yd run
        #expect(gallery.byTag[.turnover]?.count == 1)
        #expect(gallery.byTag[.kick]?.count == 1)
        #expect(gallery.byTag[.touchdown] == nil)
    }

    @Test func rosterParsesCommonFormats() {
        let text = """
        Number,Name,Position
        22,Jane Smith,RB
        #11\tAlex Kim
        80 Sam Lee
        Chris Park, 54
        nonsense line
        """
        let (roster, problems) = Roster.parse(text)
        #expect(roster.name(for: 22) == "Jane Smith")
        #expect(roster.players[22]?.position == "RB")
        #expect(roster.name(for: 11) == "Alex Kim")
        #expect(roster.name(for: 80) == "Sam Lee")
        #expect(roster.name(for: 54) == "Chris Park")
        #expect(problems.count == 1)
        #expect(Roster.parse(roster.csv).roster == roster)
    }

    @Test func roleCounts() {
        #expect(PlayInvolvement.Role.passer.counted(2) == "2 passes")
        #expect(PlayInvolvement.Role.recovered.counted(3) == "3 recoveries")
        #expect(PlayInvolvement.Role.carrier.counted(1) == "1 run")
        #expect(PlayInvolvement.Role.tackler.counted(4) == "4 tackles")
    }

    @Test func oldSavedGamesWithoutRosterStillDecode() throws {
        let json = #"{"name":"Eagles","shortName":"EAGL"}"#.data(using: .utf8)!
        let team = try JSONDecoder().decode(TeamInfo.self, from: json)
        #expect(team.roster == nil)
    }
}
