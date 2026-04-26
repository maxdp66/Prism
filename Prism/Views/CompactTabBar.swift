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

    private var activeTab: BrowserTab? {
        browserState.tabs.first { $0.id == browserState.activeTabId }
    }

    var body: some View {
        HStack(spacing: 6) {
            // Leading spacer for traffic lights
            Color.clear
                .frame(width: 76)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    // Force view re-evaluation when any tab's properties change
                    // The tabUpdateCounter increments whenever any tab publishes a change
                    let _ = browserState.tabUpdateCounter
                    
                    ForEach(browserState.tabs, id: \.id) { tab in
                        CompactTabItem(
                            tab: tab,

                            barFrame: $barFrame,
                            suggestions: $suggestions,
                            suggestionsHeight: $suggestionsHeight,
                            selectedSuggestionIndex: $selectedSuggestionIndex,
                            onFocus: {
                                browserState.focusedTabId = tab.id
                            },
                            onBlur: {
                                browserState.focusedTabId = nil
                            }
                        )
                        .environmentObject(browserState)
                        .environmentObject(bookmarkStore)
                        .environmentObject(settings)
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .center)))
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
                }
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: browserState.activeTabId)
            }
        }
        .background(WindowAccessor())
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.top, 7)
        .padding(.bottom, 7)
        .overlay(
            // Loading progress bar
            GeometryReader { geometry in
                if let activeTab = activeTab, activeTab.isLoading {
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: geometry.size.width * activeTab.estimatedProgress, height: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .offset(y: geometry.size.height - 2)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 0, height: 2)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: activeTab?.isLoading ?? false)
            .animation(.easeInOut(duration: 0.3), value: activeTab?.estimatedProgress ?? 0)
        )
        .gesture(DragGesture().onChanged { _ in }) // Prevent window dragging
    }
}
