import Foundation
import Testing
@testable import SidelineCore

@Suite struct GameRecordingTests {
    @Test func clipReachesBackBeforeTheCall() {
        let c = ClipPolicy.football.clip(assetID: "glasses-01.mov", anchor: 102)
        #expect(c == VideoRef(assetID: "glasses-01.mov", start: 87, end: 104))
    }

    @Test func clipClampsAtStartAndEnd() {
        let early = ClipPolicy.football.clip(assetID: "a", anchor: 5)
        #expect(early.start == 0)
        #expect(early.end == 7)
        let atEnd = ClipPolicy.football.clip(assetID: "a", anchor: 100, available: 101)
        #expect(atEnd.end == 101)
    }

    @Test func segmentNamesAndJSON() throws {
        var r = GameRecording(gameID: UUID())
        #expect(r.nextFileName == "glasses-01.mov")
        r.segments.append(.init(file: r.nextFileName, startedAt: Date(timeIntervalSince1970: 0),
                                endedAt: Date(timeIntervalSince1970: 90), frames: 1350, source: "test"))
        #expect(r.nextFileName == "glasses-02.mov")
        #expect(r.segments[0].duration == 90)
        let data = try JSONEncoder().encode(r)
        #expect(try JSONDecoder().decode(GameRecording.self, from: data) == r)
    }
}
