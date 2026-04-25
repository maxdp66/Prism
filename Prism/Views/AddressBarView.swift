import SwiftUI
import AppKit

// MARK: - AddressBarView

struct AddressBarView: View {

    @Binding var barFrame: CGRect
    @Binding var suggestions: [Suggestion]
    @Binding var suggestionsHeight: CGFloat
    @Binding var selectedSuggestionIndex: Int?

    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject var bookmarkStore: BookmarkStore
    @EnvironmentObject private var settings: BrowserSettings

    @State private var editingText: String = ""
    @State private var isEditing: Bool = false
    @State private var isHovered: Bool = false
    @State private var showPrivacyPopover = false
    @State private var autocompleteTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    var activeTab: BrowserTab? { browserState.activeTab }

    private var searchPlaceholder: String {
        "Search \(settings.searchEngine.rawValue) or enter address"
    }

    var body: some View {
        addressBarContent
    }

    private var addressBarContent: some View {
        HStack(spacing: 10) {
            // MARK: Security/Search Icon
            securityIcon
                .frame(width: 16, height: 16)

            // MARK: Address Input Field
            ZStack(alignment: .leading) {
                // Display mode (non-editing)
                if !isEditing {
                    displayLabel
                }
                
                // Input mode (editing)
                TextField(searchPlaceholder, text: $editingText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isFocused)
                    .opacity(isEditing ? 1 : 0)
                    .onSubmit {
                        commit()
                    }
                    .onMoveCommand { direction in
                        switch direction {
                        case .down:
                            if let current = selectedSuggestionIndex {
                                if current < suggestions.count - 1 {
                                    selectedSuggestionIndex = current + 1
                                }
                            } else if !suggestions.isEmpty {
                                selectedSuggestionIndex = 0
                            }
                        case .up:
                            if let current = selectedSuggestionIndex {
                                if current > 0 {
                                    selectedSuggestionIndex = current - 1
                                }
                            } else if !suggestions.isEmpty {
                                selectedSuggestionIndex = suggestions.count - 1
                            }
                        default:
                            break
                        }
                    }
                    .onChange(of: isFocused) { _, newValue in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isEditing = newValue
                        }
                        if newValue {
                            editingText = activeTab?.displayURL ?? ""
                        } else {
                            suggestions = []
                        }
                    }
                    .onChange(of: editingText) { _, newValue in
                        selectedSuggestionIndex = nil
                        autocompleteTask?.cancel()

                        guard isFocused,
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
            }

            Spacer(minLength: 0)

            // MARK: Right-side Controls
            HStack(spacing: 12) {
                privacyShield
                bookmarkButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(isEditing ? 0.75 : 0.5))
                
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        Color.primary.opacity(isEditing ? 0.15 : 0.06),
                        lineWidth: 1
                    )
            }
        )
        .frame(height: 32)
        .onHover { isHovered = $0 }
        .onTapGesture {
            isFocused = true
        }
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
        .background(
            Button("") {
                isFocused = true
                editingText = activeTab?.displayURL ?? ""
            }
            .keyboardShortcut("l", modifiers: .command)
            .opacity(0)
        )
    }

    // MARK: Subviews

    @ViewBuilder
    private var securityIcon: some View {
        let isSecure = activeTab?.isSecure ?? false
        let hasURL = !(activeTab?.displayURL.isEmpty ?? true)

        Group {
            if hasURL {
                Image(systemName: isSecure ? "lock.fill" : "globe")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSecure ? Color(red: 0.2, green: 0.8, blue: 0.2) : .secondary)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var displayLabel: some View {
        let urlString = activeTab?.displayURL ?? ""
        let isLoading = activeTab?.isLoading ?? false

        Group {
            if urlString.isEmpty && !isLoading {
                Text(searchPlaceholder)
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
            } else {
                styledURL(urlString)
            }
        }
        .lineLimit(1)
        .truncationMode(.tail)
    }

    private func styledURL(_ raw: String) -> Text {
        guard let url = URL(string: raw), let host = url.host else {
            return Text(raw).font(.system(size: 13))
        }
        let scheme = (url.scheme ?? "https") + "://"
        let rest = String(raw.dropFirst(scheme.count + host.count))

        var s = AttributedString(scheme)
        s.foregroundColor = .secondary
        s.font = .system(size: 13)

        var h = AttributedString(host)
        h.foregroundColor = .primary
        h.font = .system(size: 13, weight: .semibold)

        var r = AttributedString(rest)
        r.foregroundColor = .secondary
        r.font = .system(size: 13)

        return Text(s + h + r)
    }

    @ViewBuilder
    private var privacyShield: some View {
        let count = activeTab?.blockedItemsCount ?? 0
        let isEnabled = browserState.isContentBlockerReady && settings.contentBlockerEnabled

        Button(action: { showPrivacyPopover = true }) {
            HStack(spacing: 4) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(count > 0 ? Color(red: 0.6, green: 0.3, blue: 1.0) : .secondary)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.6, green: 0.3, blue: 1.0))
                }
            }
        }
        .buttonStyle(.plain)
        .help("Privacy Shield – \(count) trackers blocked")
        .popover(isPresented: $showPrivacyPopover, arrowEdge: .bottom) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundColor(isEnabled ? Color(red: 0.2, green: 0.8, blue: 0.2) : .secondary)
                        .font(.system(size: 14))
                    Text(isEnabled ? "Content Blocker Active" : "Content Blocker Inactive")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                Divider()
                HStack {
                    Text("Trackers blocked on this page")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(count > 0 ? Color(red: 0.6, green: 0.3, blue: 1.0) : .secondary)
                }
            }
            .padding(12)
            .frame(width: 240)
        }
    }

    @ViewBuilder
    private var bookmarkButton: some View {
        let url = activeTab?.displayURL ?? ""
        let isBookmarked = bookmarkStore.bookmarks.contains { $0.url == url }

        Button {
            if isBookmarked {
                if let bookmark = bookmarkStore.bookmarks.first(where: { $0.url == url }) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        bookmarkStore.remove(bookmark)
                    }
                }
            } else if !url.isEmpty {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    bookmarkStore.add(title: activeTab?.title ?? "", url: url)
                }
            }
        } label: {
            Image(systemName: isBookmarked ? "star.fill" : "star")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isBookmarked ? Color(red: 1.0, green: 0.8, blue: 0.0) : .secondary)
                .scaleEffect(isBookmarked ? 1.15 : 1.0)
        }
        .buttonStyle(.plain)
        .help(isBookmarked ? "Remove Bookmark" : "Add Bookmark")
        .opacity(url.isEmpty ? 0 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isBookmarked)
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

    // MARK: Actions

    private func commit() {
        let text = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        isFocused = false

        // Capture selected suggestion BEFORE clearing the array
        if let index = selectedSuggestionIndex,
           index >= 0, index < suggestions.count {
            let selected = suggestions[index]
            selectedSuggestionIndex = nil
            suggestions = []
            browserState.activeTab?.navigate(to: selected.text, grabFocus: true)
        } else {
            suggestions = []
            selectedSuggestionIndex = nil
            if !text.isEmpty {
                browserState.activeTab?.navigate(to: text, grabFocus: true)
            }
        }
    }
}

// MARK: - SuggestionsOverlay

// MARK: - SuggestionsOverlay

struct SuggestionsOverlay: View {
    let suggestions: [Suggestion]
    @Binding var suggestionsHeight: CGFloat
    @Binding var selectedIndex: Int?
    let onSelect: (Suggestion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                        SuggestionRow(
                            suggestion: suggestion,
                            isSelected: selectedIndex == index
                        )
                        .onTapGesture {
                            onSelect(suggestion)
                        }
                        .onHover { hovering in
                            if hovering {
                                selectedIndex = index
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 400)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 15, y: 10)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        suggestionsHeight = geo.size.height
                    }
                    .onChange(of: geo.size.height) {
                        suggestionsHeight = geo.size.height
                    }
            }
        )
    }
}

// MARK: - SuggestionRow

struct SuggestionRow: View {
    let suggestion: Suggestion
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.type.iconName)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .white : iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)

                if let subtitle = suggestion.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let date = suggestion.dateText {
                Text(date)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
        .background(isSelected ? Color.accentColor : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var iconColor: Color {
        switch suggestion.type {
        case .url: return .blue
        case .bookmark: return .yellow
        case .history: return .secondary
        case .search: return .secondary
        }
    }
}