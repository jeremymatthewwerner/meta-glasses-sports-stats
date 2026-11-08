import Foundation

/// Jersey number → player, for one team. Imported from a CSV/paste (the
/// universal path; TeamSnap/GameChanger links come later).
public struct Roster: Codable, Sendable, Equatable {
    public struct Player: Codable, Sendable, Equatable {
        public var name: String
        public var position: String?
        public init(name: String, position: String? = nil) {
            self.name = name
            self.position = position
        }
    }

    public var players: [Int: Player]

    public init(players: [Int: Player] = [:]) {
        self.players = players
    }

    public func name(for jersey: Int) -> String? { players[jersey]?.name }

    public var isEmpty: Bool { players.isEmpty }

    /// Parses pasted or exported roster text. Accepts, one player per line:
    ///   `22,Jane Smith,RB` · `22<tab>Jane Smith` · `#22 Jane Smith` · `Jane Smith, 22`
    /// A header row and blank lines are skipped. Returns the roster and
    /// a note for every line it couldn't read.
    public static func parse(_ text: String) -> (roster: Roster, problems: [String]) {
        var players: [Int: Player] = [:]
        var problems: [String] = []
        for (i, raw) in text.split(whereSeparator: \.isNewline).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let fields = line.split(whereSeparator: { $0 == "," || $0 == "\t" || $0 == ";" })
                .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
                .filter { !$0.isEmpty }
            var number: Int?
            var rest: [String] = []
            if fields.count >= 2 {
                for f in fields {
                    if number == nil, let n = Int(f.trimmingCharacters(in: CharacterSet(charactersIn: "#"))), (0...99).contains(n) {
                        number = n
                    } else {
                        rest.append(f)
                    }
                }
            } else if let m = line.firstMatch(of: /^#?(\d{1,2})\s+(.+)$/) {
                number = Int(m.1)
                rest = [String(m.2)]
            }
            guard let number, let name = rest.first, !name.isEmpty else {
                if i > 0 || !line.lowercased().contains("name") {
                    problems.append("Line \(i + 1): couldn't read “\(line)”")
                }
                continue
            }
            players[number] = Player(name: name, position: rest.count > 1 ? rest[1] : nil)
        }
        return (Roster(players: players), problems)
    }

    /// CSV text that round-trips through `parse`.
    public var csv: String {
        players.keys.sorted().map { n in
            let p = players[n]!
            return ([String(n), p.name] + (p.position.map { [$0] } ?? [])).joined(separator: ",")
        }.joined(separator: "\n")
    }
}

extension FootballGame {
    /// "#22 Jane Smith" when the roster knows the number, else "#22".
    public func displayName(_ player: PlayerKey) -> String {
        if let name = team(player.team).roster?.name(for: player.jersey) {
            return "#\(player.jersey) \(name)"
        }
        return "#\(player.jersey)"
    }
}
