import Foundation
import Combine

// MARK: - QuickLinkStore

/// Manages the collection of quick access links with persistence to UserDefaults.
@MainActor
final class QuickLinkStore: ObservableObject {
    
    static let shared = QuickLinkStore()
    
    /// The current collection of quick access links.
    @Published var quickLinks: [QuickLink] = []
    
    /// UserDefaults key for persisting quick links.
    private let storageKey = "com.prism.quickLinks"
    
    /// Default quick links to seed on first launch.
    private let defaultLinks: [QuickLink] = [
        QuickLink(title: "GitHub", url: "https://github.com"),
        QuickLink(title: "YouTube", url: "https://youtube.com"),
        QuickLink(title: "Hacker News", url: "https://news.ycombinator.com"),
        QuickLink(title: "Wikipedia", url: "https://wikipedia.org"),
        QuickLink(title: "DuckDuckGo", url: "https://duckduckgo.com"),
        QuickLink(title: "Reddit", url: "https://reddit.com"),
        QuickLink(title: "Twitter/X", url: "https://x.com"),
        QuickLink(title: "Anthropic", url: "https://anthropic.com"),
    ]
    
    private init() {
        load()
        if quickLinks.isEmpty {
            seedDefaults()
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Add a new quick link.
    /// - Parameters:
    ///   - title: The display title for the link.
    ///   - url: The URL to navigate to.
    func add(title: String, url: String) {
        guard !url.isEmpty else { return }
        let link = QuickLink(title: title.isEmpty ? url : title, url: url)
        quickLinks.append(link)
        save()
    }
    
    /// Remove a specific quick link.
    /// - Parameter link: The link to remove.
    func remove(_ link: QuickLink) {
        quickLinks.removeAll { $0.id == link.id }
        save()
    }
    
    /// Remove quick links at specified indices.
    /// - Parameter offsets: The indices to remove.
    func remove(at offsets: IndexSet) {
        quickLinks.remove(atOffsets: offsets)
        save()
    }
    
    /// Move quick links from source indices to a destination.
    /// - Parameters:
    ///   - source: The source indices.
    ///   - destination: The destination index.
    func move(from source: IndexSet, to destination: Int) {
        quickLinks.move(fromOffsets: source, toOffset: destination)
        save()
    }
    
    /// Update a quick link's title and URL.
    /// - Parameters:
    ///   - link: The link to update.
    ///   - title: The new title.
    ///   - url: The new URL.
    func update(_ link: QuickLink, title: String, url: String) {
        guard let index = quickLinks.firstIndex(where: { $0.id == link.id }) else { return }
        quickLinks[index].title = title.isEmpty ? url : title
        quickLinks[index].url = url
        save()
    }
    
    /// Reset the quick links to the default set.
    func resetToDefaults() {
        quickLinks = defaultLinks.map { QuickLink(title: $0.title, url: $0.url) }
        save()
    }
    
    // MARK: - Persistence
    
    /// Save the current quick links to UserDefaults.
    private func save() {
        let snapshot = quickLinks
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: self.storageKey)
            }
        }
    }
    
    /// Load quick links from UserDefaults.
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([QuickLink].self, from: data)
        else { return }
        quickLinks = decoded
    }
    
    /// Seed the default quick links and save them.
    private func seedDefaults() {
        quickLinks = defaultLinks
        let snapshot = quickLinks
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: self.storageKey)
            }
        }
    }
}