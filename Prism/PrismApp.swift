import SwiftUI
import AppKit

@main
struct PrismApp: App {

    @StateObject private var browserState = BrowserState()
    @StateObject private var bookmarkStore = BookmarkStore.shared
    @StateObject private var settings = BrowserSettings.shared

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(browserState)
                .environmentObject(bookmarkStore)
                .environmentObject(settings)
                .onAppear {
                    NSApp.windows.forEach { window in
                        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
                        window.titlebarAppearsTransparent = true
                        window.titleVisibility = .hidden
                        window.titlebarSeparatorStyle = .none
                        window.isMovableByWindowBackground = true
                        window.standardWindowButton(.closeButton)?.isHidden = false
                        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
                        window.standardWindowButton(.zoomButton)?.isHidden = false
                        window.toolbar = nil
                        window.appearance = NSAppearance(named: .vibrantDark)
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
                .preferredColorScheme(settings.appearanceMode.colorScheme)
                .animation(.easeInOut(duration: 0.3), value: settings.appearanceMode)
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.windows.forEach { window in
            configureWindow(window)
        }
    }

    func application(_ application: NSApplication, didCreateWindow window: NSWindow) {
        configureWindow(window)
    }

    private func configureWindow(_ window: NSWindow) {
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
        window.toolbar = nil
        window.appearance = NSAppearance(named: .vibrantDark)
    }
}
