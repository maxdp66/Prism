import SwiftUI
import AppKit

// MARK: - CompactTabItem

struct CompactTabItem: View {

    @ObservedObject var tab: BrowserTab
    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject var bookmarkStore: BookmarkStore
    @EnvironmentObject private var settings: BrowserSettings

    /// Visual displacement applied when another tab is being dragged past this one.
    let displacement: CGFloat

    @Binding var barFrame: CGRect
    @Binding var suggestions: [Suggestion]
    @Binding var suggestionsHeight: CGFloat
    @Binding var selectedSuggestionIndex: Int?

    let onFocus: () -> Void
    let onBlur: () -> Void
    /// Called each drag frame with the current translation so CompactTabBar can
    /// update displacements without publishing through BrowserState.
    let onDragUpdate: (CGFloat) -> Void
    /// Called when the drag gesture ends so CompactTabBar can reset local displacement state.
    let onDragEnd: () -> Void

    @State private var editingText: String = ""
    @State private var isHovered: Bool = false
    @FocusState private var addressBarFocused: Bool
    @State private var autocompleteTask: Task<Void, Never>?
    @State private var viewUpdateTrigger: Int = 0
    
    // Drag state
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0.0
    @State private var dragStartLocation: CGPoint = .zero

    private var isActive: Bool {
        browserState.activeTabId == tab.id
    }

    private var isFocused: Bool {
        browserState.focusedTabId == tab.id
    }
    
    private var isBeingDragged: Bool {
        browserState.draggingTabId == tab.id
    }

    private var searchPlaceholder: String {
        "Search \(settings.searchEngine.rawValue) or enter address"
    }

    private var displayTitle: String {
        let title = tab.title
        let hasValidTitle = !title.isEmpty && title != "New Tab"
        
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
        ZStack(alignment: .trailing) {
            if isFocused {
                // Address Bar Mode
                addressBarContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .leading)),
                        removal:   .opacity.combined(with: .scale(scale: 0.96, anchor: .leading))
                    ))
                    .onAppear {
                        DispatchQueue.main.async {
                            if isFocused { addressBarFocused = true }
                        }
                    }
            } else {
                // Tab Display Mode
                tabDisplayContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .leading)),
                        removal:   .opacity
                    ))
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
                    // Drag gesture for reordering and extracting tabs
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                if !isDragging {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                                        isDragging = true
                                    }
                                    dragStartLocation = value.startLocation
                                    dragOffset = 0
                                    browserState.startDrag(tabId: tab.id)
                                }
                                // Update local position directly — no BrowserState publish
                                dragOffset = value.translation.width
                                onDragUpdate(value.translation.width)
                            }
                            .onEnded { value in
                                let dropLocation = value.location
                                let inTabBar = dropLocation.y <= barFrame.maxY + 20
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    isDragging = false
                                    dragOffset = 0
                                }
                                onDragEnd()
                                browserState.endDrag(inTabBar: inTabBar, tabBarFrame: barFrame, dropLocation: dropLocation)
                            }
                    )
            }
        }
        // Focused tab expands for address bar; display-mode tabs cap so the trailing
        // WindowDragHandle fills the remaining space.
        .frame(minWidth: isFocused ? 180 : 60, maxWidth: isFocused ? 260 : 200)
        .frame(height: 28)
        // Single spring drives both the frame resize and the view transitions above.
        .animation(.spring(response: 0.3, dampingFraction: 0.78), value: isFocused)
        // Visual feedback during drag
        .scaleEffect(isBeingDragged ? 1.05 : 1.0)
        .shadow(color: isBeingDragged ? .black.opacity(0.3) : .clear, radius: isBeingDragged ? 10 : 0)
        .opacity(isBeingDragged ? 0.7 : 1.0)
        // Dragged tab follows cursor; other tabs slide aside (iOS-style)
        .offset(x: isBeingDragged ? dragOffset : displacement)
        // Explicitly observe tab property changes to force view re-evaluation
        .onReceive(tab.objectWillChange) { _ in
            // Increment to trigger view update
            viewUpdateTrigger += 1
        }
        .background(
            Group {
                if isActive && !isBeingDragged {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                } else if !isBeingDragged {
                    // Inactive tabs: subtle fill + border so they're always legible,
                    // slightly stronger on hover.
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(isHovered ? 0.07 : 0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.primary.opacity(isHovered ? 0.16 : 0.10), lineWidth: 0.75)
                        )
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
        .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)
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