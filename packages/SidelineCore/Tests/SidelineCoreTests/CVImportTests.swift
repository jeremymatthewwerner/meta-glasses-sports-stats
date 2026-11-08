import Foundation
import Testing
@testable import SidelineCore

@Suite struct CVImportTests {
    func game() -> (FootballGame, UUID) {
        var g = FootballGame(home: TeamInfo(name: "Reds"), away: TeamInfo(name: "Blues"))
        let r = FootballVoiceParser.parse("22 run for 7, tackle by 54")
        let e = FootballEvent(offense: .home, play: r.play, source: .voice, transcript: "22 run for 7, tackle by 54",
                              videoRefs: [VideoRef(assetID: "glasses-01.mov", start: 2, end: 19)])
        g.append(e)
        return (g, e.id)
    }

    func report(_ g: FootballGame, _ play: UUID, refined: Bool = true) -> Data {
        let refinedJSON = refined ? #"{"start": 6.5, "end": 14.0}"# : "null"
        return """
        {"format": "sideline-cv-report", "version": 1, "game_id": "\(g.id.uuidString)",
         "teams": {"A": {"color": "#d83b3b", "team": "home"}, "B": {"color": "#2a4fb0", "team": "away"}},
         "plays": [{"play_id": "\(play.uuidString)", "index": 0,
           "clip": {"asset": "glasses-01.mov", "start": 2, "end": 19},
           "action": {"segment": {"start": 8.0, "end": 12.0, "confidence": 0.8, "peak_t": 9, "threshold": 0.5, "duration": 4},
                      "refined_clip": \(refinedJSON)},
           "matches": {"matched": [{"team": "home", "jersey": 22, "role": "ballCarrier", "track_id": 3,
                                    "confidence": 0.9, "team_conflict": false, "ambiguous": false}],
                       "missing": [{"team": "away", "jersey": 54, "role": "tacklers"}], "unexpected": []}}]}
        """.data(using: .utf8)!
    }

    @Test func appliesTrimNotesAndTeamColors() throws {
        var (g, id) = game()
        let summary = try g.applyCV(CVReport.decode(report(g, id)))
        #expect(summary.playsUpdated == 1 && summary.clipsTrimmed == 1 && summary.playersSeen == 1 && summary.playersNotSeen == 1)
        let e = g.events[0]
        #expect(e.videoRefs == [VideoRef(assetID: "glasses-01.mov", start: 6.5, end: 14.0),
                                VideoRef(assetID: "glasses-01.mov", start: 2, end: 19)])
        #expect(e.cv?.summary == "#22 ✓ · #54 not seen")
        #expect(e.cv?.actionConfidence == 0.8)
        #expect(g.home.jerseyColor == "#d83b3b" && g.away.jerseyColor == "#2a4fb0")
    }

    @Test func reimportIsIdempotentAndCanUntrim() throws {
        var (g, id) = game()
        try g.applyCV(CVReport.decode(report(g, id)))
        try g.applyCV(CVReport.decode(report(g, id)))
        #expect(g.events[0].videoRefs.count == 2)
        try g.applyCV(CVReport.decode(report(g, id, refined: false)))   // newer run didn't trim: back to original
        #expect(g.events[0].videoRefs == [VideoRef(assetID: "glasses-01.mov", start: 2, end: 19)])
        #expect(g.events[0].cv?.trimmed == false)
    }

    @Test func rejectsAnotherGamesReport() throws {
        var (g, id) = game()
        let other = FootballGame(home: TeamInfo(name: "X"), away: TeamInfo(name: "Y"))
        let data = report(other, id)
        #expect(throws: CVImportError.self) { try g.applyCV(CVReport.decode(data)) }
    }

    @Test func savedGamesWithoutCVStillDecode() throws {
        var (g, _) = game()
        g.events[0].cv = nil
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let back = try dec.decode(FootballGame.self, from: enc.encode(g))
        #expect(back.events[0].cv == nil && back.home.jerseyColor == nil)
    }
}
