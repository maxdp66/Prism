import Foundation

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
        completion: @escaping ([String]) -> Void
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
            guard apiKey?.isEmpty == false else {
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

            let suggestions = self.parseSuggestions(from: data, provider: provider)

            DispatchQueue.main.async {
                completion(suggestions)
            }
        }

        currentTask?.resume()
    }

    private func parseSuggestions(from data: Data, provider: AutocompleteProvider) -> [String] {
        switch provider {
        case .none:
            return []

        case .searxng:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  json.count > 1,
                  let suggestions = json[1] as? [String] else {
                return []
            }
            return suggestions

        case .duckDuckGo:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  json.count > 1,
                  let suggestions = json[1] as? [String] else {
                return []
            }
            return suggestions

        case .google:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  json.count > 1,
                  let suggestionsArray = json[1] as? [String] else {
                return []
            }
            return suggestionsArray

        case .brave:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let suggestions = json["suggestions"] as? [[String: Any]] else {
                return []
            }
            return suggestions.compactMap { $0["text"] as? String }
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
}