import Foundation
import SwiftUI
import WebKit
import Combine

// MARK: - BrowserState

@MainActor
final class BrowserState: ObservableObject {

    // MARK: Published

    @Published var tabs: [BrowserTab] = []
    @Published var activeTabId: UUID?
    @Published var sidebarVisible: Bool = true
    @Published var isContentBlockerReady: Bool = false
    @Published var contentBlockerError: String? = nil
    @Published var settingsChangedNeedsReload: Bool = false

    private let sidebarVisibleKey = "com.prism.sidebarVisible"

    // MARK: Derived

    var activeTab: BrowserTab? {
        guard let id = activeTabId else { return nil }
        return tabs.first { $0.id == id }
    }

    // MARK: Shared WebKit configuration

    private(set) var sharedConfiguration: WKWebViewConfiguration = WKWebViewConfiguration()

    // MARK: Notification token

    private nonisolated(unsafe) var newTabToken: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    // MARK: Settings

    private let settings = BrowserSettings.shared

    // Tracks the last values used when building the WKWebViewConfiguration so
    // we only rebuild when something WebKit actually cares about changes.
    private var lastConfigJS: Bool = true
    private var lastConfigAutoplay: Bool = false
    private var lastConfigBlocker: Bool = true

    // MARK: Init

    init() {
        sidebarVisible = UserDefaults.standard.object(forKey: sidebarVisibleKey) as? Bool ?? true

        lastConfigJS = settings.javascriptEnabled
        lastConfigAutoplay = settings.autoplayEnabled
        lastConfigBlocker = settings.contentBlockerEnabled

        setupConfiguration()
        listenForNewTabNotifications()
        observeSettings()
        // First tab is opened inside setupConfiguration() after the content blocker is ready,
        // so we do NOT call addNewTab here directly.
    }

    // MARK: - Configuration

    private func setupConfiguration() {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = settings.autoplayEnabled ? [] : [.all]

        config.applicationNameForUserAgent = "Prism/1.0"

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = settings.javascriptEnabled
        config.defaultWebpagePreferences = prefs

        self.sharedConfiguration = config

        // Load content blocker async, then open the first tab so it benefits from blocking.
        if settings.contentBlockerEnabled {
            Task {
                do {
                    let ruleList = try await ContentBlocker.shared.loadRuleList()
                    config.userContentController.add(ruleList)
                    isContentBlockerReady = true
                } catch {
                    print("[Prism] ContentBlocker failed: \(error)")
                    contentBlockerError = "Content blocker failed to load."
                    isContentBlockerReady = true
                }
                if tabs.isEmpty { addNewTab(url: nil) }
            }
        } else {
            isContentBlockerReady = true
            if tabs.isEmpty { addNewTab(url: nil) }
        }
    }

    /// Rebuild WKWebViewConfiguration only when a WebKit-relevant setting changes.
    /// Existing WKWebViews cannot have their configuration changed after creation —
    /// the user is prompted to reload open tabs to apply changes.
    private func rebuildConfiguration() {
        let jsChanged = settings.javascriptEnabled != lastConfigJS
        let autoplayChanged = settings.autoplayEnabled != lastConfigAutoplay
        let blockerChanged = settings.contentBlockerEnabled != lastConfigBlocker

        guard jsChanged || autoplayChanged || blockerChanged else { return }

        lastConfigJS = settings.javascriptEnabled
        lastConfigAutoplay = settings.autoplayEnabled
        lastConfigBlocker = settings.contentBlockerEnabled

        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = settings.autoplayEnabled ? [] : [.all]

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = settings.javascriptEnabled
        config.defaultWebpagePreferences = prefs

        if settings.contentBlockerEnabled {
            Task {
                do {
                    let ruleList = try await ContentBlocker.shared.loadRuleList()
                    config.userContentController.add(ruleList)
                } catch {
                    print("[Prism] ContentBlocker reload failed: \(error)")
                }
                sharedConfiguration = config
                if !tabs.isEmpty { settingsChangedNeedsReload = true }
            }
        } else {
            sharedConfiguration = config
            if !tabs.isEmpty { settingsChangedNeedsReload = true }
        }
    }

    /// Subscribe to settings changes and rebuild shared configuration on the fly.
    private func observeSettings() {
        settings.objectWillChange
            .sink { [weak self] _ in
                self?.rebuildConfiguration()
            }
            .store(in: &cancellables)
    }

    // MARK: - Tab Management

    func addNewTab(url: URL? = nil) {
        let tab = BrowserTab(configuration: sharedConfiguration, settings: settings)
        tabs.append(tab)
        activateTab(tab)

        if let url {
            tab.webView.load(URLRequest(url: url))
        }
    }

    private var closedTabURLs: [URL] = []

    func closeTab(_ tab: BrowserTab) {
        guard tabs.count > 1 else {
            activeTab?.navigate(to: "")
            return
        }

        // Save URL for restore (max 10)
        if let url = tab.webView.url {
            closedTabURLs.append(url)
            if closedTabURLs.count > 10 { closedTabURLs.removeFirst() }
        }

        let index = tabs.firstIndex(where: { $0.id == tab.id }) ?? 0
        tabs.removeAll { $0.id == tab.id }

        if tab.id == activeTabId {
            let newIndex = max(0, min(index, tabs.count - 1))
            activateTab(tabs[newIndex])
        }
    }

    func restoreLastClosedTab() {
        guard let url = closedTabURLs.popLast() else { return }
        addNewTab(url: url)
    }

    var canRestoreClosedTab: Bool { !closedTabURLs.isEmpty }

    func activateTab(_ tab: BrowserTab) {
        activeTabId = tab.id
    }

    func reloadAllTabs() {
        tabs.forEach { $0.reload() }
        settingsChangedNeedsReload = false
    }

    // MARK: - target=_blank handler

    private func listenForNewTabNotifications() {
        newTabToken = NotificationCenter.default.addObserver(
            forName: .openNewTab,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let url = notification.userInfo?["url"] as? URL
            Task { @MainActor in
                self.addNewTab(url: url)
            }
        }
    }

    // MARK: - Sidebar

    func toggleSidebar() {
        sidebarVisible.toggle()
        UserDefaults.standard.set(sidebarVisible, forKey: sidebarVisibleKey)
    }

    deinit {
        if let token = newTabToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
