import Foundation
import SwiftUI

// MARK: - Search Engine

enum SearchEngine: String, CaseIterable, Identifiable, Codable, Sendable {
    case duckDuckGo = "DuckDuckGo"
    case google = "Google"
    case bing = "Bing"
    case brave = "Brave"
    case ecosia = "Ecosia"

    var id: String { rawValue }

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
        case .duckDuckGo, .google, .bing, .brave, .ecosia: "q"
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

    // MARK: - Published properties backed by @AppStorage

    @AppStorage(Keys.searchEngine)       var searchEngine: SearchEngine = .duckDuckGo
    @AppStorage(Keys.javascriptEnabled)  var javascriptEnabled: Bool = true
    @AppStorage(Keys.contentBlockerEnabled) var contentBlockerEnabled: Bool = true
    @AppStorage(Keys.autoplayEnabled)    var autoplayEnabled: Bool = false
    @AppStorage(Keys.homepageURL)        var homepageURL: String = ""

    // MARK: - Helpers

    func searchQueryURL(for query: String) -> URL? {
        searchEngine.searchURL(for: query)
    }
}
