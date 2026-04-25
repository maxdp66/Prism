import SwiftUI
import AppKit

// MARK: - App Entry Point

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
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
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
            }

            CommandGroup(replacing: .sidebar) {
                Button("Toggle Bookmarks Sidebar") {
                    browserState.toggleSidebar()
                }
                .keyboardShortcut("b", modifiers: .command)
            }
        }
        .settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Nothing needed yet
    }
}
