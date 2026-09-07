@preconcurrency import SwiftUI
import AppKit

@main
struct PrismApp: App {

    @StateObject private var browserState = BrowserState()
    @StateObject private var bookmarkStore = BookmarkStore.shared
    @StateObject private var settings = BrowserSettings.shared
    @StateObject private var quickLinkStore = QuickLinkStore.shared

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(browserState)
                .environmentObject(bookmarkStore)
                .environmentObject(settings)
                .environmentObject(quickLinkStore)
                .onAppear {
                    if let window = NSApp.windows.first {
                        AppDelegate.configureWindow(window)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            // MARK: Tab management
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    browserState.addNewTab(url: nil)
                }
                .keyboardShortcut("t", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("Close Tab") {
                    if let tab = browserState.activeTab {
                        browserState.closeTab(tab)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)

                Button("Reopen Last Closed Tab") {
                    browserState.restoreLastClosedTab()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(!browserState.canRestoreClosedTab)
            }

            // MARK: Sidebar
            CommandGroup(replacing: .sidebar) {
                Button("Toggle Bookmarks Sidebar") {
                    browserState.toggleSidebar()
                }
                .keyboardShortcut("b", modifiers: .command)
            }

            // MARK: Page actions
            CommandMenu("Page") {
                Button("Find in Page...") {
                    browserState.activeTab?.isFindBarVisible = true
                }
                .keyboardShortcut("f", modifiers: .command)

                Divider()

                Button("Zoom In") {
                    browserState.activeTab?.zoomIn()
                }
                .keyboardShortcut("=", modifiers: .command)

                Button("Zoom Out") {
                    browserState.activeTab?.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    browserState.activeTab?.resetZoom()
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Button("Print...") {
                    browserState.activeTab?.printPage()
                }
                .keyboardShortcut("p", modifiers: .command)

                Divider()

                Button("Reload Page") {
                    browserState.activeTab?.reload()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Reload All Tabs") {
                    browserState.reloadAllTabs()
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(quickLinkStore)
                .preferredColorScheme(settings.appearanceMode.colorScheme)
                .animation(.easeInOut(duration: 0.3), value: settings.appearanceMode)
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private nonisolated(unsafe) var newWindowNotificationToken: NSObjectProtocol?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.windows.forEach { window in
            Self.configureWindow(window)
        }
        
        // Listen for requests to create new windows with extracted tabs
        newWindowNotificationToken = NotificationCenter.default.addObserver(
            forName: .openNewWindowWithTab,
            object: nil,
            queue: .main
        ) { notification in
            guard let tab = notification.userInfo?["tab"] as? BrowserTab else { return }
            Task { @MainActor in
                self.createWindow(with: tab)
            }
        }
    }

    func application(_ application: NSApplication, didCreateWindow window: NSWindow) {
        Self.configureWindow(window)
    }
    
    deinit {
        if let token = newWindowNotificationToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    /// Create a new window with an extracted tab
    private func createWindow(with tab: BrowserTab) {
        // Create a new BrowserState for this window with just the extracted tab
        let newBrowserState = BrowserState()
        newBrowserState.tabs = [tab]
        newBrowserState.activeTabId = tab.id
        
        // Create the content view
        let contentView = ContentView()
            .environmentObject(newBrowserState)
            .environmentObject(BookmarkStore.shared)
            .environmentObject(BrowserSettings.shared)
            .environmentObject(QuickLinkStore.shared)
        
        // Create a new window
        let newWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Set up the window
        newWindow.contentView = NSHostingView(rootView: contentView)
        newWindow.title = tab.title
        newWindow.makeKeyAndOrderFront(nil)
        
        // Configure the window appearance
        Self.configureWindow(newWindow)
    }
}

// MARK: - Window Configuration Helper

extension AppDelegate {
    static func configureWindow(_ window: NSWindow) {
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        // Disable all system-initiated window movement; dragging is handled
        // manually via setFrameOrigin() in the leading spacer gesture.
        window.isMovable = false
        window.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
        window.toolbar = nil
        window.appearance = NSAppearance(named: .vibrantDark)
    }
}
