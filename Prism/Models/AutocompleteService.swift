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
        case .search: return "magnifyingglass"
        case .url: return "globe"
        case .bookmark: return "star.fill"
        case .history: return "clock"
        }
    }
}

// MARK: - AutocompleteService

final class AutocompleteService {

    static let shared = AutocompleteService()

    private var currentTask: URLSessionDataTask?
    private let session = URLSession.shared

    private init() {}

    func fetchSuggestions(
        for query: String,
        provider: AutocompleteProvider,
        customURL: String?,
        apiKey: String?,
        completion: @escaping ([Suggestion]) -> Void
    ) {
        currentTask?.cancel()

        guard !query.isEmpty else {
            completion([])
            return
        }

        guard let urlString = provider.autocompleteURL(customURL: customURL),
              let url = URL(string: urlString) else {
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        switch provider {
        case .none:
            completion([])
            return

        case .duckDuckGo:
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "type", value: "list")
            ]
            guard let acURL = components.url else {
                completion([])
                return
            }
            request.url = acURL

        case .google:
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "client", value: "firefox"),
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "hl", value: "en")
            ]
            guard let acURL = components.url else {
                completion([])
                return
            }
            request.url = acURL

        case .brave:
            guard let apiKey = apiKey, !apiKey.isEmpty else {
                completion([])
                return
            }
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "country", value: "US"),
                URLQueryItem(name: "count", value: "8")
            ]
            guard let acURL = components.url else {
                completion([])
                return
            }
            request.url = acURL
            request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")

        case .searxng:
            guard let customURL = customURL, !customURL.isEmpty else {
                completion([])
                return
            }
            var baseURL = customURL
            if !baseURL.hasPrefix("http://") && !baseURL.hasPrefix("https://") {
                baseURL = "https://" + baseURL
            }
            baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let searxURL = URL(string: baseURL) else {
                completion([])
                return
            }
            var components = URLComponents(url: searxURL, resolvingAgainstBaseURL: false)!
            components.path = "/autocomplete"
            components.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "format", value: "json")
            ]
            guard let acURL = components.url else {
                completion([])
                return
            }
            request.url = acURL
        }

        currentTask = session.dataTask(with: request) { data, response, error in
            guard error == nil,
                  let data = data else {
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }

            let suggestions = self.parseSuggestions(from: data, provider: provider, query: query)

            DispatchQueue.main.async {
                completion(suggestions)
            }
        }

        currentTask?.resume()
    }

    private func parseSuggestions(from data: Data, provider: AutocompleteProvider, query: String) -> [Suggestion] {
        let rawSuggestions: [String]

        switch provider {
        case .none:
            return []

        case .searxng:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  json.count > 1,
                  let suggestions = json[1] as? [String] else {
                return []
            }
            rawSuggestions = suggestions

        case .duckDuckGo:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  json.count > 1,
                  let suggestions = json[1] as? [String] else {
                return []
            }
            rawSuggestions = suggestions

        case .google:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  json.count > 1,
                  let suggestionsArray = json[1] as? [String] else {
                return []
            }
            rawSuggestions = suggestionsArray

        case .brave:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let suggestions = json["suggestions"] as? [[String: Any]] else {
                return []
            }
            rawSuggestions = suggestions.compactMap { $0["text"] as? String }
        }

        return rawSuggestions.map { suggestion in
            let type: SuggestionType
            if isLikelyURL(suggestion) {
                type = .url
            } else {
                type = .search
            }
            let subtitle = extractHost(from: suggestion)
            return Suggestion(
                text: suggestion,
                subtitle: subtitle,
                type: type,
                dateText: nil
            )
        }
    }

    private func extractHost(from text: String) -> String? {
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        guard let url = URL(string: encoded.hasPrefix("http") ? encoded : "https://\(encoded)"),
              let host = url.host else {
            return nil
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private func isLikelyURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Contains a dot (domain separator), no spaces, and has a plausible path or TLD
        guard trimmed.contains(".") && !trimmed.contains(" ") else { return false }
        // Exclude raw search queries that happen to contain dots (e.g. "swift 5.9")
        let components = trimmed.split(separator: ".")
        guard let last = components.last, last.count >= 2 else { return false }
        return true
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
}