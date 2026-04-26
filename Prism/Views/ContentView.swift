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

    private var immersiveHeader: some View {
        ZStack(alignment: .top) {
            VisualEffectView(material: .titlebar, blendingMode: .withinWindow)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            if let activeTab = browserState.activeTab, activeTab.themeColor != .clear {
                Rectangle()
                    .fill(activeTab.themeColor)
                    .opacity(0.5)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                if settings.layoutStyle == .compact {
                    compactHeader
                } else {
                    standardHeader
                }

                if settings.layoutStyle != .compact {
                    Divider()
                        .opacity(0.1)
                }
            }
        }
        .frame(height: settings.layoutStyle.headerHeight)
        .ignoresSafeArea()
        .preferredColorScheme(settings.appearanceMode.colorScheme)
    }

    private var compactHeader: some View {
        CompactTabBar(
            barFrame: $barFrame,
            suggestions: $suggestions,
            suggestionsHeight: $suggestionsHeight,
            selectedSuggestionIndex: $selectedSuggestionIndex
        )
        .environmentObject(browserState)
        .environmentObject(bookmarkStore)
        .environmentObject(settings)
        .coordinateSpace(name: "browserWindow")
        .padding(.vertical, 6)
        .frame(height: settings.layoutStyle.headerHeight)
    }

    private var standardHeader: some View {
        HStack(spacing: 12) {
            Spacer()
                .frame(width: 80)

            AddressBarView(
                barFrame: $barFrame,
                suggestions: $suggestions,
                suggestionsHeight: $suggestionsHeight,
                selectedSuggestionIndex: $selectedSuggestionIndex
            )
            .environmentObject(browserState)
            .environmentObject(bookmarkStore)
            .environmentObject(settings)
            .coordinateSpace(name: "browserWindow")
            .frame(maxWidth: 450)

            Spacer()
        }
        .padding(.vertical, settings.layoutStyle == .vertical ? 4 : 8)
        .frame(height: settings.layoutStyle == .vertical ? 38 : 48)
    }

private var webContentSection: some View {
        ZStack {
            HSplitView {
                if settings.layoutStyle == .vertical {
                    SidebarView()
                        .environmentObject(browserState)
                        .environmentObject(bookmarkStore)
                        .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                if let tab = browserState.activeTab {
                    ActiveTabView(
                        tab: tab,
                        clearSuggestions: { suggestions = [] }
                    )
                    .environmentObject(browserState)
                    .environmentObject(settings)
                } else {
                    NewTabView(clearSuggestions: { suggestions = [] })
                        .environmentObject(browserState)
                        .environmentObject(settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, settings.layoutStyle.headerHeight)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: browserState.activeTabId)

            if !suggestions.isEmpty {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { suggestions = [] }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if browserState.settingsChangedNeedsReload {
                VStack {
                    SettingsReloadBanner {
                        browserState.reloadAllTabs()
                    } onDismiss: {
                        browserState.settingsChangedNeedsReload = false
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
            }

            if let tab = browserState.activeTab, tab.isFindBarVisible {
                VStack {
                    Spacer()
                    FindBar(tab: tab)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private var suggestionsOverlay: some View {
        Group {
            if !suggestions.isEmpty {
                SuggestionsOverlay(
                    suggestions: suggestions,
                    suggestionsHeight: $suggestionsHeight,
                    selectedIndex: $selectedSuggestionIndex,
                    onSelect: { suggestion in
                        browserState.activeTab?.navigate(to: suggestion.text)
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
    }

    var body: some View {
        ZStack {
            webContentSection
                .zIndex(0)
            
            VStack(spacing: 0) {
                immersiveHeader
                    .zIndex(1)
                Spacer()
            }
            
            suggestionsOverlay
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 900, minHeight: 600)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: suggestions.isEmpty)
        .animation(.spring(response: 0.2, dampingFraction: 0.9), value: browserState.settingsChangedNeedsReload)
        .animation(.spring(response: 0.2, dampingFraction: 0.9), value: browserState.activeTab?.isFindBarVisible)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settings.layoutStyle)
        .onChange(of: browserState.activeTabId) {
            suggestions = []
            selectedSuggestionIndex = nil
        }
        .animation(.easeInOut(duration: 0.3), value: settings.appearanceMode)
    }
}

// MARK: - VisualEffectView

// MARK: - VisualEffectView

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - FindBar

struct FindBar: View {
    @ObservedObject var tab: BrowserTab
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            TextField("Find in page", text: $tab.findQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
                .onSubmit { tab.findInPage(tab.findQuery, forward: true) }
                .onChange(of: tab.findQuery) {
                    tab.findInPage(tab.findQuery, forward: true)
                }

            if tab.findMatchCount == 0 && !tab.findQuery.isEmpty {
                Text("No results")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 4) {
                Button {
                    tab.findInPage(tab.findQuery, forward: false)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(tab.findQuery.isEmpty)

                Button {
                    tab.findInPage(tab.findQuery, forward: true)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(tab.findQuery.isEmpty)
            }

            Spacer()

            Button {
                tab.dismissFindBar()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 0.5)
        }
        .onAppear { isFocused = true }
    }
}

// MARK: - SettingsReloadBanner

struct SettingsReloadBanner: View {
    let onReloadAll: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 13))

            Text("Settings updated — reload tabs to apply changes.")
                .font(.system(size: 12))
                .foregroundColor(.primary)

            Spacer()

            Button("Reload All") {
                onReloadAll()
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.blue)
            .buttonStyle(.plain)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color.blue.opacity(0.08))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 0.5)
        }
    }
}
