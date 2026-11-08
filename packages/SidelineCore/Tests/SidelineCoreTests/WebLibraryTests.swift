import Foundation
import Testing
@testable import SidelineCore

@Suite struct WebLibraryTests {
    func event(_ s: String, _ game: FootballGame) -> FootballEvent {
        let r = FootballVoiceParser.parse(s)
        return FootballEvent(offense: r.situation?.possession ?? game.state.possession, play: r.play,
                             situation: r.situation, source: .voice, status: .confirmed, transcript: s)
    }

    func game(home: String = "Eagles", away: String = "Hawks", date: Date, ended: Bool, plays: [String]) -> FootballGame {
        var roster = Roster()
        roster.players[22] = .init(name: "Jane Smith")
        var g = FootballGame(home: TeamInfo(name: home, roster: roster), away: TeamInfo(name: away), openingKickoff: .away)
        g.date = date
        for s in plays { g.append(event(s, g)) }
        g.ended = ended
        return g
    }

    let utc = TimeZone(identifier: "UTC")!
    let oct31 = Date(timeIntervalSince1970: 1_793_469_600)   // 2026-10-31 17:00 UTC
    let nov7 = Date(timeIntervalSince1970: 1_794_074_400)    // 2026-11-07 17:00 UTC

    func library(clips: Bool = false) -> (WebLibrary, FootballGame, FootballGame) {
        let old = game(date: oct31, ended: true, plays: ["kickoff touchback", "22 run for 31 touchdown", "extra point good"])
        var new = game(away: "Lions <&>", date: nov7, ended: false, plays: ["kickoff touchback", "22 run for 9"])
        new.events[1].videoRefs = [VideoRef(assetID: "glasses-01.mov", start: 2, end: 19)]
        let exported: Set<UUID> = clips ? [new.events[1].id] : []
        return (WebLibrary(games: [old, new], exportedClips: exported, timeZone: utc, generated: nov7), old, new)
    }

    @Test func layoutHasIndexStyleAndOnePagePerGame() {
        let (lib, old, new) = library()
        let paths = lib.files().map(\.path)
        #expect(paths.contains("index.html") && paths.contains("style.css"))
        for g in [old, new] {
            #expect(paths.contains("games/\(g.id.uuidString)/index.html"))
            #expect(paths.contains("games/\(g.id.uuidString)/game.json"))
        }
    }

    @Test func indexListsNewestFirstWithScoresAndSeason() {
        let (lib, old, new) = library()
        let html = lib.indexPage()
        let newPos = html.range(of: new.id.uuidString)!.lowerBound
        let oldPos = html.range(of: old.id.uuidString)!.lowerBound
        #expect(newPos < oldPos)
        #expect(html.contains("Hawks 0 – Eagles 7"))
        #expect(html.contains("Oct 31, 2026 · Final · 3 plays"))
        #expect(html.contains("In progress"))
        #expect(html.contains("<td>Eagles</td><td>1–0 (1 in progress)</td>"))
    }

    @Test func textIsEscaped() {
        let (lib, _, new) = library()
        let html = lib.gamePage(new)
        #expect(html.contains("Lions &lt;&amp;&gt; at Eagles"))
        #expect(!html.contains("Lions <&>"))
    }

    @Test func gamePageHasQuartersRecapLeadersAndFilterablePlays() {
        let (lib, old, _) = library()
        let html = lib.gamePage(old)
        #expect(html.contains("<td class=\"total\">7</td>"))
        #expect(html.contains("Eagles beat Hawks 7–0."))
        #expect(html.contains("<a href=\"#player=home-22\">#22 Jane Smith</a>"))
        #expect(html.contains("<option value=\"home-22\">#22 Jane Smith (1 run)</option>"))
        #expect(html.contains("data-players=\"home-22\" data-tags=\"bigPlay touchdown\""))
        #expect(html.contains("data-tag=\"touchdown\""))
        #expect(!html.contains("data-tag=\"penalty\""))      // only tags that occur get a chip
        #expect(html.contains("<span class=\"badge tag-touchdown\">Touchdown</span>"))
    }

    @Test func clipsOnlyWhenExported() {
        let (without, _, new) = library(clips: false)
        #expect(!without.gamePage(new).contains("<video"))
        let (with, _, clipped) = library(clips: true)
        let html = with.gamePage(clipped)
        #expect(html.contains("<video controls playsinline preload=\"metadata\" src=\"clips/\(clipped.events[1].id.uuidString).mp4\">"))
        #expect(with.indexPage().contains("1 clip"))
    }

    @Test func clipsToExportTakesFirstRefOfKeptPlays() {
        let (_, old, new) = library()
        var rejected = old
        rejected.events[1].videoRefs = [VideoRef(assetID: "a.mov", start: 0, end: 5)]
        rejected.events[1].status = .rejected
        let clips = WebLibrary.clipsToExport([rejected, new])
        #expect(clips.count == 1)
        #expect(clips[0].eventID == new.events[1].id)
        #expect(clips[0].path == "games/\(new.id.uuidString)/clips/\(new.events[1].id.uuidString).mp4")
        #expect(clips[0].source.start == 2)
    }

    @Test func badTeamColorsAreIgnored() {
        var (lib, old, _) = library()
        old.home.jerseyColor = "red;background:url(x)"
        old.away.jerseyColor = "#1f6b45"
        lib.games = [old]
        let html = lib.gamePage(old)
        #expect(html.contains("style=\"background:#1f6b45\""))
        #expect(!html.contains("url(x)"))
    }
}
