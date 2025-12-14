import Foundation

extension String {
    /// Returns the string with leading and trailing whitespace removed
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
