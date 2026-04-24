import SwiftUI
import AppKit

// MARK: - SidebarView

struct SidebarView: View {

    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject var bookmarkStore: BookmarkStore

    @State private var searchText: String = ""
    @State private var showingAddSheet: Bool = false
    @State private var isEditing: Bool = false

    private var filteredBookmarks: [Bookmark] {
        if searchText.isEmpty { return bookmarkStore.bookmarks }
        return bookmarkStore.bookmarks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.url.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Bookmarks", systemImage: "bookmark.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    withAnimation { isEditing.toggle() }
                } label: {
                    Text(isEditing ? "Done" : "Edit")
                        .font(.system(size: 11))
                        .foregroundColor(.prismPurple)
                }
                .buttonStyle(.plain)

                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(.prismPurple)
                }
                .buttonStyle(.plain)
                .help("Add Bookmark")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("Search bookmarks", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Bookmark list
            List {
                ForEach(filteredBookmarks) { bookmark in
                    BookmarkRowView(bookmark: bookmark) {
                        browserState.activeTab?.navigate(to: bookmark.url)
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            bookmarkStore.remove(bookmark)
                        }
                    }
                }
                .onDelete { offsets in
                    bookmarkStore.remove(at: offsets)
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Footer: current tab info
            if let tab = browserState.activeTab, !tab.displayURL.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Current Page")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(0.8)

                    Text(tab.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(tab.displayURL)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
        )
        .sheet(isPresented: $showingAddSheet) {
            AddBookmarkSheet(isPresented: $showingAddSheet)
                .environmentObject(browserState)
                .environmentObject(bookmarkStore)
        }
    }
}

// MARK: - BookmarkRowView

struct BookmarkRowView: View {
    let bookmark: Bookmark
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Favicon placeholder / icon
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.prismPurple.opacity(0.15))
                        .frame(width: 22, height: 22)
                    Text(String(bookmark.title.prefix(1)).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.prismPurple)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(bookmark.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(bookmark.host)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AddBookmarkSheet

struct AddBookmarkSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject var bookmarkStore: BookmarkStore

    @State private var title: String = ""
    @State private var url: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Bookmark")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Title")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextField("Bookmark title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("URL")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextField("https://example.com", text: $url)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    bookmarkStore.add(title: title, url: url)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(url.isEmpty)
                .buttonStyle(.borderedProminent)
                .tint(.prismPurple)
            }
        }
        .padding(24)
        .frame(width: 340)
        .onAppear {
            title = browserState.activeTab?.title ?? ""
            url = browserState.activeTab?.displayURL ?? ""
        }
    }
}

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
