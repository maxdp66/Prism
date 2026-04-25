import Foundation
import SwiftUI

// MARK: - Search Engine

enum SearchEngine: String, CaseIterable, Identifiable, Codable, Sendable {
    case duckDuckGo = "DuckDuckGo"
    case google = "Google"
    case bing = "Bing"
    case brave = "Brave"
    case ecosia = "Ecosia"

    var baseURL: String {
        switch self {
        case .duckDuckGo: "https://duckduckgo.com/"
        case .google:     "https://www.google.com/"
        case .bing:       "https://www.bing.com/"
        case .brave:      "https://search.brave.com/"
        case .ecosia:     "https://www.ecosia.org/"
        }
    }

    var queryParameter: String {
        switch self {
        case .duckDuckGo: "q"
        case .google:     "q"
        case .bing:       "q"
        case .brave:      "q"
        case .ecosia:     "q"
        }
    }

    func searchURL(for query: String) -> URL? {
        var comps = URLComponents(string: baseURL)!
        comps.queryItems = [URLQueryItem(name: queryParameter, value: query)]
        return comps.url
    }
}

// MARK: - BrowserSettings

@MainActor
final class BrowserSettings: ObservableObject {

    static let shared = BrowserSettings()

    // MARK: - AppStorage keys

    private enum Keys {
        static let searchEngine       = "searchEngine"
        static let javascriptEnabled  = "javascriptEnabled"
        static let contentBlockerEnabled = "contentBlockerEnabled"
        static let autoplayEnabled    = "autoplayEnabled"
        static let homepageURL        = "homepageURL"
    }

    // MARK: - Published properties (backed by @AppStorage)

    @AppStorage(Keys.searchEngine)       private var storedSearchEngine: String = SearchEngine.duckDuckGo.rawValue
    @AppStorage(Keys.javascriptEnabled)  private var storedJavascriptEnabled: Bool = true
    @AppStorage(Keys.contentBlockerEnabled) private var storedContentBlockerEnabled: Bool = true
    @AppStorage(Keys.autoplayEnabled)    private var storedAutoplayEnabled: Bool = false
    @AppStorage(Keys.homepageURL)        private var storedHomepageURL: String = ""

    // MARK: - Public bindings

    @Published var searchEngine: SearchEngine = .duckDuckGo {
        didSet { storedSearchEngine = searchEngine.rawValue }
    }
    @Published var javascriptEnabled: Bool = true {
        didSet { storedJavascriptEnabled = javascriptEnabled }
    }
    @Published var contentBlockerEnabled: Bool = true {
        didSet { storedContentBlockerEnabled = contentBlockerEnabled }
    }
    @Published var autoplayEnabled: Bool = false {
        didSet { storedAutoplayEnabled = autoplayEnabled }
    }
    @Published var homepageURL: String = "" {
        didSet { storedHomepageURL = homepageURL }
    }

    // MARK: - Init

    private init() {
        // Sync @AppStorage values into @Published properties at startup
        _searchEngine          = AppStorage(wrappedValue: SearchEngine(rawValue: storedSearchEngine) ?? .duckDuckGo,   Keys.searchEngine)
        _javascriptEnabled     = AppStorage(wrappedValue: storedJavascriptEnabled,                                          Keys.javascriptEnabled)
        _contentBlockerEnabled = AppStorage(wrappedValue: storedContentBlockerEnabled,                                    Keys.contentBlockerEnabled)
        _autoplayEnabled       = AppStorage(wrappedValue: storedAutoplayEnabled,                                          Keys.autoplayEnabled)
        _homepageURL           = AppStorage(wrappedValue: storedHomepageURL,                                              Keys.homepageURL)
    }

    // MARK: - Helpers

    func searchQueryURL(for query: String) -> URL? {
        searchEngine.searchURL(for: query)
    }
}
