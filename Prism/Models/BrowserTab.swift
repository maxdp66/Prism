import Foundation
import WebKit
import Combine

// MARK: - Favicon Cache (module-level)

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

    // MARK: KVO tokens

    private var kvoTokens: [NSKeyValueObservation] = []

    // MARK: Init

    init(configuration: WKWebViewConfiguration, settings: BrowserSettings) {
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.settings = settings
        super.init()

        let safariUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        webView.customUserAgent = safariUA

        let source = "(function() { document.body.style.paddingTop = '60px'; })();"
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(script)

        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        setupKVO()
    }

    deinit {
        kvoTokens.forEach { $0.invalidate() }
    }

    // MARK: - KVO Setup

    private func setupKVO() {
        let options: NSKeyValueObservingOptions = [.new]

        kvoTokens.append(webView.observe(\.url, options: options) { [weak self] wv, _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let url = wv.url
                self.displayURL = url?.absoluteString ?? ""
                self.isSecure = url?.scheme?.lowercased() == "https"
            }
        })

        kvoTokens.append(webView.observe(\.title, options: options) { [weak self] wv, _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let t = wv.title ?? ""
                self.title = t.isEmpty ? "New Tab" : t
            }
        })

        kvoTokens.append(webView.observe(\.isLoading, options: options) { [weak self] wv, _ in
            DispatchQueue.main.async { self?.isLoading = wv.isLoading }
        })

        kvoTokens.append(webView.observe(\.estimatedProgress, options: options) { [weak self] wv, _ in
            DispatchQueue.main.async { self?.estimatedProgress = wv.estimatedProgress }
        })

        kvoTokens.append(webView.observe(\.canGoBack, options: options) { [weak self] wv, _ in
            DispatchQueue.main.async { self?.canGoBack = wv.canGoBack }
        })

        kvoTokens.append(webView.observe(\.canGoForward, options: options) { [weak self] wv, _ in
            DispatchQueue.main.async { self?.canGoForward = wv.canGoForward }
        })
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
                    try? await Task.sleep(nanoseconds: 50_000_000)
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
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
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
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
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

// MARK: - FaviconLoader (module-level singleton)

private final class FaviconLoader {
    static let shared = FaviconLoader()

    private let session: URLSession
    private var inFlight: [URL: [(NSImage?) -> Void]] = [:]
    private let lock = NSLock()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        self.session = URLSession(configuration: config)
    }

    func load(url: URL, cacheKey: String, completion: @escaping (NSImage?) -> Void) {
        if let cached = faviconCache.object(forKey: cacheKey as NSString) {
            completion(cached)
            return
        }

        lock.lock()
        if inFlight[url] != nil {
            // Another request already in flight — piggyback on it
            inFlight[url]!.append(completion)
            lock.unlock()
            return
        }
        inFlight[url] = [completion]
        lock.unlock()

        let task = session.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            let image: NSImage?
            if let data = data, let img = NSImage(data: data), error == nil {
                faviconCache.setObject(img, forKey: cacheKey as NSString)
                image = img
            } else {
                image = nil
            }
            self.lock.lock()
            let callbacks = self.inFlight.removeValue(forKey: url) ?? []
            self.lock.unlock()
            DispatchQueue.main.async {
                callbacks.forEach { $0(image) }
            }
        }
        task.resume()
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
        completionHandler: @escaping () -> Void
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
        completionHandler: @escaping (Bool) -> Void
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
