import Foundation

// MARK: - QuickLink

/// Represents a user-editable quick access link displayed on the new tab page.
struct QuickLink: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var url: String
    var dateAdded: Date = Date()
    
    init(title: String, url: String) {
        self.title = title
        self.url = url
    }
    
    /// The URL as a Foundation URL object, if valid.
    var resolvedURL: URL? {
        URL(string: url)
    }
    
    /// The host/domain extracted from the URL.
    var host: String {
        URL(string: url)?.host ?? url
    }
    
    // MARK: Codable
    
    private enum CodingKeys: String, CodingKey {
        case id, title, url, dateAdded
    }
}