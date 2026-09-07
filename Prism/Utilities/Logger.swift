import os.log
import Foundation

// MARK: - Log

/// A centralized logging utility for the Prism browser.
/// Provides structured logging with appropriate log levels.
///
/// Usage:
/// ```swift
/// Log.debug("Loading data...")
/// Log.info("Data loaded successfully")
/// Log.error("Failed to load data: \(error)")
/// ```
struct Log {
    
    // MARK: - Loggers
    
    /// General application logging.
    private static let generalLogger = Logger(subsystem: "com.prism.browser", category: "General")
    
    /// Networking-related logging.
    private static let networkLogger = Logger(subsystem: "com.prism.browser", category: "Network")
    
    /// WebKit/browser engine logging.
    private static let webkitLogger = Logger(subsystem: "com.prism.browser", category: "WebKit")
    
    /// Content blocker logging.
    private static let contentBlockerLogger = Logger(subsystem: "com.prism.browser", category: "ContentBlocker")
    
    /// State management logging.
    private static let stateLogger = Logger(subsystem: "com.prism.browser", category: "State")
    
    // MARK: - General Logging
    
    /// Log a debug message (only appears in debug builds).
    /// - Parameter message: The message to log.
    /// - Parameter file: The source file (automatically populated).
    /// - Parameter line: The line number (automatically populated).
    static func debug(_ message: String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        generalLogger.debug("[\(fileName):\(line)] \(message)")
        #endif
    }
    
    /// Log an info message.
    /// - Parameter message: The message to log.
    static func info(_ message: String) {
        generalLogger.info("\(message)")
    }
    
    /// Log an error message.
    /// - Parameter message: The message to log.
    /// - Parameter error: An optional error to include.
    static func error(_ message: String, error: Error? = nil) {
        if let error = error {
            generalLogger.error("\(message): \(error.localizedDescription)")
        } else {
            generalLogger.error("\(message)")
        }
    }
    
    /// Log a warning message.
    /// - Parameter message: The message to log.
    static func warning(_ message: String) {
        generalLogger.warning("\(message)")
    }
    
    // MARK: - Network Logging
    
    /// Log a network-related debug message.
    static func networkDebug(_ message: String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        networkLogger.debug("[\(fileName):\(line)] \(message)")
        #endif
    }
    
    /// Log a network-related error.
    static func networkError(_ message: String, error: Error? = nil) {
        if let error = error {
            networkLogger.error("\(message): \(error.localizedDescription)")
        } else {
            networkLogger.error("\(message)")
        }
    }
    
    // MARK: - WebKit Logging
    
    /// Log a WebKit-related message.
    static func webkit(_ message: String) {
        webkitLogger.info("\(message)")
    }
    
    /// Log a WebKit-related error.
    static func webkitError(_ message: String, error: Error? = nil) {
        if let error = error {
            webkitLogger.error("\(message): \(error.localizedDescription)")
        } else {
            webkitLogger.error("\(message)")
        }
    }
    
    // MARK: - Content Blocker Logging
    
    /// Log a content blocker-related message.
    static func contentBlocker(_ message: String) {
        contentBlockerLogger.info("\(message)")
    }
    
    /// Log a content blocker-related error.
    static func contentBlockerError(_ message: String, error: Error? = nil) {
        if let error = error {
            contentBlockerLogger.error("\(message): \(error.localizedDescription)")
        } else {
            contentBlockerLogger.error("\(message)")
        }
    }
    
    // MARK: - State Logging
    
    /// Log a state-related debug message.
    static func stateDebug(_ message: String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        stateLogger.debug("[\(fileName):\(line)] \(message)")
        #endif
    }
    
    /// Log a state-related info message.
    static func stateInfo(_ message: String) {
        stateLogger.info("\(message)")
    }
}