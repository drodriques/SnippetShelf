import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode = AppAppearanceMode.auto.rawValue
    @AppStorage("showMenuBarItem") private var showMenuBarItem = true
    @AppStorage("showCurrentWord") private var showCurrentWord = true

    @AppStorage("backgroundTranslucency") private var translucency = 0.0
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: "gearshape").font(.system(size: 26))
                    .foregroundStyle(LibraryAppearance.icon)
                Text("General").font(.headline)
            }
            .foregroundStyle(LibraryAppearance.accent)
            .frame(maxWidth: .infinity).padding(.top, 12)
            .accessibilityElement(children: .ignore).accessibilityLabel("General settings")
            .accessibilityAddTraits(.isHeader)
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearanceMode) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }.pickerStyle(.segmented)
                    Slider(value: $translucency, in: 0...1, step: 0.05) {
                        Text("Background translucency")
                    } minimumValueLabel: { Text("Opaque") } maximumValueLabel: { Text("Translucent") }
                        .disabled(reduceTransparency)
                    Text(reduceTransparency
                         ? "Reduce Transparency is enabled in macOS. The library uses an opaque background."
                         : "Adjust the library background. Text and controls remain fully opaque.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Menu bar") {
                    Toggle("Show SnippetShelf in the menu bar", isOn: $showMenuBarItem)
                    Toggle("Show current word beside the menu-bar icon", isOn: $showCurrentWord)
                        .disabled(!showMenuBarItem)
                    Text("Hiding SnippetShelf removes both the icon and current word. Use SnippetShelf → Settings… (⌘,) to show them again.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .snippetScrollbars()
        }
        .navigationTitle("General")
        .padding(12)
        .frame(width: 520, height: 480)
    }
}
