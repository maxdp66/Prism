import SwiftUI

// MARK: - NewTabView

struct NewTabView: View {

    @EnvironmentObject var browserState: BrowserState

    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool

    // Quick-access tiles
    private let quickLinks: [(title: String, url: String, icon: String)] = [
        ("GitHub",       "https://github.com",                   "chevron.left.forwardslash.chevron.right"),
        ("YouTube",      "https://youtube.com",                  "play.rectangle.fill"),
        ("Hacker News",  "https://news.ycombinator.com",         "newspaper.fill"),
        ("Wikipedia",    "https://wikipedia.org",                "book.fill"),
        ("DuckDuckGo",   "https://duckduckgo.com",               "magnifyingglass"),
        ("Reddit",       "https://reddit.com",                   "bubble.left.and.bubble.right.fill"),
        ("Twitter/X",    "https://x.com",                        "bird.fill"),
        ("Anthropic",    "https://anthropic.com",                "sparkles"),
    ]

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                stops: [
                    .init(color: Color(red: 88/255,  green: 28/255,  blue: 135/255), location: 0.0),
                    .init(color: Color(red: 109/255, green: 40/255,  blue: 217/255), location: 0.25),
                    .init(color: Color(red: 37/255,  green: 99/255,  blue: 235/255), location: 0.6),
                    .init(color: Color(red: 6/255,   green: 182/255, blue: 212/255), location: 1.0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle animated overlay orbs
            GeometryReader { geo in
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: -geo.size.width * 0.15, y: -geo.size.height * 0.1)
                    .blur(radius: 60)

                Circle()
                    .fill(Color.cyan.opacity(0.08))
                    .frame(width: geo.size.width * 0.45)
                    .offset(x: geo.size.width * 0.55, y: geo.size.height * 0.5)
                    .blur(radius: 80)
            }

            VStack(spacing: 40) {
                Spacer()

                // Logo / Wordmark
                VStack(spacing: 8) {
                    Text("Prism")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(white: 0.9)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

                    Text("Private · Fast · Native")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(1.5)
                }

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    TextField("Search DuckDuckGo or enter a URL", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .focused($searchFocused)
                        .onSubmit { performSearch() }
                        .tint(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        )
                )
                .frame(maxWidth: 580)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)

                // Quick-access grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("QUICK ACCESS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(1.5)
                        .frame(maxWidth: 580, alignment: .leading)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                        spacing: 10
                    ) {
                        ForEach(quickLinks, id: \.url) { link in
                            QuickLinkTile(
                                title: link.title,
                                icon: link.icon,
                                url: link.url
                            ) {
                                browserState.activeTab?.navigate(to: link.url)
                            }
                        }
                    }
                    .frame(maxWidth: 580)
                }

                Spacer()
                Spacer()
            }
            .padding()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                searchFocused = true
            }
        }
    }

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        browserState.activeTab?.navigate(to: query)
        searchText = ""
    }
}

// MARK: - QuickLinkTile

struct QuickLinkTile: View {
    let title: String
    let icon: String
    let url: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(isHovered ? 0.22 : 0.14))
                    )

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial.opacity(isHovered ? 0.5 : 0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
