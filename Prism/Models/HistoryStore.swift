import Foundation

// MARK: - HistoryEntry

struct HistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let url: String
    var visitedAt: Date

    init(title: String, url: String) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.visitedAt = Date()
    }
}

// MARK: - HistoryStore

@MainActor
final class HistoryStore: ObservableObject {

    static let shared = HistoryStore()

    @Published var entries: [HistoryEntry] = []

    private let storageKey = "com.prism.history"
    private let maxEntries = 500

    private init() {
        load()
    }

    func add(title: String, url: String) {
        guard !url.isEmpty, url != "about:blank" else { return }

        // Update visitedAt if URL already exists
        if let idx = entries.firstIndex(where: { $0.url == url }) {
            entries[idx].visitedAt = Date()
            entries[idx] = HistoryEntry(title: title.isEmpty ? url : title, url: url)
            entries[idx].visitedAt = Date()
            // Move to front so most-recent appears first
            let entry = entries.remove(at: idx)
            entries.insert(entry, at: 0)
        } else {
            let entry = HistoryEntry(title: title.isEmpty ? url : title, url: url)
            entries.insert(entry, at: 0)
        }

        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        save()
    }

    func clearAll() {
        entries = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - Persistence

    private func save() {
        let snapshot = entries
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: self.storageKey)
            }
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return }
        entries = decoded
    }
}
