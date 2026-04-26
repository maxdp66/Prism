import SwiftUI

// MARK: - ActiveTabView

/// A view that displays the active tab's content, switching between
/// NewTabView (welcome screen) and WebContentView based on the tab's state.
///
/// This view takes `BrowserTab` as `@ObservedObject` to ensure SwiftUI
/// properly tracks changes to the tab's `displayURL` and `isLoading` properties.
/// This fixes the bug where quick access links and search bar navigation
/// didn't trigger a view update in ContentView.
struct ActiveTabView: View {

    @ObservedObject var tab: BrowserTab
    @EnvironmentObject private var settings: BrowserSettings

    let clearSuggestions: () -> Void

    var body: some View {
        if tab.displayURL.isEmpty && !tab.isLoading {
            // Show welcome screen (new tab page)
            NewTabView(clearSuggestions: clearSuggestions)
                .environmentObject(settings)
                .id(tab.id)
        } else {
            // Show web content
            WebContentView(webView: tab.webView)
                .id(tab.id)
        }
    }
}