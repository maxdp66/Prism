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

    // MARK: Init

    init() {
        setupConfiguration()
        listenForNewTabNotifications()

        // Always start with at least one blank tab
        addNewTab(url: nil)
    }

    // MARK: - Configuration

    private func setupConfiguration() {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Preferences
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        self.sharedConfiguration = config

        // Load content blocker async
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
    }

    // MARK: - Tab Management

    func addNewTab(url: URL? = nil) {
        let tab = BrowserTab(configuration: sharedConfiguration)
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
