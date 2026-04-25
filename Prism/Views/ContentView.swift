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
        ZStack(alignment: .top) {
            HSplitView {
                if browserState.sidebarVisible {
                    SidebarView()
                        .environmentObject(browserState)
                        .environmentObject(bookmarkStore)
                        .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)
                        .transition(.move(edge: .leading))
                }

                if let tab = browserState.activeTab {
                    if tab.displayURL.isEmpty && !tab.isLoading {
                        NewTabView(clearSuggestions: { suggestions = [] })
                            .environmentObject(browserState)
                            .environmentObject(settings)
                    } else {
                        WebContentContainer(webView: tab.webView)
                    }
                } else {
                    NewTabView(clearSuggestions: { suggestions = [] })
                        .environmentObject(browserState)
                        .environmentObject(settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
            .zIndex(0)

            if !suggestions.isEmpty {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { suggestions = [] }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(1)
            }

            UnifiedToolbar(
                barFrame: $barFrame,
                suggestions: $suggestions,
                suggestionsHeight: $suggestionsHeight,
                selectedSuggestionIndex: $selectedSuggestionIndex
            )
            .environmentObject(browserState)
            .environmentObject(bookmarkStore)
            .environmentObject(settings)
            .coordinateSpace(name: "browserWindow")
            .zIndex(1)

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
                .zIndex(100)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                .onExitCommand {
                    suggestions = []
                    selectedSuggestionIndex = nil
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: suggestions.isEmpty)
        .onChange(of: browserState.activeTabId) { _ in
            suggestions = []
            selectedSuggestionIndex = nil
        }
    }
}

// MARK: - UnifiedToolbar

struct UnifiedToolbar: View {

    @Binding var barFrame: CGRect
    @Binding var suggestions: [Suggestion]
    @Binding var suggestionsHeight: CGFloat
    @Binding var selectedSuggestionIndex: Int?

    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject var bookmarkStore: BookmarkStore

    @State private var toolbarWidth: CGFloat = 0

    private var tabWidth: CGFloat {
        let padding: CGFloat = 16 + 8 + 76 + 10
        let actionButtonsWidth: CGFloat = 100 + 100
        let addressBarWidth: CGFloat = 600
        let availableWidth = toolbarWidth - padding - actionButtonsWidth - addressBarWidth
        let tabCount = max(1, CGFloat(browserState.tabs.count))
        let dynamicWidth = availableWidth / tabCount
        return max(100, min(220, dynamicWidth))
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                Color.clear
                    .preference(key: WidthPreferenceKey.self, value: geo.size.width)
                    .onPreferenceChange(WidthPreferenceKey.self) { toolbarWidth = $0 }
            }
            .frame(height: 0)

            HStack(spacing: 0) {
                Spacer().frame(width: 76)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(browserState.tabs.enumerated()), id: \.element.id) { index, tab in
                                let showSeparator = index > 0 && !browserState.tabs.isEmpty
                                let leftTab = index > 0 ? browserState.tabs[index - 1] : nil

                                if showSeparator {
                                    TabSeparatorView(
                                        leftTab: leftTab,
                                        rightTab: tab,
                                        browserState: browserState
                                    )
                                }

                                TabPillView(tab: tab)
                                    .environmentObject(browserState)
                                    .frame(width: tabWidth)
                                    .id(tab.id)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: browserState.tabs.count)
                            }

                            Button {
                                browserState.addNewTab(url: nil)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(Color.primary.opacity(0.05))
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("New Tab (⌘T)")
                            .padding(.leading, 2)
                        }
                        .padding(.horizontal, 16)
                    }
                    .scrollContentBackground(.hidden)
                    .onChange(of: browserState.activeTabId) { id in
                        if let id {
                            withAnimation { proxy.scrollTo(id, anchor: .center) }
                        }
                    }
                }

                Spacer(minLength: 4)
            }
            .frame(height: 32)
            .background(Color.clear)

            HStack(spacing: 0) {
                Spacer().frame(width: 76)

                HStack(spacing: 6) {
                    ToolbarButton(
                        symbolName: "chevron.left",
                        tooltip: "Go Back (⌘[)",
                        enabled: browserState.activeTab?.canGoBack ?? false
                    ) {
                        browserState.activeTab?.goBack()
                    }

                    ToolbarButton(
                        symbolName: "chevron.right",
                        tooltip: "Go Forward (⌘])",
                        enabled: browserState.activeTab?.canGoForward ?? false
                    ) {
                        browserState.activeTab?.goForward()
                    }

                    ToolbarButton(
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

                HStack(spacing: 6) {
                    ToolbarButton(
                        symbolName: "sidebar.left",
                        tooltip: "Toggle Bookmarks (⌘B)",
                        enabled: true
                    ) {
                        browserState.toggleSidebar()
                    }
                }
                .frame(minWidth: 100, alignment: .trailing)

                Spacer().frame(width: 10)
            }
            .frame(height: 38)
            .background(Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 0.5)
            }

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
        .background(.ultraThinMaterial)
    }
}

private struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - ToolbarButton

struct ToolbarButton: View {
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
                .opacity(enabled ? 0.7 : 0.4)
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

// MARK: - TabSeparatorView

struct TabSeparatorView: View {
    let leftTab: BrowserTab?
    let rightTab: BrowserTab
    @ObservedObject var browserState: BrowserState

    @State private var isHovered = false

    private var isActiveOrHovered: Bool {
        let rightActive = browserState.activeTabId == rightTab.id
        let leftActive = leftTab != nil && browserState.activeTabId == leftTab?.id

        let rightHovered = isHovered

        return rightActive || leftActive || rightHovered
    }

    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 1, height: 16)
            .opacity(isActiveOrHovered ? 0 : 1)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Color extension

extension Color {
    static let prismPurple = Color(red: 139/255, green: 92/255, blue: 246/255)
    static let prismBlue   = Color(red: 59/255,  green: 130/255, blue: 246/255)
    static let prismTeal   = Color(red: 20/255,  green: 184/255, blue: 166/255)
}