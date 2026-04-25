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

                TextField("Homepage URL", text: $settings.homepageURL)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(.primary)
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
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 400, minHeight: 300)
    }
}
