import Foundation
import SwiftUI

// MARK: - Search Engine

enum SearchEngine: String, CaseIterable, Identifiable, Codable, Sendable {
    case duckDuckGo = "DuckDuckGo"
    case google = "Google"
    case bing = "Bing"
    case brave = "Brave"
    case ecosia = "Ecosia"
    case searxng = "SearXNG"

    var id: String { rawValue }

    var baseURL: String {
        switch self {
        case .duckDuckGo: "https://duckduckgo.com/"
        case .google:     "https://www.google.com/search"
        case .bing:       "https://www.bing.com/"
        case .brave:      "https://search.brave.com/search"
        case .ecosia:     "https://www.ecosia.org/"
        case .searxng:    ""
        }
    }

    var queryParameter: String {
        switch self {
        case .duckDuckGo, .google, .bing, .brave, .ecosia: "q"
        case .searxng: "q"
        }
    }

    func searchURL(for query: String) -> URL? {
        guard !baseURL.isEmpty else { return nil }
        var comps = URLComponents(string: baseURL)!
        comps.queryItems = [URLQueryItem(name: queryParameter, value: query)]
        return comps.url
    }

    func searchURL(for query: String, customBaseURL: String) -> URL? {
        guard !customBaseURL.isEmpty else { return nil }
        var baseURL = customBaseURL
        if !baseURL.hasPrefix("http://") && !baseURL.hasPrefix("https://") {
            baseURL = "https://" + baseURL
        }
        let cleanURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var comps = URLComponents(string: cleanURL) else { return nil }
        comps.path = "/"
        comps.queryItems = [URLQueryItem(name: queryParameter, value: query)]
        return comps.url
    }
}

// MARK: - Autocomplete Provider

enum AutocompleteProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case none = "None"
    case duckDuckGo = "DuckDuckGo"
    case google = "Google"
    case brave = "Brave"
    case searxng = "SearXNG"

    var id: String { rawValue }

    func autocompleteURL(customURL: String?) -> String? {
        switch self {
        case .none:
            return nil
        case .duckDuckGo:
            return "https://duckduckgo.com/ac/"
        case .google:
            return "https://www.google.com/complete/search"
        case .brave:
            return "https://api.search.brave.com/res/v1/suggest/search"
        case .searxng:
            guard let url = customURL, !url.isEmpty else { return nil }
            var baseURL = url
            if !baseURL.hasPrefix("http://") && !baseURL.hasPrefix("https://") {
                baseURL = "https://" + baseURL
            }
            baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return baseURL + "/autocomplete"
        }
    }

    var usesAPIKey: Bool {
        switch self {
        case .none, .duckDuckGo, .google, .searxng:
            return false
        case .brave:
            return true
        }
    }
}

// MARK: - Tab Layout Style

enum TabLayoutStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case standard = "Standard"
    case compact = "Compact"
    case vertical = "Vertical"

    var id: String { rawValue }

    var headerHeight: CGFloat {
        switch self {
        case .standard: return 56
        case .compact: return 42
        case .vertical: return 42
        }
    }
}

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "System"
    case dark = "Dark"
    case light = "Light"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

// MARK: - BrowserSettings

@MainActor
final class BrowserSettings: ObservableObject {

    static let shared = BrowserSettings()

    // MARK: - AppStorage keys

    private enum Keys {
        static let searchEngine       = "searchEngine"
        static let searxngURL       = "searxngURL"
        static let autocompleteProvider = "autocompleteProvider"
        static let autocompleteAPIKey = "autocompleteAPIKey"
        static let javascriptEnabled  = "javascriptEnabled"
        static let contentBlockerEnabled = "contentBlockerEnabled"
        static let autoplayEnabled    = "autoplayEnabled"
        static let homepageURL        = "homepageURL"
        static let appearanceMode     = "appearanceMode"
        static let layoutStyle        = "layoutStyle"
    }

    // MARK: - Published properties backed by @AppStorage

    @AppStorage(Keys.searchEngine)       var searchEngine: SearchEngine = .duckDuckGo
    @AppStorage(Keys.searxngURL)       var searxngURL: String = "searx.org"
    @AppStorage(Keys.autocompleteProvider) var autocompleteProvider: AutocompleteProvider = .duckDuckGo
    @AppStorage(Keys.autocompleteAPIKey) var autocompleteAPIKey: String = ""
    @AppStorage(Keys.javascriptEnabled)  var javascriptEnabled: Bool = true
    @AppStorage(Keys.contentBlockerEnabled) var contentBlockerEnabled: Bool = true
    @AppStorage(Keys.autoplayEnabled)    var autoplayEnabled: Bool = false
    @AppStorage(Keys.homepageURL)        var homepageURL: String = ""
    @AppStorage(Keys.appearanceMode)     var appearanceMode: AppearanceMode = .system
    @AppStorage(Keys.layoutStyle)        var layoutStyle: TabLayoutStyle = .standard

    // MARK: - Helpers

    func searchQueryURL(for query: String) -> URL? {
        if searchEngine == .searxng {
            return searchEngine.searchURL(for: query, customBaseURL: searxngURL)
        }
        return searchEngine.searchURL(for: query)
    }
}
