import Foundation
import SidelineCore

/// Saved games of every sport share one folder: Documents/games/<id>.json
/// plus <id>-utterances.json (and a <id>/ folder for videos). A file decodes
/// as the sport it is (football and soccer games have different required
/// fields), so each scorebook only sees its own games.
enum GameFiles {
    static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("games", isDirectory: true)
    }

    static func file(for id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).json") }
    static func utterancesFile(for id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString)-utterances.json") }

    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    /// Every saved game of one sport, most recently saved first.
    static func all<G: Decodable>(_ type: G.Type) -> [(game: G, url: URL)] {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        func modified(_ u: URL) -> Date {
            (try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
        let dec = decoder
        return files
            .filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasSuffix("-utterances.json") }
            .sorted { modified($0) > modified($1) }
            .compactMap { url in (try? Data(contentsOf: url)).flatMap { try? dec.decode(G.self, from: $0) }.map { ($0, url) } }
    }

    static func utterances(for id: UUID) -> [UtteranceLogEntry] {
        (try? Data(contentsOf: utterancesFile(for: id))).flatMap { try? decoder.decode([UtteranceLogEntry].self, from: $0) } ?? []
    }

    static func save<G: Encodable>(_ game: G, id: UUID, log: [UtteranceLogEntry]) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try encoder.encode(game).write(to: file(for: id), options: .atomic)
            try encoder.encode(log).write(to: utterancesFile(for: id), options: .atomic)
        } catch {
            print("[GameFiles] save failed: \(error)")
        }
    }

    static func folder(for id: UUID) -> URL { directory.appendingPathComponent(id.uuidString, isDirectory: true) }

    /// Video files for a game (glasses recordings and imported camera videos).
    static func recording(for id: UUID) -> GameRecording {
        let url = folder(for: id).appendingPathComponent("recording.json")
        return (try? Data(contentsOf: url)).flatMap { try? decoder.decode(GameRecording.self, from: $0) } ?? GameRecording(gameID: id)
    }

    static func saveRecording(_ r: GameRecording) {
        do {
            try FileManager.default.createDirectory(at: folder(for: r.gameID), withIntermediateDirectories: true)
            try encoder.encode(r).write(to: folder(for: r.gameID).appendingPathComponent("recording.json"), options: .atomic)
        } catch {
            print("[GameFiles] recording save failed: \(error)")
        }
    }

    static func delete(_ id: UUID) {
        let fm = FileManager.default
        try? fm.removeItem(at: file(for: id))
        try? fm.removeItem(at: utterancesFile(for: id))
        try? fm.removeItem(at: directory.appendingPathComponent(id.uuidString, isDirectory: true))
    }
}
