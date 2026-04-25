import Foundation

// MARK: - Suggestion

struct Suggestion: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let subtitle: String?
    let type: SuggestionType
    let dateText: String?

    static func == (lhs: Suggestion, rhs: Suggestion) -> Bool {
        lhs.text == rhs.text && lhs.type == rhs.type && lhs.subtitle == rhs.subtitle
    }
}

// MARK: - SuggestionType

enum SuggestionType: String, CaseIterable {
    case search
    case url
    case bookmark
    case history

    var iconName: String {
        switch self {
        case .search:   return "magnifyingglass"
        case .url:      return "globe"
        case .bookmark: return "star.fill"
        case .history:  return "clock"
        }
    }
}

// MARK: - AutocompleteService

final class AutocompleteService {

    static let shared = AutocompleteService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 10.0
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public async API

    func fetchSuggestions(
        for query: String,
        provider: AutocompleteProvider,
        customURL: String?,
        apiKey: String?,
        bookmarks: [Bookmark] = [],
        history: [HistoryEntry] = []
    ) async -> [Suggestion] {
        guard !query.isEmpty else { return [] }

        // Local results first (bookmarks + history), no network needed
        let localResults = buildLocalSuggestions(
            query: query,
            bookmarks: bookmarks,
            history: history
        )

        guard provider != .none,
              let urlString = provider.autocompleteURL(customURL: customURL),
              let baseURL = URL(string: urlString) else {
            return localResults
        }

        guard let request = buildRequest(
            provider: provider,
            baseURL: baseURL,
            query: query,
            apiKey: apiKey
        ) else {
            return localResults
        }

        do {
            let (data, _) = try await session.data(for: request)
            let remote = parseSuggestions(from: data, provider: provider, query: query)
            // Merge: local first, then remote de-duped
            let localURLs = Set(localResults.map { $0.text })
            let deduped = remote.filter { !localURLs.contains($0.text) }
            return localResults + deduped
        } catch {
            return localResults
        }
    }

    // MARK: - Local suggestions

    private func buildLocalSuggestions(
        query: String,
        bookmarks: [Bookmark],
        history: [HistoryEntry]
    ) -> [Suggestion] {
        let q = query.lowercased()

        let bookmarkSuggestions: [Suggestion] = bookmarks
            .filter { $0.url.lowercased().contains(q) || $0.title.lowercased().contains(q) }
            .prefix(3)
            .map { bm in
                Suggestion(text: bm.url, subtitle: bm.title, type: .bookmark, dateText: nil)
            }

        let historySuggestions: [Suggestion] = history
            .filter { $0.url.lowercased().contains(q) || $0.title.lowercased().contains(q) }
            .prefix(3)
            .map { entry in
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                let date = formatter.localizedString(for: entry.visitedAt, relativeTo: Date())
                return Suggestion(text: entry.url, subtitle: entry.title, type: .history, dateText: date)
            }

        // Deduplicate history vs bookmarks (bookmark wins)
        let bookmarkURLs = Set(bookmarkSuggestions.map { $0.text })
        let filteredHistory = historySuggestions.filter { !bookmarkURLs.contains($0.text) }

        return bookmarkSuggestions + filteredHistory
    }

    // MARK: - Request builder

    private func buildRequest(
        provider: AutocompleteProvider,
        baseURL: URL,
        query: String,
        apiKey: String?
    ) -> URLRequest? {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "GET"

        switch provider {
        case .none:
            return nil

        case .duckDuckGo:
            var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
            comps.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "type", value: "list")
            ]
            guard let url = comps.url else { return nil }
            request.url = url

        case .google:
            var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
            comps.queryItems = [
                URLQueryItem(name: "client", value: "firefox"),
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "hl", value: "en")
            ]
            guard let url = comps.url else { return nil }
            request.url = url

        case .brave:
            guard let key = apiKey, !key.isEmpty else { return nil }
            var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
            comps.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "country", value: "US"),
                URLQueryItem(name: "count", value: "8")
            ]
            guard let url = comps.url else { return nil }
            request.url = url
            request.setValue(key, forHTTPHeaderField: "X-Subscription-Token")

        case .searxng:
            var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
            comps.path = "/autocomplete"
            comps.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "format", value: "json")
            ]
            guard let url = comps.url else { return nil }
            request.url = url
        }

        return request
    }

    // MARK: - JSON parsing

    private func parseSuggestions(from data: Data, provider: AutocompleteProvider, query: String) -> [Suggestion] {
        let rawSuggestions: [String]

        switch provider {
        case .none:
            return []

        case .searxng, .duckDuckGo, .google:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  json.count > 1,
                  let arr = json[1] as? [String] else { return [] }
            rawSuggestions = arr

        case .brave:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let suggestions = json["suggestions"] as? [[String: Any]] else { return [] }
            rawSuggestions = suggestions.compactMap { $0["text"] as? String }
        }

        return rawSuggestions.map { suggestion in
            let type: SuggestionType = isLikelyURL(suggestion) ? .url : .search
            let subtitle = extractHost(from: suggestion)
            return Suggestion(text: suggestion, subtitle: subtitle, type: type, dateText: nil)
        }
    }

    // MARK: - Helpers

    private func extractHost(from text: String) -> String? {
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        guard let url = URL(string: encoded.hasPrefix("http") ? encoded : "https://\(encoded)"),
              let host = url.host else { return nil }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private func isLikelyURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains(".") && !trimmed.contains(" ") else { return false }
        let components = trimmed.split(separator: ".")
        guard let last = components.last, last.count >= 2 else { return false }
        return true
    }
}
