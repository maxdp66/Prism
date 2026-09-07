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

    // Track tab positions for drag and drop
    @State private var tabPositions: [UUID: CGRect] = [:]
    @State private var tabBarBounds: CGRect = .zero
    /// Per-tab slide displacement — local state so drag frames don't re-render the whole app.
    @State private var tabDisplacements: [UUID: CGFloat] = [:]

    var body: some View {
        HStack(spacing: 6) {
            // Leading spacer for traffic lights — pure-AppKit drag handle moves the window
            WindowDragHandle()
                .frame(width: 76)

            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        // Force view re-evaluation when any tab's properties change
                        // The tabUpdateCounter increments whenever any tab publishes a change
                        let _ = browserState.tabUpdateCounter

                        ForEach(browserState.tabs, id: \.id) { tab in
                            CompactTabItem(
                                tab: tab,
                                displacement: tabDisplacements[tab.id] ?? 0,
                                barFrame: $barFrame,
                                suggestions: $suggestions,
                                suggestionsHeight: $suggestionsHeight,
                                selectedSuggestionIndex: $selectedSuggestionIndex,
                                onFocus: {
                                    browserState.focusedTabId = tab.id
                                },
                                onBlur: {
                                    browserState.focusedTabId = nil
                                },
                                onDragUpdate: { offset in
                                    updateInsertionAndDisplacements(offset: offset)
                                },
                                onDragEnd: {
                                    tabDisplacements = [:]
                                }
                            )
                            .environmentObject(browserState)
                            .environmentObject(bookmarkStore)
                            .environmentObject(settings)
                            .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .center)))
                            .zIndex(browserState.draggingTabId == tab.id ? 1 : 0)
                            // Animate displacement slides with spring; dragged tab is not in tabDisplacements
                            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: tabDisplacements[tab.id])
                            // Track position of each tab
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear {
                                            updateTabPosition(id: tab.id, frame: geo.frame(in: .named("tabBarCoordinateSpace")))
                                        }
                                        .onChange(of: geo.frame(in: .named("tabBarCoordinateSpace"))) { _, newFrame in
                                            updateTabPosition(id: tab.id, frame: newFrame)
                                        }
                                }
                            )
                        }

                        // New Tab Button - inline with tabs, inside scroll view
                        Button {
                            browserState.addNewTabAndGetId(url: nil)
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

                        // Trailing empty-space drag handle — drags the window from space after tabs
                        WindowDragHandle()
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .frame(minWidth: geometry.size.width, alignment: .leading)
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: browserState.activeTabId)
                }
                .coordinateSpace(name: "tabBarCoordinateSpace")
                .onAppear {
                    tabBarBounds = geometry.frame(in: .named("tabBarCoordinateSpace"))
                }
                .onChange(of: geometry.frame(in: .named("tabBarCoordinateSpace"))) { _, newFrame in
                    tabBarBounds = newFrame
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(WindowAccessor())
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.top, 7)
        .padding(.bottom, 7)
        .coordinateSpace(name: "tabBarCoordinateSpace")
    }

    private func updateTabPosition(id: UUID, frame: CGRect) {
        tabPositions[id] = frame
    }

    /// Called on every drag frame via callback — updates tabDisplacements ONLY when the
    /// insertion index changes (discrete event), so the spring animation fires once per
    /// tab-boundary crossing rather than 60 times per second.
    private func updateInsertionAndDisplacements(offset: CGFloat) {
        guard let draggingId = browserState.draggingTabId,
              let originalIndex = browserState.dragOriginalIndex else { return }

        let draggedMidX = (tabPositions[draggingId]?.midX ?? 0) + offset

        // Compute insertion index from actual measured tab centers
        var newIndex = originalIndex
        for (tabIdx, tab) in browserState.tabs.enumerated() {
            guard tab.id != draggingId,
                  let center = tabPositions[tab.id].map({ $0.midX }) else { continue }
            if offset > 0 && tabIdx > originalIndex && draggedMidX > center {
                newIndex = max(newIndex, tabIdx)
            } else if offset < 0 && tabIdx < originalIndex && draggedMidX < center {
                newIndex = min(newIndex, tabIdx)
            }
        }
        let insertionIndex: Int
        if offset > 0 && newIndex > originalIndex {
            insertionIndex = newIndex + 1
        } else if offset < 0 && newIndex < originalIndex {
            insertionIndex = newIndex
        } else {
            insertionIndex = originalIndex
        }

        // Early-exit: displacement already correct for this insertion index
        guard insertionIndex != browserState.dragInsertionIndex else { return }
        browserState.dragInsertionIndex = insertionIndex

        // Compute per-tab displacement so surrounding tabs slide aside.
        // No withAnimation wrapper — each tab item carries a .animation(.spring, value:)
        // declarative modifier that handles the interpolation exactly once per change.
        let draggedWidth: CGFloat = (tabPositions[draggingId]?.width ?? 80.0) + 3.0
        var displacements: [UUID: CGFloat] = [:]
        for (i, tab) in browserState.tabs.enumerated() {
            guard tab.id != draggingId else { continue }
            var shift: CGFloat = 0.0
            if insertionIndex > originalIndex && i > originalIndex && i < insertionIndex {
                shift = -draggedWidth
            } else if insertionIndex < originalIndex && i >= insertionIndex && i < originalIndex {
                shift = draggedWidth
            }
            if shift != 0.0 { displacements[tab.id] = shift }
        }
        tabDisplacements = displacements
    }

    /// Get the center position for each tab for drag calculations
    func getTabCenters() -> [(id: UUID, center: CGFloat)] {
        return tabPositions.map { id, frame in
            (id: id, center: frame.midX)
        }.sorted { $0.center < $1.center }
    }
}