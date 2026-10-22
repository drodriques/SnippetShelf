import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("showMenuBarItem") private var showMenuBarItem = true
    @AppStorage("showCurrentWord") private var showCurrentWord = true

    var body: some View {
        TabView {
            Form {
                Section("Menu bar") {
                    Toggle("Show SnippetShelf in the menu bar", isOn: $showMenuBarItem)
                    Toggle("Show current word beside the menu-bar icon", isOn: $showCurrentWord)
                        .disabled(!showMenuBarItem)
                    Text("Hiding SnippetShelf removes both the icon and current word. Use SnippetShelf → Settings… (⌘,) to show them again.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }
        }
        .padding(12)
        .frame(width: 500, height: 300)
    }
}
