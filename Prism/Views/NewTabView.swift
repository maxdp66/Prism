import SwiftUI

// MARK: - NewTabView

struct NewTabView: View {

    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject private var settings: BrowserSettings
    @StateObject private var quickLinkStore = QuickLinkStore.shared

    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool

    // Edit state
    @State private var editingLink: QuickLink? = nil
    @State private var showingAddLink = false

    let clearSuggestions: () -> Void

    private var searchPlaceholder: String {
        "Search \(settings.searchEngine.rawValue) or enter a URL"
    }

    var body: some View {
        ZStack {
            PrismBackground()
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo / Wordmark
                PrismTitleView()

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    TextField(searchPlaceholder, text: $searchText)
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
                    HStack {
                        Text("QUICK ACCESS")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.5)

                        Spacer()

                        // Add button
                        Button(action: { showingAddLink = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .frame(width: 20, height: 20)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Add Quick Link")
                    }
                    .frame(maxWidth: 580, alignment: .leading)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                        spacing: 10
                    ) {
                        ForEach(quickLinkStore.quickLinks) { link in
                            QuickLinkTile(
                                title: link.title,
                                url: link.url,
                                link: link
                            ) {
                                clearSuggestions()
                                browserState.activeTab?.navigate(to: link.url)
                                // Clear focused tab to show tab display instead of address bar
                                browserState.focusedTabId = nil
                            } onEdit: { linkToEdit in
                                editingLink = linkToEdit
                            }
                        }
                    }
                    .frame(maxWidth: 580)
                }

                Spacer()
                Spacer()
            }
            .padding()
            .sheet(item: $editingLink) { link in
                QuickLinkEditView(
                    link: link,
                    onSave: { newTitle, newURL in
                        quickLinkStore.update(link, title: newTitle, url: newURL)
                    },
                    onDelete: {
                        quickLinkStore.remove(link)
                    },
                    onCancel: {}
                )
            }
            .sheet(isPresented: $showingAddLink) {
                QuickLinkAddView(
                    onSave: { title, url in
                        quickLinkStore.add(title: title, url: url)
                    },
                    onCancel: {}
                )
            }
        }
        .onAppear {
            // Focus after first render — .task preferred over DispatchQueue.asyncAfter
            Task { @MainActor in
                searchFocused = true
            }
        }
    }

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        clearSuggestions()
        searchFocused = false
        browserState.activeTab?.navigate(to: query)
        // Clear focused tab to show tab display instead of address bar
        browserState.focusedTabId = nil
        searchText = ""
    }
}

// MARK: - QuickLinkTile

struct QuickLinkTile: View {
    let title: String
    let url: String
    let link: QuickLink?
    let action: () -> Void
    let onEdit: (QuickLink) -> Void

    @State private var isHovered = false
    @State private var faviconImage: NSImage?
    @State private var isLoading = false
    @State private var showContextMenu = false
    @State private var isEditing = false
    @State private var longPressTimer: Timer? = nil
    @State private var isLongPressing = false

    private var domain: String {
        URL(string: url)?.host ?? url
    }

    var body: some View {
        ZStack {
            // Button for normal click - handles navigation
            Button(action: action) {
                VStack(spacing: 8) {
                    ZStack {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .progressViewStyle(.circular)
                                    .tint(.white.opacity(0.5))
                            } else if let image = faviconImage {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Image(systemName: "globe")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }
                        }
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(isHovered ? 0.22 : 0.14))
                        )

                        // Edit indicator on hover (not shown during long press)
                        if isHovered && !isLongPressing {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .position(x: 38, y: 38)
                                .shadow(radius: 2)
                        }
                        
                        // Selection indicator on long press - larger pencil icon
                        if isLongPressing {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.accentColor)
                                .shadow(radius: 4)
                        }
                    }

                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    Group {
                        if isLongPressing {
                            // Selected state during long press
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial.opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 2)
                                )
                                .shadow(color: .accentColor.opacity(0.4), radius: 12)
                        } else {
                            // Normal or hover state
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial.opacity(isHovered ? 0.5 : 0.25))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.white.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
                                )
                        }
                    }
                )
                .scaleEffect(isLongPressing ? 0.95 : (isHovered ? 1.03 : 1.0))
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
                .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isLongPressing)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                // Only update hover state if not in the process of opening edit sheet
                if !isEditing {
                    isHovered = hovering
                }
            }
            .onAppear {
                loadFavicon()
            }
            .contextMenu {
                if let link = link {
                    Button {
                        onEdit(link)
                    } label: {
                        Label("Edit Name & URL", systemImage: "pencil")
                    }
                }
            }
            
            // Invisible overlay for long press detection (doesn't block button clicks)
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            // Start long press timer on mouse down if not already running
                            if longPressTimer == nil && !isEditing {
                                isLongPressing = true
                                longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in
                                    if let link = link {
                                        // Haptic feedback - trackpad click to indicate edit mode
                                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                                        // Immediately deselect tile visually and prevent hover state from reactivating
                                        isEditing = true
                                        isLongPressing = false
                                        isHovered = false
                                        longPressTimer = nil
                                        onEdit(link)
                                    }
                                }
                            }
                        }
                        .onEnded { _ in
                            // Cancel timer if released before long press duration
                            longPressTimer?.invalidate()
                            longPressTimer = nil
                            isLongPressing = false
                        }
                )
        }
    }

    private func loadFavicon() {
        guard !domain.isEmpty else { return }
        isLoading = true
        
        Task {
            let image = await FaviconCache.shared.fetchFavicon(for: domain)
            await MainActor.run {
                if let image = image {
                    faviconImage = image
                }
                isLoading = false
            }
        }
    }
}

// MARK: - PrismTitleView

struct PrismTitleView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Prism")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .tracking(-1)
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 1.0, green: 0.91, blue: 0.93).opacity(0.65), location: 0.0),
                            .init(color: Color.white.opacity(0.65),                               location: 0.38),
                            .init(color: Color(red: 0.91, green: 0.96, blue: 1.0).opacity(0.65), location: 0.72),
                            .init(color: Color(red: 0.94, green: 0.90, blue: 1.0).opacity(0.65), location: 1.0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .white.opacity(0.55), radius: 12)
                .shadow(color: .white.opacity(0.18), radius: 48)

            Text("Private · Fast · Native")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.38))
                .tracking(4.0)
        }
    }
}

// MARK: - PrismBackground

struct PrismBackground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width

            ZStack {
                // Deep dark base — nearly black with a cool blue-black tint
                Color(red: 0.04, green: 0.04, blue: 0.07)

                // ── White incoming beam ──────────────────────────────────────
                Canvas { ctx, size in
                    let focal = CGPoint(x: size.width * 0.5, y: 0)
                    var beam = Path()
                    beam.move(to: focal)
                    beam.addLine(to: CGPoint(x: 0, y: -size.height * 0.4))
                    beam.addLine(to: CGPoint(x: size.width, y: -size.height * 0.4))
                    beam.closeSubpath()
                    ctx.fill(beam, with: .color(Color.white.opacity(0.06)))
                }
                .blur(radius: 28)

                // ── Spectrum fan ─────────────────────────────────────────────
                Canvas { ctx, size in
                    let focal = CGPoint(x: size.width * 0.5, y: 0)
                    let bottom = size.height * 1.08
                    let fanLeft  = size.width * -0.08
                    let fanRight = size.width *  1.08
                    let fanWidth = fanRight - fanLeft

                    let bands: [(Double, Double, Double, Double)] = [
                        (0.95, 0.20, 0.20, 0.28),
                        (0.98, 0.55, 0.08, 0.22),
                        (0.97, 0.93, 0.12, 0.20),
                        (0.15, 0.82, 0.38, 0.22),
                        (0.18, 0.52, 0.98, 0.28),
                        (0.62, 0.10, 0.96, 0.24),
                    ]

                    let count = Double(bands.count)
                    let slice = fanWidth / count

                    for (i, (r, g, b, a)) in bands.enumerated() {
                        let xL = fanLeft + slice * Double(i) - slice * 0.25
                        let xR = fanLeft + slice * Double(i + 1) + slice * 0.25
                        var ray = Path()
                        ray.move(to: focal)
                        ray.addLine(to: CGPoint(x: xL, y: bottom))
                        ray.addLine(to: CGPoint(x: xR, y: bottom))
                        ray.closeSubpath()
                        ctx.fill(ray, with: .color(Color(red: r, green: g, blue: b).opacity(a)))
                    }
                }
                .blur(radius: 72)

                // ── Secondary inner glow ─────────────────────────────────────
                Canvas { ctx, size in
                    let focal = CGPoint(x: size.width * 0.5, y: 0)
                    let bottom = size.height * 1.08
                    let fanLeft  = size.width * 0.04
                    let fanRight = size.width * 0.96
                    let fanWidth = fanRight - fanLeft

                    let bands: [(Double, Double, Double)] = [
                        (0.96, 0.22, 0.22),
                        (0.98, 0.58, 0.10),
                        (0.97, 0.94, 0.14),
                        (0.16, 0.84, 0.40),
                        (0.20, 0.54, 0.98),
                        (0.64, 0.12, 0.97),
                    ]

                    let count  = Double(bands.count)
                    let slice  = fanWidth / count

                    for (i, (r, g, b)) in bands.enumerated() {
                        let xL = fanLeft + slice * Double(i)
                        let xR = fanLeft + slice * Double(i + 1)
                        var ray = Path()
                        ray.move(to: focal)
                        ray.addLine(to: CGPoint(x: xL, y: bottom))
                        ray.addLine(to: CGPoint(x: xR, y: bottom))
                        ray.closeSubpath()
                        ctx.fill(ray, with: .color(Color(red: r, green: g, blue: b).opacity(0.10)))
                    }
                }
                .blur(radius: 28)

                // ── Focal bloom ───────────────────────────────────────────────
                RadialGradient(
                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.04), .clear],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: w * 0.28
                )

                // ── Vignette ──────────────────────────────────────────────────
                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.55)],
                    center: .center,
                    startRadius: w * 0.3,
                    endRadius: w * 0.85
                )
            }
        }
        // Rasterize once so subsequent parent recomputes don't redraw the canvas layers.
        .drawingGroup()
    }
}