import SwiftUI
import AppKit

// MARK: - TabBarView

struct TabBarView: View {

    @EnvironmentObject var browserState: BrowserState

    var body: some View {
        HStack(spacing: 0) {
            // Drag region / traffic-light spacer
            Color.clear
                .frame(width: 76)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(browserState.tabs) { tab in
                            TabPillView(tab: tab)
                                .environmentObject(browserState)
                                .id(tab.id)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
                .onChange(of: browserState.activeTabId) { id in
                    if let id {
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }

            Spacer(minLength: 4)

            // Add tab button
            Button {
                browserState.addNewTab(url: nil)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .help("New Tab (⌘T)")
            .padding(.trailing, 8)
        }
        .frame(height: 38)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
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
    @State private var showClose = false

    private var isActive: Bool {
        browserState.activeTabId == tab.id
    }

    var body: some View {
        HStack(spacing: 5) {
            // Favicon / spinner
            Group {
                if tab.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                } else if let favicon = tab.favicon {
                    Image(nsImage: favicon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                        .cornerRadius(2)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 14)
                }
            }

            // Title
            Text(tab.title)
                .font(.system(size: 12, weight: isActive ? .medium : .regular))
                .foregroundColor(isActive ? .primary : .secondary)
                .lineLimit(1)
                .frame(maxWidth: 150, alignment: .leading)

            // Close button
            Button {
                browserState.closeTab(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 14, height: 14)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(showClose ? 0.12 : 0))
                    )
            }
            .buttonStyle(.plain)
            .opacity(isHovered || isActive ? 1 : 0)
            .onHover { showClose = $0 }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive
                      ? Color(NSColor.controlBackgroundColor)
                      : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
                .shadow(
                    color: isActive ? Color.black.opacity(0.12) : .clear,
                    radius: 2, x: 0, y: 1
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isActive ? Color.prismPurple.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { browserState.activateTab(tab) }
        .onHover { isHovered = $0 }
        .help(tab.displayURL.isEmpty ? "New Tab" : tab.displayURL)
    }
}
