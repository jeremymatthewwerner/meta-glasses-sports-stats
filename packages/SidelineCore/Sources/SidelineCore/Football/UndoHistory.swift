import Foundation

/// Undo / redo for the scorebook. Undo rejects the newest play that still
/// counts; redo puts the most recently undone play back with the status it
/// had (proposed or confirmed). Calling a new play clears the redo history,
/// as in a text editor: redo only makes sense right after an undo.
public struct UndoHistory: Codable, Sendable, Equatable {
    struct Entry: Codable, Sendable, Equatable {
        var eventID: UUID
        var previous: EventStatus
    }

    private var redoStack: [Entry] = []

    public init() {}

    public var canRedo: Bool { !redoStack.isEmpty }

    /// The play a redo would restore, if it's still in the game and rejected.
    public func redoTarget(in game: FootballGame) -> FootballEvent? {
        guard let top = redoStack.last else { return nil }
        return game.events.first { $0.id == top.eventID && $0.status == .rejected }
    }

    @discardableResult
    public mutating func undo(in game: inout FootballGame) -> FootballEvent? {
        guard let event = game.events.last(where: { $0.status != .rejected }) else { return nil }
        redoStack.append(Entry(eventID: event.id, previous: event.status))
        game.setStatus(.rejected, for: event.id)
        return game.events.first { $0.id == event.id }
    }

    @discardableResult
    public mutating func redo(in game: inout FootballGame) -> FootballEvent? {
        while let top = redoStack.popLast() {
            // Skip entries that were changed some other way since (e.g. swiped back).
            guard game.events.contains(where: { $0.id == top.eventID && $0.status == .rejected }) else { continue }
            game.setStatus(top.previous, for: top.eventID)
            return game.events.first { $0.id == top.eventID }
        }
        return nil
    }

    /// Call when a new play is added.
    public mutating func clearRedo() { redoStack.removeAll() }
}
