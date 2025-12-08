import Foundation

/// Utility for formatting time durations and relative dates
struct TimeFormatter {
    
    /// Format a duration in seconds to human-readable string (e.g., "1hr 30m", "45m", "30s")
    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return "\(hours)hr \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            let seconds = Int(duration) % 60
            return "\(seconds)s"
        }
    }
    
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
    
    /// Convert a date to relative string (e.g., "Today", "Yesterday", "3d ago", "2w ago")
    static func relativeDate(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let components = calendar.dateComponents([.day], from: date, to: now)
            if let days = components.day, days < 7 {
                return "\(days)d ago"
            } else if let days = components.day, days < 30 {
                let weeks = days / 7
                return "\(weeks)w ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                return formatter.string(from: date)
            }
        }
    }
}
