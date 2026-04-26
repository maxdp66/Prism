import SwiftUI
import AppKit

// MARK: - CompactTabItem

struct CompactTabItem: View {

    @ObservedObject var tab: BrowserTab
    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject var bookmarkStore: BookmarkStore
    @EnvironmentObject private var settings: BrowserSettings

    @Binding var barFrame: CGRect
    @Binding var suggestions: [Suggestion]
    @Binding var suggestionsHeight: CGFloat
    @Binding var selectedSuggestionIndex: Int?

    let onFocus: () -> Void
    let onBlur: () -> Void

    @State private var editingText: String = ""
    @State private var isHovered: Bool = false
    @FocusState private var addressBarFocused: Bool
    @State private var autocompleteTask: Task<Void, Never>?
    @State private var viewUpdateTrigger: Int = 0  // Force view updates

    private var isActive: Bool {
        browserState.activeTabId == tab.id
    }

    private var isFocused: Bool {
        browserState.focusedTabId == tab.id
    }

    private var searchPlaceholder: String {
        "Search \(settings.searchEngine.rawValue) or enter address"
    }

    private var displayTitle: String {
        let title = tab.title
        let hasValidTitle = !title.isEmpty && title != "New Tab"
        // Debug: print when this is evaluated
        #if DEBUG
        print("[CompactTabItem] displayTitle evaluated for tab \(tab.id.uuidString.prefix(8)): title='\(title)', displayURL='\(tab.displayURL)', hasValidTitle=\(hasValidTitle)")
        #endif
        
        if settings.showWebsiteNameOnly {
            // Try to extract site name from page title first
            if hasValidTitle {
                // Extract site name from title: take first part before common separators
                let separators = [" - ", " | ", " · ", " – ", " — "]
                var siteName = title
                for separator in separators {
                    if let range = siteName.range(of: separator) {
                        siteName = String(siteName[..<range.lowerBound])
                        break
                    }
                }
                // Clean up and capitalize
                siteName = siteName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !siteName.isEmpty {
                    return siteName
                }
            }

            // Fallback to hostname extraction
            if let url = URL(string: tab.displayURL), let host = url.host {
                // Extract site name: remove www. prefix and TLD suffix
                var siteName = host
                if siteName.hasPrefix("www.") {
                    siteName = String(siteName.dropFirst(4))
                }
                // Remove TLD (everything after the first dot)
                if let dotIndex = siteName.firstIndex(of: ".") {
                    siteName = String(siteName[..<dotIndex])
                }
                return siteName.capitalized
            }

            return "New Tab"
        } else {
            // When not showing website name only, prefer title but fall back to URL
            if hasValidTitle {
                return title
            }
            // If no valid title, try to show hostname from URL
            if let url = URL(string: tab.displayURL), let host = url.host {
                var siteName = host
                if siteName.hasPrefix("www.") {
                    siteName = String(siteName.dropFirst(4))
                }
                return siteName
            }
            return "New Tab"
        }
    }

    var body: some View {
        #if DEBUG
        let _ = { print("[CompactTabItem] body evaluated for tab \(tab.id.uuidString.prefix(8))") }()
        #endif
        
        ZStack(alignment: .trailing) {
            if isFocused {
                // Address Bar Mode
                addressBarContent
                    .onAppear {
                        DispatchQueue.main.async {
                            if isFocused {
                                addressBarFocused = true
                            }
                        }
                    }
            } else {
                // Tab Display Mode
                tabDisplayContent
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                    // First tap activates the tab, second tap focuses the URL bar
                    .onTapGesture {
                        browserState.focusedTabId = nil
                        if browserState.activeTabId != tab.id {
                            browserState.activateTab(tab)
                        } else {
                            onFocus()
                            editingText = tab.displayURL
                        }
                    }
            }
        }
        .frame(minWidth: 60, maxWidth: .infinity)
        .frame(height: 28)
        // Explicitly observe tab property changes to force view re-evaluation
        .onReceive(tab.objectWillChange) { _ in
            // Increment to trigger view update
            viewUpdateTrigger += 1
        }
        .background(
            Group {
                if isActive {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                } else if isHovered && !isFocused {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.05))
                }
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onHover { isHovered = $0 }
        .onChange(of: addressBarFocused) { _, newValue in
            if newValue {
                editingText = tab.displayURL
            } else if isFocused {
                onBlur()
                suggestions = []
            }
        }
    }
    
    @ViewBuilder
    private var addressBarContent: some View {
        HStack(spacing: 8) {
            // Security icon
            Group {
                if tab.isSecure {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.2))
                } else if !tab.displayURL.isEmpty {
                    Image(systemName: "globe")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 12)

            // Input field
            TextField(searchPlaceholder, text: $editingText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($addressBarFocused)
                .onSubmit {
                    commitAddress()
                }
                .onChange(of: editingText) { _, newValue in
                    selectedSuggestionIndex = nil
                    autocompleteTask?.cancel()

                    guard addressBarFocused,
                          settings.autocompleteProvider != .none,
                          newValue.count >= 2 else {
                        suggestions = []
                        return
                    }

                    autocompleteTask = Task {
                        try? await Task.sleep(for: .milliseconds(200))
                        guard !Task.isCancelled else { return }
                        await fetchAutocomplete(for: newValue)
                    }
                }

            Spacer()

            // Close button (always visible in focused mode)
            Button {
                browserState.closeTab(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.primary.opacity(0.5))
                    .frame(width: 16, height: 16)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(minWidth: 200, idealWidth: 300, maxWidth: .infinity)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        barFrame = geo.frame(in: .named("browserWindow"))
                    }
                    .onChange(of: geo.frame(in: .named("browserWindow"))) { _, newFrame in
                        barFrame = newFrame
                    }
            }
        )
    }

    @ViewBuilder
    private var tabDisplayContent: some View {
        ZStack {
            // This invisible view forces re-evaluation when viewUpdateTrigger changes
            Color.clear
                .frame(width: 0, height: 0)
                .id(viewUpdateTrigger)
            
            HStack(spacing: 6) {
                // Leading icon/close
                Group {
                    if let favicon = tab.favicon {
                        Image(nsImage: favicon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 14, height: 14)

                // Title/URL
                VStack(alignment: .leading, spacing: 0) {
                    Text(displayTitle)
                        .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? .primary : .secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Close button (always accessible, appears on hover)
                if isHovered {
                    Button {
                        browserState.closeTab(tab)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.primary.opacity(0.4))
                            .frame(width: 14, height: 14)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                } else {
                    // Placeholder to keep layout consistent
                    Color.clear.frame(width: 14, height: 14)
                }
            }

            // Loading bar overlay inside tab
            if tab.isLoading {
                VStack {
                    Spacer()
                    GeometryReader { geometry in
                        ZStack {
                            // Base bar
                            Rectangle()
                                .fill(Color(red: 0.0, green: 0.8, blue: 0.4).opacity(0.8))
                                .frame(width: geometry.size.width * max(CGFloat(tab.estimatedProgress), 0.05), height: 2)

                            // Refractive gradient overlay
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.clear,
                                            settings.appearanceMode == .dark ? Color.white.opacity(0.4) : Color.white.opacity(0.3),
                                            Color.clear
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * max(CGFloat(tab.estimatedProgress), 0.05), height: 2)
                                .mask(
                                    Rectangle()
                                        .frame(width: geometry.size.width * max(CGFloat(tab.estimatedProgress), 0.05), height: 2)
                                )
                        }
                        .shadow(color: Color(red: 0.0, green: 0.8, blue: 0.4).opacity(0.6), radius: 4, y: 0)
                        .shadow(color: Color(red: 0.0, green: 0.8, blue: 0.4).opacity(0.3), radius: 8, y: 0)
                        .animation(.easeInOut(duration: 0.3), value: tab.estimatedProgress)
                    }
                    .frame(height: 2)
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func fetchAutocomplete(for query: String) async {
        let results = await AutocompleteService.shared.fetchSuggestions(
            for: query,
            provider: settings.autocompleteProvider,
            customURL: settings.searchEngine == .searxng ? settings.searxngURL : nil,
            apiKey: settings.autocompleteAPIKey.isEmpty ? nil : settings.autocompleteAPIKey,
            bookmarks: bookmarkStore.bookmarks,
            history: HistoryStore.shared.entries
        )
        guard !Task.isCancelled else { return }
        suggestions = results
    }

    private func commitAddress() {
        let text = editingText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = selectedSuggestionIndex,
           index >= 0, index < suggestions.count {
            let selected = suggestions[index]
            selectedSuggestionIndex = nil
            suggestions = []
            browserState.activateTab(tab)
            tab.navigate(to: selected.text)
        } else {
            suggestions = []
            selectedSuggestionIndex = nil
            if !text.isEmpty {
                browserState.activateTab(tab)
                tab.navigate(to: text)
            }
        }

        // Unfocus tab after navigation, clear typing state
        browserState.focusedTabId = nil
        addressBarFocused = false
        editingText = ""
    }
}
