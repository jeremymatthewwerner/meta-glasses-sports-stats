import Foundation

/// Converts spoken number words to digits ("twenty two" → "22",
/// "seventy-five" → "75", "number 7" → "7"). Speech recognizers usually emit
/// digits already, but not always, and jersey numbers are 0–99.
enum NumberWords {
    static let units: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
        "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13,
        "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
    ]
    static let tens: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90,
    ]

    /// Replaces number-word runs in an already-lowercased, space-separated string.
    static func digitize(_ text: String) -> String {
        let words = text.split(separator: " ").map(String.init)
        var out: [String] = []
        var i = 0
        while i < words.count {
            let w = words[i]
            if let t = tens[w] {
                if i + 1 < words.count, let u = units[words[i + 1]], u < 10, u > 0 {
                    out.append(String(t + u))
                    i += 2
                } else {
                    out.append(String(t))
                    i += 1
                }
            } else if let u = units[w] {
                out.append(String(u))
                i += 1
            } else {
                out.append(w)
                i += 1
            }
        }
        return out.joined(separator: " ")
    }
}
