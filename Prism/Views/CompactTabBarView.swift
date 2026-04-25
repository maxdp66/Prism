import SwiftUI
import AppKit

// MARK: - CompactTabBar

struct CompactTabBar: View {
    
    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject var bookmarkStore: BookmarkStore
    @EnvironmentObject private var settings: BrowserSettings
    
    @Binding var barFrame: CGRect
    @Binding var suggestions: [Suggestion]
    @Binding var suggestionsHeight: CGFloat
    @Binding var selectedSuggestionIndex: Int?
    
    @State private var focusedTabId: UUID? = nil
    
    var body: some View {
        HStack(spacing: 6) {
            // Leading spacer for traffic lights
            Color.clear
                .frame(width: 76)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(browserState.tabs, id: \.id) { tab in
                        CompactTabItem(
                            tab: tab,
                            isFocused: focusedTabId == tab.id,
                            barFrame: $barFrame,
                            suggestions: $suggestions,
                            suggestionsHeight: $suggestionsHeight,
                            selectedSuggestionIndex: $selectedSuggestionIndex,
                            onFocus: {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                    focusedTabId = tab.id
                                }
                            },
                            onBlur: {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                    focusedTabId = nil
                                }
                            }
                        )
                        .environmentObject(browserState)
                        .environmentObject(bookmarkStore)
                        .environmentObject(settings)
                        .id(tab.id)
                    }
                }
                .padding(.horizontal, 6)
            }
            .frame(maxWidth: .infinity)
            
            // New Tab Button
            Button {
                browserState.addNewTab(url: nil)
                focusedTabId = nil
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
            .help("New Tab (⌘T)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

// MARK: - CompactTabItem

struct CompactTabItem: View {
    
    @ObservedObject var tab: BrowserTab
    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject var bookmarkStore: BookmarkStore
    @EnvironmentObject private var settings: BrowserSettings
    
    let isFocused: Bool
    
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
    
    private var isActive: Bool {
        browserState.activeTabId == tab.id
    }
    
    private var searchPlaceholder: String {
        "Search \(settings.searchEngine.rawValue) or enter address"
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            if isFocused {
                // Address Bar Mode
                addressBarContent
            } else {
                // Tab Display Mode
                tabDisplayContent
            }
        }
        .frame(minWidth: 60, maxWidth: .infinity)
        .frame(height: 28)
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
        .onTapGesture {
            if !isFocused {
                onFocus()
                addressBarFocused = true
                editingText = tab.displayURL
            }
        }
        .onChange(of: addressBarFocused) { _, newValue in
            if !newValue && isFocused {
                onBlur()
                suggestions = []
            }
        }
        .onChange(of: browserState.activeTabId) { _, _ in
            if isFocused && browserState.activeTabId != tab.id {
                addressBarFocused = false
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
        HStack(spacing: 6) {
            // Leading icon/close
            ZStack {
                if tab.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                } else if let favicon = tab.favicon {
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
                Text(tab.title.isEmpty ? "New Tab" : tab.title)
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
        .padding(.horizontal, 8)
        .onTapGesture {
            browserState.activateTab(tab)
        }
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
        addressBarFocused = false
        
        if let index = selectedSuggestionIndex,
           index >= 0, index < suggestions.count {
            let selected = suggestions[index]
            selectedSuggestionIndex = nil
            suggestions = []
            tab.navigate(to: selected.text, grabFocus: true)
        } else {
            suggestions = []
            selectedSuggestionIndex = nil
            if !text.isEmpty {
                tab.navigate(to: text, grabFocus: true)
            }
        }
    }
}
