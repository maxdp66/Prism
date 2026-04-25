import SwiftUI
import AppKit

// MARK: - AddressBarView

struct AddressBarView: View {

    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject var bookmarkStore: BookmarkStore
    @EnvironmentObject private var settings: BrowserSettings

    @State private var editingText: String = ""
    @State private var isEditing: Bool = false
    @State private var isHovered: Bool = false
    @State private var showPrivacyPopover = false
    @State private var suggestions: [String] = []
    @State private var barFrame: CGRect = .zero
    @FocusState private var isFocused: Bool

    var activeTab: BrowserTab? { browserState.activeTab }

    private var searchPlaceholder: String {
        "Search \(settings.searchEngine.rawValue) or enter address"
    }

    var body: some View {
        ZStack(alignment: .top) {
            addressBarContent
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: FramePrefKey.self, value: geo.frame(in: .global))
                    }
                )
                .onPreferenceChange(FramePrefKey.self) { newFrame in
                    barFrame = newFrame
                }
                .zIndex(0)

            if isFocused && !suggestions.isEmpty {
                suggestionsList
                    .frame(width: barFrame.width)
                    .position(x: barFrame.midX, y: barFrame.maxY + 8 + 100)
                    .zIndex(999)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: suggestions.isEmpty)
    }

    private var addressBarContent: some View {
        HStack(spacing: 6) {
            securityIcon

            ZStack(alignment: .leading) {
                if !isEditing {
                    displayLabel
                }
                TextField(searchPlaceholder, text: $editingText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isFocused)
                    .opacity(isEditing ? 1 : 0)
                    .onSubmit {
                        commit()
                    }
                    .onChange(of: isFocused) { focused in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isEditing = focused
                        }
                        if focused {
                            editingText = activeTab?.displayURL ?? ""
                        } else {
                            suggestions = []
                        }
                    }
                    .onChange(of: editingText) { newValue in
                        if isFocused && settings.autocompleteProvider != .none && newValue.count >= 2 {
                            fetchAutocomplete(for: newValue)
                        } else {
                            suggestions = []
                        }
                    }
            }

            Spacer(minLength: 0)

            privacyShield

            bookmarkButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isEditing
                                ? Color.prismPurple.opacity(0.7)
                                : (isHovered ? Color.secondary.opacity(0.3) : Color.secondary.opacity(0.15)),
                            lineWidth: isEditing ? 1.5 : 1
                        )
                )
        )
        .frame(maxWidth: .infinity)
        .onHover { isHovered = $0 }
        .onTapGesture {
            isFocused = true
        }
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
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSecure ? .green : .secondary)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 16)
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
        h.font = .system(size: 13, weight: .medium)

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
            HStack(spacing: 3) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 11))
                    .foregroundColor(count > 0 ? .prismPurple : .secondary)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.prismPurple)
                }
            }
        }
        .buttonStyle(.plain)
        .help("Privacy Shield – \(count) trackers blocked")
        .popover(isPresented: $showPrivacyPopover, arrowEdge: .bottom) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundColor(isEnabled ? .green : .secondary)
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
                        .foregroundColor(count > 0 ? .prismPurple : .secondary)
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
                bookmarkStore.remove(bookmarkStore.bookmarks.first { $0.url == url }!)
            } else if !url.isEmpty {
                bookmarkStore.add(title: activeTab?.title ?? "", url: url)
            }
        } label: {
            Image(systemName: isBookmarked ? "star.fill" : "star")
                .font(.system(size: 12))
                .foregroundColor(isBookmarked ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
        .help(isBookmarked ? "Remove Bookmark" : "Add Bookmark")
        .opacity(url.isEmpty ? 0 : 1)
    }

    @ViewBuilder
    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    editingText = suggestion
                    suggestions = []
                    commit()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 16)

                        Text(suggestion)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
    }

    private func fetchAutocomplete(for query: String) {
        AutocompleteService.shared.fetchSuggestions(
            for: query,
            provider: settings.autocompleteProvider,
            customURL: settings.searchEngine == .searxng ? settings.searxngURL : nil,
            apiKey: settings.autocompleteAPIKey.isEmpty ? nil : settings.autocompleteAPIKey
        ) { results in
            self.suggestions = results
        }
    }

    // MARK: Actions

    private func commit() {
        let text = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        isFocused = false
        suggestions = []
        if !text.isEmpty {
            browserState.activeTab?.navigate(to: text)
        }
    }
}

// MARK: - Frame Preference Key

private struct FramePrefKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
