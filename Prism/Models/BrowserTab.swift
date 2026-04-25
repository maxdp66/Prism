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

    // MARK: Settings

    private let settings: BrowserSettings

    // MARK: KVO tokens

    private var kvoTokens: [NSKeyValueObservation] = []

    // MARK: Init

    init(configuration: WKWebViewConfiguration, settings: BrowserSettings) {
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.settings = settings
        super.init()
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
            Task { @MainActor in
                guard let self else { return }
                let url = wv.url
                self.displayURL = url?.absoluteString ?? ""
                self.isSecure = url?.scheme?.lowercased() == "https"
            }
        })

        kvoTokens.append(webView.observe(\.title, options: options) { [weak self] wv, _ in
            Task { @MainActor in
                guard let self else { return }
                let t = wv.title ?? ""
                self.title = t.isEmpty ? "New Tab" : t
            }
        })

        kvoTokens.append(webView.observe(\.isLoading, options: options) { [weak self] wv, _ in
            Task { @MainActor in
                self?.isLoading = wv.isLoading
            }
        })

        kvoTokens.append(webView.observe(\.estimatedProgress, options: options) { [weak self] wv, _ in
            Task { @MainActor in
                self?.estimatedProgress = wv.estimatedProgress
            }
        })

        kvoTokens.append(webView.observe(\.canGoBack, options: options) { [weak self] wv, _ in
            Task { @MainActor in
                self?.canGoBack = wv.canGoBack
            }
        })

        kvoTokens.append(webView.observe(\.canGoForward, options: options) { [weak self] wv, _ in
            Task { @MainActor in
                self?.canGoForward = wv.canGoForward
            }
        })
    }

    // MARK: - Navigation

    func navigate(to input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let url = resolveURL(from: trimmed) {
            webView.load(URLRequest(url: url))
        }
    }

    private func resolveURL(from input: String) -> URL? {
        // Already a valid URL with scheme
        if let url = URL(string: input), let scheme = url.scheme, !scheme.isEmpty {
            if scheme == "about" || url.host != nil {
                return url
            }
        }

        // Looks like a domain (contains a dot, no spaces, and has a plausible TLD)
        let domainTLDs = [".com", ".org", ".net", ".edu", ".gov", ".io", ".co", ".ai", ".app", ".dev"]
        if !input.contains(" ") && domainTLDs.contains(where: { input.lowercased().contains($0) }) {
            let candidate = input.hasPrefix("http://") || input.hasPrefix("https://") ? input : "https://\(input)"
            if let url = URL(string: candidate), url.host != nil {
                return url
            }
        }

        // Fall through to selected search engine
        let searchURL = settings.searchQueryURL(for: input)
        return searchURL
    }

    func goBack()    { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload()    { webView.reload() }
    func stopLoad()  { webView.stopLoading() }

    func incrementBlockedCount() {
        DispatchQueue.main.async { self.blockedItemsCount += 1 }
    }
}

// MARK: - WKNavigationDelegate

extension BrowserTab: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        DispatchQueue.main.async {
            self.blockedItemsCount = 0
            self.favicon = nil
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadFavicon()
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
        let cacheKey = "favicon:\(host)" as NSString

        if let cached = faviconCache.object(forKey: cacheKey) {
            self.favicon = cached
            return
        }

        let faviconURL = URL(string: "https://\(host)/favicon.ico")!

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: faviconURL) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let image = NSImage(data: data),
                  error == nil else { return }
            faviconCache.setObject(image, forKey: cacheKey)
            Task { @MainActor in
                self.favicon = image
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
