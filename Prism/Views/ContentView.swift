import SwiftUI
import AppKit

// MARK: - ContentView

struct ContentView: View {

    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject var bookmarkStore: BookmarkStore
    @EnvironmentObject private var settings: BrowserSettings

    @State private var suggestions: [Suggestion] = []
    @State private var barFrame: CGRect = .zero
    @State private var suggestionsHeight: CGFloat = 0
    @State private var selectedSuggestionIndex: Int? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                TabBarView()
                    .environmentObject(browserState)

                BrowserToolbar(
                    barFrame: $barFrame,
                    suggestions: $suggestions,
                    suggestionsHeight: $suggestionsHeight,
                    selectedSuggestionIndex: $selectedSuggestionIndex
                )
                .environmentObject(browserState)
                .environmentObject(bookmarkStore)
                .environmentObject(settings)

                Divider()
                    .opacity(0.3)

                HSplitView {
                    if browserState.sidebarVisible {
                        SidebarView()
                            .environmentObject(browserState)
                            .environmentObject(bookmarkStore)
                            .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)
                            .transition(.move(edge: .leading))
                    }

                    ZStack {
                        if let tab = browserState.activeTab {
                            if tab.displayURL.isEmpty && !tab.isLoading {
                                NewTabView(clearSuggestions: { suggestions = [] })
                                    .environmentObject(browserState)
                                    .environmentObject(settings)
                            } else {
                                WebContentView(webView: tab.webView)
                            }
                        } else {
                            NewTabView(clearSuggestions: { suggestions = [] })
                                .environmentObject(browserState)
                                .environmentObject(settings)
                        }

                        if !suggestions.isEmpty {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { suggestions = [] }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .zIndex(1)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .zIndex(0)

            if !suggestions.isEmpty {
                SuggestionsOverlay(
                    suggestions: suggestions,
                    suggestionsHeight: $suggestionsHeight,
                    selectedIndex: $selectedSuggestionIndex,
                    onSelect: { suggestion in
                        browserState.activeTab?.navigate(to: suggestion.text, grabFocus: true)
                        suggestions = []
                    }
                )
                .frame(width: barFrame.width)
                .position(
                    x: barFrame.midX,
                    y: barFrame.maxY + suggestionsHeight / 2 + 8
                )
                .zIndex(2)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                .onExitCommand {
                    suggestions = []
                    selectedSuggestionIndex = nil
                }
            }
        }
        .coordinateSpace(name: "browserWindow")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: suggestions.isEmpty)
        .frame(minWidth: 900, minHeight: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in }
        .onChange(of: browserState.activeTabId) { _ in
            suggestions = []
            selectedSuggestionIndex = nil
        }
    }
}

// MARK: - BrowserToolbar

struct BrowserToolbar: View {

    @Binding var barFrame: CGRect
    @Binding var suggestions: [Suggestion]
    @Binding var suggestionsHeight: CGFloat
    @Binding var selectedSuggestionIndex: Int?

    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject var bookmarkStore: BookmarkStore

    var body: some View {
        HStack(spacing: 0) {
            // Left toolbar buttons – fixed min-width keeps the address bar centred
            HStack(spacing: 6) {
                NavButton(
                    symbolName: "chevron.left",
                    tooltip: "Go Back (⌘[)",
                    enabled: browserState.activeTab?.canGoBack ?? false
                ) {
                    browserState.activeTab?.goBack()
                }

                NavButton(
                    symbolName: "chevron.right",
                    tooltip: "Go Forward (⌘])",
                    enabled: browserState.activeTab?.canGoForward ?? false
                ) {
                    browserState.activeTab?.goForward()
                }

                NavButton(
                    symbolName: browserState.activeTab?.isLoading == true ? "xmark" : "arrow.clockwise",
                    tooltip: browserState.activeTab?.isLoading == true ? "Stop Loading" : "Reload (⌘R)",
                    enabled: true
                ) {
                    if browserState.activeTab?.isLoading == true {
                        browserState.activeTab?.stopLoad()
                    } else {
                        browserState.activeTab?.reload()
                    }
                }
            }
            .frame(minWidth: 100, alignment: .leading)

            Spacer()

            // Centred address bar, Safari-style
            AddressBarView(
                barFrame: $barFrame,
                suggestions: $suggestions,
                suggestionsHeight: $suggestionsHeight,
                selectedSuggestionIndex: $selectedSuggestionIndex
            )
            .environmentObject(browserState)
            .environmentObject(bookmarkStore)
            .frame(maxWidth: 600)

            Spacer()

            // Right toolbar buttons – mirror the left side so the bar stays centred
            HStack(spacing: 6) {
                NavButton(
                    symbolName: "sidebar.left",
                    tooltip: "Toggle Bookmarks (⌘B)",
                    enabled: true
                ) {
                    browserState.toggleSidebar()
                }
            }
            .frame(minWidth: 100, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            ZStack {
                VStack {
                    Spacer()
                    if let tab = browserState.activeTab, tab.isLoading {
                        GeometryReader { geo in
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.prismPurple, Color.blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * tab.estimatedProgress, height: 2)
                                .animation(.easeInOut(duration: 0.2), value: tab.estimatedProgress)
                        }
                        .frame(height: 2)
                    }
                }
            }
        )
    }
}

// MARK: - NavButton

struct NavButton: View {
    let symbolName: String
    let tooltip: String
    let enabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        let shortcut = keyEquivalent(for: symbolName)
        let mods = modifiers(for: symbolName)

        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(enabled ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered && enabled
                              ? Color.primary.opacity(0.08)
                              : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(tooltip)
        .onHover { isHovered = $0 }
        .modifier(ConditionalKeyboardShortcut(keyEquivalent: shortcut, modifiers: mods))
    }

    private func keyEquivalent(for symbol: String) -> KeyEquivalent {
        switch symbol {
        case "chevron.left":  return "["
        case "chevron.right": return "]"
        case "arrow.clockwise", "xmark": return "r"
        default: return "\0"
        }
    }

    private func modifiers(for symbol: String) -> EventModifiers {
        switch symbol {
        case "chevron.left", "chevron.right", "arrow.clockwise", "xmark": return .command
        default: return []
        }
    }
}

struct ConditionalKeyboardShortcut: ViewModifier {
    let keyEquivalent: KeyEquivalent
    let modifiers: EventModifiers

    func body(content: Content) -> some View {
        if keyEquivalent != KeyEquivalent("\0") || !modifiers.isEmpty {
            content.keyboardShortcut(keyEquivalent, modifiers: modifiers)
        } else {
            content
        }
    }
}

// MARK: - Color extension

extension Color {
    static let prismPurple = Color(red: 139/255, green: 92/255, blue: 246/255)
    static let prismBlue   = Color(red: 59/255,  green: 130/255, blue: 246/255)
    static let prismTeal   = Color(red: 20/255,  green: 184/255, blue: 166/255)
}