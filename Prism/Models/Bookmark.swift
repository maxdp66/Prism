import Foundation
import AppKit

// MARK: - Bookmark

struct Bookmark: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var url: String
    var dateAdded: Date = Date()

    // Transient – loaded async after decode
    var faviconData: Data?

    init(title: String, url: String) {
        self.title = title
        self.url = url
    }

    var resolvedURL: URL? { URL(string: url) }

    var host: String {
        URL(string: url)?.host ?? url
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case id, title, url, dateAdded
    }
}

// MARK: - BookmarkStore

@MainActor
final class BookmarkStore: ObservableObject {

    static let shared = BookmarkStore()

    @Published var bookmarks: [Bookmark] = []

    private let storageKey = "com.prism.bookmarks"

    private init() {
        load()
        if bookmarks.isEmpty { seedDefaults() }
    }

    func add(title: String, url: String) {
        guard !url.isEmpty else { return }
        let bm = Bookmark(title: title.isEmpty ? url : title, url: url)
        bookmarks.append(bm)
        save()
    }

    func remove(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        save()
    }

    func remove(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        bookmarks.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: Persistence (async, non-blocking)

    private func save() {
        let snapshot = bookmarks
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: self.storageKey)
            }
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Bookmark].self, from: data)
        else { return }
        bookmarks = decoded
    }

    private func seedDefaults() {
        bookmarks = [
            Bookmark(title: "GitHub", url: "https://github.com"),
            Bookmark(title: "YouTube", url: "https://youtube.com"),
            Bookmark(title: "Hacker News", url: "https://news.ycombinator.com"),
            Bookmark(title: "Wikipedia", url: "https://wikipedia.org"),
            Bookmark(title: "DuckDuckGo", url: "https://duckduckgo.com"),
        ]
        // Save on background too
        let snapshot = bookmarks
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: self.storageKey)
            }
        }
    }
}
