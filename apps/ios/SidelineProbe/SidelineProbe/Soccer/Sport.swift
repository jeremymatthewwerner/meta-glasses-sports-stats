import Foundation

/// Which scorebook the Scorebook tab shows (saved across launches).
enum Sport: String, CaseIterable, Identifiable {
    case football, soccer
    var id: String { rawValue }
    var label: String { self == .football ? "Football" : "Soccer" }
}
