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

    // MARK: Derived

    var activeTab: BrowserTab? {
        guard let id = activeTabId else { return nil }
        return tabs.first { $0.id == id }
    }

    // MARK: Shared WebKit configuration

    private(set) var sharedConfiguration: WKWebViewConfiguration = WKWebViewConfiguration()

    // MARK: Notification token

    private var newTabToken: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    // MARK: Settings

    private let settings = BrowserSettings.shared

    // MARK: Init

    init() {
        setupConfiguration()
        listenForNewTabNotifications()
        observeSettings()

        // Always start with at least one blank tab
        addNewTab(url: nil)
    }

    // MARK: - Configuration

    private func setupConfiguration() {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = settings.autoplayEnabled ? [] : [.all]

        // Preferences – controlled by settings
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = settings.javascriptEnabled
        config.defaultWebpagePreferences = prefs

        self.sharedConfiguration = config

        // Load content blocker async — only if enabled
        if settings.contentBlockerEnabled {
            Task {
                do {
                    let ruleList = try await ContentBlocker.shared.loadRuleList()
                    config.userContentController.add(ruleList)
                    isContentBlockerReady = true
                } catch {
                    print("[Prism] ContentBlocker failed: \(error)")
                    isContentBlockerReady = true   // continue anyway
                }
            }
        } else {
            isContentBlockerReady = true  // not needed, but "ready"
        }
    }

    /// Rebuild WKWebViewConfiguration when settings change.
    private func rebuildConfiguration() {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = settings.autoplayEnabled ? [] : [.all]

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = settings.javascriptEnabled
        config.defaultWebpagePreferences = prefs

        // Content blocker only if enabled
        if settings.contentBlockerEnabled {
            // Fire-and-forget: rules are async; if they fail we still continue
            Task {
                do {
                    let ruleList = try await ContentBlocker.shared.loadRuleList()
                    config.userContentController.add(ruleList)
                } catch {
                    print("[Prism] ContentBlocker reload failed: \(error)")
                }
            }
        }

        sharedConfiguration = config
    }

    /// Subscribe to settings changes and rebuild shared configuration on the fly.
    private func observeSettings() {
        // @AppStorage-backed properties on ObservableObject automatically send objectWillChange
        // when their values change. Subscribe to the root publisher and trigger a rebuild.
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
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

    func closeTab(_ tab: BrowserTab) {
        guard tabs.count > 1 else {
            // Last tab — just navigate home
            activeTab?.navigate(to: "")
            return
        }

        let index = tabs.firstIndex(where: { $0.id == tab.id }) ?? 0

        tabs.removeAll { $0.id == tab.id }

        // Activate the nearest remaining tab
        if tab.id == activeTabId {
            let newIndex = max(0, min(index, tabs.count - 1))
            activateTab(tabs[newIndex])
        }
    }

    func activateTab(_ tab: BrowserTab) {
        activeTabId = tab.id
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
        withAnimation(.easeInOut(duration: 0.2)) {
            sidebarVisible.toggle()
        }
    }

    deinit {
        if let token = newTabToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
