import SwiftUI
import AppKit

// MARK: - TabPillView

struct TabPillView: View {

    @ObservedObject var tab: BrowserTab
    @EnvironmentObject var browserState: BrowserState

    @State private var isHovered = false

    private var isActive: Bool {
        browserState.activeTabId == tab.id
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ZStack {
                    if isHovered || isActive {
                        Button {
                            browserState.closeTab(tab)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.primary.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .frame(width: 16, height: 16)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(Circle())
                    } else {
                        leadingIcon
                    }
                }
                .frame(width: 16, height: 16)

                HStack(spacing: 0) {
                    Spacer()
                    Text(tab.title.isEmpty ? "New Tab" : tab.title)
                        .font(.system(size: 11, weight: isActive ? .medium : .regular))
                        .foregroundColor(isActive ? .primary : .secondary)
                        .lineLimit(1)
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 20)
        .background(
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.15))
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.gray.opacity(0.1))
                } else {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.clear)
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture { browserState.activateTab(tab) }
        .onHover { isHovered = $0 }
        .help(tab.displayURL.isEmpty ? "New Tab" : tab.displayURL)
        .frame(minWidth: 100, maxWidth: 200)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if tab.isLoading {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 12, height: 12)
        } else if let favicon = tab.favicon {
            Image(nsImage: favicon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        } else {
            Image(systemName: "globe")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}
