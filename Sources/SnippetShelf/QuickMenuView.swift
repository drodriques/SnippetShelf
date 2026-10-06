import SwiftUI
import AppKit
import SnippetCore

struct QuickMenuView: View {
    @EnvironmentObject private var store: SnippetStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let favorites = store.library.filtered(scope: .favorites)
        let systemFavorites = store.systemItems(in: .favorites)
        if !favorites.isEmpty || !systemFavorites.isEmpty {
            Text("Favorites")
            SnippetMenuItems(snippets: favorites)
            SystemMenuItems(items: systemFavorites)
            Divider()
        }
        Menu("System") {
            ForEach(SystemGroup.allCases) { group in
                Menu(group.title) {
                    let items = store.systemItems(in: .system(group))
                    if items.isEmpty {
                        Text(group == .network ? (store.networkMessage ?? "No active network address") : "Unavailable")
                    } else {
                        SystemMenuItems(items: items)
                    }
                }
            }
        }
        Divider()
        if store.snippets.isEmpty {
            Text("No saved snippets yet")
        } else {
            Menu("All Snippets") { SnippetMenuItems(snippets: store.library.filtered(scope: .all)) }
            let untagged = store.library.filtered(scope: .untagged)
            if !untagged.isEmpty {
                Menu("Untagged") { SnippetMenuItems(snippets: untagged) }
            }
        }
        ForEach(store.library.children(of: nil)) { tag in TagQuickMenu(tag: tag) }
        Divider()
        if let notice = store.notice { Text(notice) }
        if store.errorMessage != nil { Text("Open SnippetShelf to review an error") }
        Button("Open SnippetShelf…") { showLibrary() }
        Button("New Snippet…") {
            store.scope = .all
            store.wantsNewSnippet = true
            showLibrary()
        }
        Divider()
        Button("Quit SnippetShelf") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
    }

    private func showLibrary() {
        openWindow(id: "library")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

private struct SnippetMenuItems: View {
    @EnvironmentObject private var store: SnippetStore
    let snippets: [Snippet]

    var body: some View {
        ForEach(snippets) { snippet in
            Button { store.copy(snippet) } label: {
                Label(snippet.title, systemImage: snippet.isFavorite ? "star.fill" : "doc.text")
            }
        }
    }
}

private struct TagQuickMenu: View {
    @EnvironmentObject private var store: SnippetStore
    let tag: SnippetTag

    var body: some View {
        Menu {
            // All in This Group follows the same inclusive parent filtering as the sidebar.
            let inclusive = store.library.filtered(scope: .tag(tag.id))
            if !inclusive.isEmpty {
                Menu("All in This Group") { SnippetMenuItems(snippets: inclusive) }
                Divider()
            }
            let direct = Snippet.matching(store.snippets.filter { $0.tagIDs.contains(tag.id) }, query: "")
            SnippetMenuItems(snippets: direct)
            ForEach(store.library.children(of: tag.id)) { child in TagQuickMenu(tag: child) }
            if inclusive.isEmpty && store.library.children(of: tag.id).isEmpty { Text("No snippets") }
        } label: { Label(tag.name, systemImage: "folder") }
    }
}

private struct SystemMenuItems: View {
    @EnvironmentObject private var store: SnippetStore
    let items: [SystemItem]

    var body: some View {
        ForEach(items) { item in
            Button { store.copySystem(item.action) } label: {
                Label(menuTitle(item), systemImage: store.library.systemFavorites.contains(item.action)
                    ? "star.fill" : item.group.icon)
            }.disabled(!item.isAvailable).help(item.value ?? item.unavailableReason ?? "Unavailable")
        }
    }

    private func menuTitle(_ item: SystemItem) -> String {
        guard item.group == .network else { return "Copy \(item.title)" }
        let values = item.value?.components(separatedBy: "\n") ?? []
        let preview = values.count > 1 ? "\(values.count) addresses" : (values.first ?? "Unavailable")
        return "Copy \(item.title) — \(preview)"
    }
}
