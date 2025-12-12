import Foundation

/// Utility for formatting time
struct TimeFormatter {

    /// Format a timestamp in seconds to MM:SS or HH:MM:SS format
    static func formatTimestamp(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Format date with time (e.g., "Mon, Dec 12  ·  3:45PM")
    static func dateWithTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        let dateString = formatter.string(from: date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        timeFormatter.amSymbol = "AM"
        timeFormatter.pmSymbol = "PM"
        let timeString = timeFormatter.string(from: date)

        return "\(dateString)  ·  \(timeString)"
    }
}
