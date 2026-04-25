import SwiftUI
import AppKit

// MARK: - TabBarView

struct TabBarView: View {

    @EnvironmentObject var browserState: BrowserState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Drag region / traffic-light spacer
                Color.clear
                    .frame(width: 76)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(browserState.tabs) { tab in
                                TabPillView(tab: tab)
                                    .environmentObject(browserState)
                                    .id(tab.id)
                            }

                            // Add tab button – sits right next to the last tab
                            Button {
                                browserState.addNewTab(url: nil)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(Color.primary.opacity(0.05))
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("New Tab (⌘T)")
                            .padding(.leading, 4)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                    }
                    .onChange(of: browserState.activeTabId) { id in
                        if let id {
                            withAnimation { proxy.scrollTo(id, anchor: .center) }
                        }
                    }
                }

                Spacer(minLength: 4)
            }
            .frame(height: 24)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
        // Make the tab bar draggable (acts like title bar)
        .overlay(
            Rectangle()
                .fill(Color.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        )
    }
}

// MARK: - TabPillView

struct TabPillView: View {

    @ObservedObject var tab: BrowserTab
    @EnvironmentObject var browserState: BrowserState

    @State private var isHovered = false

    private var isActive: Bool {
        browserState.activeTabId == tab.id
    }

    var body: some View {
        HStack(spacing: 6) {
            // Favicon / spinner
            Group {
                if tab.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                } else if let favicon = tab.favicon {
                    Image(nsImage: favicon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 12, height: 12)
                }
            }

            // Title
            Text(tab.title)
                .font(.system(size: 11, weight: isActive ? .medium : .regular))
                .foregroundColor(isActive ? .primary : .secondary)
                .lineLimit(1)
                .frame(maxWidth: 140, alignment: .leading)

            // Close button
            Button {
                browserState.closeTab(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 12, height: 12)
            }
            .buttonStyle(.plain)
            .opacity(isActive || isHovered ? 0.6 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive
                      ? Color(NSColor.controlBackgroundColor).opacity(0.7)
                      : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { browserState.activateTab(tab) }
        .onHover { isHovered = $0 }
        .help(tab.displayURL.isEmpty ? "New Tab" : tab.displayURL)
    }
}
