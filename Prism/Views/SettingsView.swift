import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {

    @EnvironmentObject private var settings: BrowserSettings
    @StateObject private var quickLinkStore = QuickLinkStore.shared

    @State private var showingAddLink = false
    @State private var editingLink: QuickLink? = nil

    var body: some View {
        Form {
            // MARK: General
            Section("General") {
                Picker("Search Engine", selection: $settings.searchEngine) {
                    ForEach(SearchEngine.allCases) { engine in
                        Text(engine.rawValue).tag(engine)
                    }
                }
                .pickerStyle(.menu)

                if settings.searchEngine == .searxng {
                    TextField("SearXNG Instance URL", text: $settings.searxngURL)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(.primary)
                    Text("e.g., searx.org, search.bahai.org, my-instance.example.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                TextField("Homepage URL", text: $settings.homepageURL)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(.primary)
            }

            // MARK: Autocomplete
            Section("Autocomplete") {
                Picker("Provider", selection: $settings.autocompleteProvider) {
                    ForEach(AutocompleteProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.menu)

                if settings.autocompleteProvider == .brave {
                    SecureField("Brave API Key", text: $settings.autocompleteAPIKey)
                        .textFieldStyle(.roundedBorder)
                    Text("Get your free API key at api.search.brave.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // MARK: Privacy
            Section("Privacy & Security") {
                Toggle("Content Blocker", isOn: $settings.contentBlockerEnabled)
                Toggle("JavaScript", isOn: $settings.javascriptEnabled)
            }

            // MARK: Media
            Section("Media & Playback") {
                Toggle("Autoplay", isOn: $settings.autoplayEnabled)
            }

            // MARK: Quick Access
            Section("Quick Access") {
                // Add button
                HStack {
                    Button(action: { showingAddLink = true }) {
                        Label("Add New Link", systemImage: "plus")
                    }

                    Spacer()

                    Button(role: .destructive) {
                        quickLinkStore.resetToDefaults()
                    } label: {
                        Text("Reset to Defaults")
                    }
                    .disabled(quickLinkStore.quickLinks.isEmpty)
                }

                // Quick links list
                if quickLinkStore.quickLinks.isEmpty {
                    Text("No quick links. Add one above!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(quickLinkStore.quickLinks) { link in
                        QuickLinkSettingsRow(
                            link: link,
                            onDelete: {
                                withAnimation {
                                    quickLinkStore.remove(link)
                                }
                            },
                            onEdit: {
                                editingLink = link
                            }
                        )
                    }
                    .onMove { source, destination in
                        withAnimation {
                            quickLinkStore.move(from: source, to: destination)
                        }
                    }
                }
            }

            // MARK: Appearance
            Section("Appearance") {
                Picker("Color Scheme", selection: $settings.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Layout Style")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        ForEach(TabLayoutStyle.allCases) { style in
                            LayoutOptionCard(
                                style: style,
                                isSelected: settings.layoutStyle == style
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    settings.layoutStyle = style
                                }
                            }
                        }
                    }
                }

                Toggle("Show Website Name Only in Tabs", isOn: $settings.showWebsiteNameOnly)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 400, minHeight: 300)
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
}

// MARK: - Layout Option Card

struct LayoutOptionCard: View {
    let style: TabLayoutStyle
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.windowBackgroundColor))
                        .frame(width: 85, height: 60)
                        .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)

                    LayoutMiniature(style: style)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
                        .padding(-5)
                )

                Text(style.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovering = hovering }
    }
}

// MARK: - Layout Miniature

struct LayoutMiniature: View {
    let style: TabLayoutStyle

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.1))
                    .padding(2)

                if style == .vertical {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.3))
                        .frame(width: geo.size.width * 0.25)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 2)
                        )
                        .padding([.leading, .top, .bottom], 4)
                } else {
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.accentColor.opacity(0.3))
                            .frame(height: style == .standard ? 12 : 6)
                        Spacer()
                    }
                    .padding(4)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(2)
    }
}
