import Foundation
import WebKit
import Combine
import SwiftUI

// MARK: - Favicon Cache (module-level)

@MainActor
private let faviconCache = NSCache<NSString, NSImage>()

// MARK: - BrowserTab

@MainActor
final class BrowserTab: NSObject, ObservableObject, Identifiable {

    // MARK: Public state (observed by SwiftUI)

    @Published var title: String = "New Tab"
    @Published var displayURL: String = ""
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0.0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isSecure: Bool = false
    @Published var blockedItemsCount: Int = 0
    @Published var favicon: NSImage? = nil
    @Published var themeColor: Color = .clear

    // MARK: Identity

    let id: UUID = UUID()

    // MARK: The actual web view

    let webView: WKWebView

    // MARK: Find in page

    @Published var isFindBarVisible: Bool = false
    @Published var findQuery: String = ""
    @Published var findMatchCount: Int = 0

    // MARK: Zoom

    @Published var magnification: CGFloat = 1.0

    // MARK: Settings

    private let settings: BrowserSettings

    // MARK: Combine cancellables

    private nonisolated(unsafe) var cancellables = Set<AnyCancellable>()

    // MARK: Init

    init(configuration: WKWebViewConfiguration, settings: BrowserSettings) {
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.settings = settings
        super.init()

        let safariUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        webView.customUserAgent = safariUA

        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        setupObservers()
    }

    // MARK: - Deinit

    deinit {
        cancellables.removeAll()
    }

    // MARK: - Observers

    private func setupObservers() {
        // URL publisher
        webView.publisher(for: \.url)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                guard let self else { return }
                self.displayURL = url?.absoluteString ?? ""
                self.isSecure = url?.scheme?.lowercased() == "https"
            }
            .store(in: &cancellables)

        // Title publisher
        webView.publisher(for: \.title)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] title in
                guard let self else { return }
                let t = title ?? ""
                self.title = t.isEmpty ? "New Tab" : t
            }
            .store(in: &cancellables)

        // isLoading publisher
        webView.publisher(for: \.isLoading)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                self?.isLoading = loading
            }
            .store(in: &cancellables)

        // estimatedProgress publisher
        webView.publisher(for: \.estimatedProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.estimatedProgress = progress
            }
            .store(in: &cancellables)

        // canGoBack publisher
        webView.publisher(for: \.canGoBack)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] canGoBack in
                self?.canGoBack = canGoBack
            }
            .store(in: &cancellables)

        // canGoForward publisher
        webView.publisher(for: \.canGoForward)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] canGoForward in
                self?.canGoForward = canGoForward
            }
            .store(in: &cancellables)

        webView.publisher(for: \.underPageBackgroundColor)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bgColor in
                guard let self else { return }
                if let color = bgColor {
                    self.themeColor = Color(nsColor: color)
                } else {
                    self.themeColor = .clear
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Navigation

    func navigate(to input: String, grabFocus: Bool = false) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let url = resolveURL(from: trimmed) {
            displayURL = url.absoluteString
            webView.load(URLRequest(url: url))

            if grabFocus {
                Task { @MainActor in
                    guard self.webView.window != nil else { return }
                    self.webView.window?.makeFirstResponder(self.webView)
                }
            }
        }
    }

    private func resolveURL(from input: String) -> URL? {
        // Already a valid URL with scheme
        if let url = URL(string: input), let scheme = url.scheme, !scheme.isEmpty {
            if scheme == "about" || url.host != nil {
                return url
            }
        }

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // localhost (with optional port and path)
        if trimmed == "localhost" || trimmed.hasPrefix("localhost:") || trimmed.hasPrefix("localhost/") {
            return URL(string: "http://\(trimmed)")
        }

        // IPv4 address (e.g. 192.168.1.1, 10.0.0.1:8080)
        let ipPattern = #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?(/.*)?$"#
        if trimmed.range(of: ipPattern, options: .regularExpression) != nil {
            return URL(string: "http://\(trimmed)")
        }

        // Looks like a domain: contains a dot, no spaces, and last segment is >= 2 chars
        if !trimmed.contains(" ") && trimmed.contains(".") {
            let components = trimmed.split(separator: ".")
            if let last = components.last, last.count >= 2,
               !last.allSatisfy({ $0.isNumber }) {
                let candidate = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
                    ? trimmed
                    : "https://\(trimmed)"
                if let url = URL(string: candidate), url.host != nil {
                    return url
                }
            }
        }

        // Fall through to selected search engine
        return settings.searchQueryURL(for: input)
    }

    func goBack()    { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload()    { webView.reload() }
    func stopLoad()  { webView.stopLoading() }

    func incrementBlockedCount() {
        blockedItemsCount += 1
    }

    // MARK: - Zoom

    func zoomIn() {
        let next = min(magnification + 0.1, 3.0)
        webView.setMagnification(next, centeredAt: .zero)
        magnification = next
    }

    func zoomOut() {
        let next = max(magnification - 0.1, 0.5)
        webView.setMagnification(next, centeredAt: .zero)
        magnification = next
    }

    func resetZoom() {
        webView.setMagnification(1.0, centeredAt: .zero)
        magnification = 1.0
    }

    // MARK: - Print

    func printPage() {
        let info = NSPrintInfo.shared
        let op = webView.printOperation(with: info)
        if let window = webView.window {
            op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            op.run()
        }
    }

    // MARK: - Find in Page

    func findInPage(_ query: String, forward: Bool = true) {
        findQuery = query
        guard !query.isEmpty else {
            webView.evaluateJavaScript("window.getSelection().removeAllRanges()") { _, _ in }
            findMatchCount = 0
            return
        }
        let config = WKFindConfiguration()
        config.backwards = !forward
        config.wraps = true
        config.caseSensitive = false
        webView.find(query, configuration: config) { [weak self] result in
            self?.findMatchCount = result.matchFound ? 1 : 0
        }
    }

    func dismissFindBar() {
        isFindBarVisible = false
        findQuery = ""
        findMatchCount = 0
        webView.evaluateJavaScript("window.getSelection().removeAllRanges()") { _, _ in }
    }
}

// MARK: - WKNavigationDelegate

extension BrowserTab: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.blockedItemsCount = 0
        self.favicon = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadFavicon()
        // Record in history (ignore blank/new-tab pages)
        let urlStr = webView.url?.absoluteString ?? ""
        if !urlStr.isEmpty && urlStr != "about:blank" {
            HistoryStore.shared.add(title: webView.title ?? "", url: urlStr)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // ignore cancellations (e.g. fast user navigation)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @MainActor @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // Autoplay gate: if autoplay is disabled, require user gesture for audio/video playback
        if !settings.autoplayEnabled {
            let mediaExtensions = ["mp4", "mp3", "webm", "m4a", "wav"]
            let isMedia = mediaExtensions.contains(navigationAction.request.url?.pathExtension.lowercased() ?? "")
            if isMedia && !navigationAction.shouldPerformDownload {
                // For media, we could block autoplay by checking the navigation type
                // A more precise approach would examine the media types, but this is a reasonable heuristic.
                // Note: WKWebView autoplay policy is also controlled by mediaTypesRequiringUserActionForPlayback
                // which we set in BrowserState.configuration already.
            }
        }
        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @MainActor @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        decisionHandler(.allow)
    }

    // MARK: Favicon helper (cached + timeout)

    private func loadFavicon() {
        guard let host = webView.url?.host else { return }
        let cacheKeyString = "favicon:\(host)"

        if let cached = faviconCache.object(forKey: cacheKeyString as NSString) {
            self.favicon = cached
            return
        }

        let faviconURL = URL(string: "https://\(host)/favicon.ico")!

        FaviconLoader.shared.load(url: faviconURL, cacheKey: cacheKeyString) { [weak self] image in
            self?.favicon = image
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Color extension

extension Color {
    static let prismPurple = Color(red: 139/255, green: 92/255, blue: 246/255)
    static let prismBlue   = Color(red: 59/255,  green: 130/255, blue: 246/255)
    static let prismTeal   = Color(red: 20/255,  green: 184/255, blue: 166/255)
}

// MARK: - FaviconLoader (module-level singleton)

@MainActor
private final class FaviconLoader {
    static let shared = FaviconLoader()

    private let session: URLSession
    private let inFlightQueue = DispatchQueue(label: "com.prism.favicon.inFlight")
    private nonisolated(unsafe) var inFlight: [URL: [(NSImage?) -> Void]] = [:]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        self.session = URLSession(configuration: config)
    }

    func load(url: URL, cacheKey: String, completion: @escaping (NSImage?) -> Void) {
        Task { @MainActor in
            let cached = faviconCache.object(forKey: cacheKey as NSString)
            if let cached {
                completion(cached)
                return
            }

            inFlightQueue.sync {
                if inFlight[url] != nil {
                    inFlight[url]!.append(completion)
                    return
                }
                inFlight[url] = [completion]
            }

            let task = session.dataTask(with: url) { [weak self] data, _, error in
                let image: NSImage?
                if let data = data, let img = NSImage(data: data), error == nil {
                    Task { @MainActor in
                        faviconCache.setObject(img, forKey: cacheKey as NSString)
                    }
                    image = img
                } else {
                    image = nil
                }
                self?.inFlightQueue.sync {
                    let callbacks = self?.inFlight.removeValue(forKey: url) ?? []
                    DispatchQueue.main.async {
                        callbacks.forEach { $0(image) }
                    }
                }
            }
            task.resume()
        }
    }
}

// MARK: - WKUIDelegate

extension BrowserTab: WKUIDelegate {

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // target=_blank — open in a new Prism tab
        if let url = navigationAction.request.url {
            NotificationCenter.default.post(
                name: .openNewTab,
                object: nil,
                userInfo: ["url": url]
            )
        }
        return nil
    }

    func webViewDidClose(_ webView: WKWebView) {}

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @MainActor @escaping @Sendable () -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @MainActor @escaping @Sendable (Bool) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let openNewTab = Notification.Name("com.prism.browser.openNewTab")
}
