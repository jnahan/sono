import Foundation
import os.log

/// Centralized logging utility with log levels
enum Logger {
    /// Log levels for different types of messages
    enum Level: String {
        case debug = "🔍"
        case info = "ℹ️"
        case success = "✅"
        case warning = "⚠️"
        case error = "❌"
        case system = "🔧"
        
        var osLogType: OSLogType {
            switch self {
            case .debug:
                return .debug
            case .info:
                return .info
            case .success:
                return .info
            case .warning:
                return .default
            case .error:
                return .error
            case .system:
                return .info
            }
        }
    }
    
    /// Logs a message with a specific level and category
    /// - Parameters:
    ///   - level: The log level (debug, info, success, warning, error, system)
    ///   - category: The category/component name (e.g., "TranscriptionService", "RecordingForm")
    ///   - message: The message to log
    ///   - file: The file name (automatically captured)
    ///   - function: The function name (automatically captured)
    ///   - line: The line number (automatically captured)
    static func log(
        _ level: Level,
        category: String,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let prefix = level.rawValue
        let logMessage = "[\(category)] \(message)"
        print("\(prefix) \(logMessage)")
        
        // Also log to OSLog for better system integration
        let osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.sono.app", category: category)
        os_log("%{public}@", log: osLog, type: level.osLogType, logMessage)
        #endif
    }
    
    // MARK: - Convenience Methods
    
    /// Logs a debug message
    static func debug(_ category: String, _ message: String) {
        log(.debug, category: category, message)
    }
    
    /// Logs an info message
    static func info(_ category: String, _ message: String) {
        log(.info, category: category, message)
    }
    
    /// Logs a success message
    static func success(_ category: String, _ message: String) {
        log(.success, category: category, message)
    }
    
    /// Logs a warning message
    static func warning(_ category: String, _ message: String) {
        log(.warning, category: category, message)
    }
    
    /// Logs an error message
    static func error(_ category: String, _ message: String) {
        log(.error, category: category, message)
    }
    
    /// Logs a system/maintenance message
    static func system(_ category: String, _ message: String) {
        log(.system, category: category, message)
    }
}
