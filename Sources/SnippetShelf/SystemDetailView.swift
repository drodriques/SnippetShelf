import SwiftUI
import SnippetCore

struct SystemDetailView: View {
    @EnvironmentObject private var store: SnippetStore
    let item: SystemItem

    private var favorite: Bool { store.library.systemFavorites.contains(item.action) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Text(item.title).font(.largeTitle.bold()).textSelection(.enabled)
                Spacer()
                Button { Task { await store.toggleSystemFavorite(item.action) } } label: {
                    Image(systemName: favorite ? "star.fill" : "star")
                        .foregroundStyle(favorite ? Color.orange : Color.secondary)
                }.buttonStyle(.borderless)
                    .help(favorite ? "Remove from Favorites" : "Add to Favorites")
                    .accessibilityLabel(favorite ? "Remove from Favorites" : "Add to Favorites")
            }
            Label("Built-in · refreshed when copied", systemImage: item.group.icon)
                .font(.callout).foregroundStyle(.secondary)
            ScrollView {
                Text(item.value ?? item.unavailableReason ?? "Unavailable")
                    .font(.system(.title3, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            }.snippetScrollbars().background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            Text(item.explanation).font(.callout).foregroundStyle(.secondary)
            HStack {
                Button { store.copySystem(item.action) } label: {
                    Label(item.copyLabel, systemImage: "doc.on.doc")
                }.disabled(!item.isAvailable).keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Refresh") { store.refreshSystem() }
                Spacer()
            }
        }.padding(24).onAppear { store.requestSystemRefresh() }
    }
}
