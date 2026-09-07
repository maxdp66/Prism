import Foundation

// MARK: - URLValidator

/// A utility for validating and normalizing URLs.
/// Provides methods to check if a string is a valid URL and to normalize URLs.
struct URLValidator {
    
    /// Validates if the given string is a well-formed URL.
    /// - Parameter string: The string to validate.
    /// - Returns: `true` if the string is a valid URL, `false` otherwise.
    static func isValidURL(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        
        // Use NSDataDetector for robust URL detection
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        if let match = detector?.firstMatch(
            in: string,
            options: [],
            range: NSRange(location: 0, length: string.utf16.count)
        ) {
            return match.range.length == string.utf16.count && match.url != nil
        }
        
        return false
    }
    
    /// Validates and returns a URL if the string is valid.
    /// - Parameter string: The string to validate.
    /// - Returns: A valid URL, or `nil` if the string is not a valid URL.
    static func validateAndReturnURL(_ string: String) -> URL? {
        guard isValidURL(string) else { return nil }
        return URL(string: string)
    }
    
    /// Normalizes a URL string by ensuring it has a scheme.
    /// - Parameter string: The URL string to normalize.
    /// - Returns: A normalized URL string with a scheme prepended if missing.
    static func normalizeURL(_ string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return string }
        
        // If already has a scheme, return as-is
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        
        // Check for other schemes (mailto:, ftp:, etc.)
        if let colonIndex = trimmed.firstIndex(of: ":"),
           let scheme = try? NSRegularExpression(pattern: "^[a-zA-Z][a-zA-Z0-9+.-]*$"),
           scheme.firstMatch(in: String(trimmed[..<colonIndex]), options: [], range: NSRange(location: 0, length: String(trimmed[..<colonIndex]).utf16.count)) != nil {
            return trimmed
        }
        
        // Prepend https:// for web URLs
        return "https://\(trimmed)"
    }
    
    /// Extracts the host/domain from a URL string.
    /// - Parameter string: The URL string.
    /// - Returns: The host component, or the original string if extraction fails.
    static func extractHost(from string: String) -> String {
        guard let url = URL(string: string),
              let host = url.host else {
            return string
        }
        return host
    }
    
    /// Checks if a URL string represents a local/development address.
    /// - Parameter string: The URL string to check.
    /// - Returns: `true` if the URL is a local/development address.
    static func isLocalURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Check for localhost
        if trimmed.hasPrefix("http://localhost") || trimmed.hasPrefix("https://localhost") {
            return true
        }
        
        // Check for IP addresses
        if trimmed.hasPrefix("http://127.0.0.1") || trimmed.hasPrefix("https://127.0.0.1") {
            return true
        }
        
        if trimmed.hasPrefix("http://192.168") || trimmed.hasPrefix("https://192.168") {
            return true
        }
        
        if trimmed.hasPrefix("http://10.0") || trimmed.hasPrefix("https://10.0") {
            return true
        }
        
        return false
    }
}