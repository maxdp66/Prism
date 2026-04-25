import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {

    @EnvironmentObject private var settings: BrowserSettings

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

            // MARK: Appearance
            Section("Appearance") {
                Picker("Color Scheme", selection: $settings.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 400, minHeight: 300)
    }
}
