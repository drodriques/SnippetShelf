import SwiftUI
import SnippetCore

struct TagSidebar: View {
    @EnvironmentObject private var store: SnippetStore
    @State private var newTagHovered = false
    let onNew: (UUID?) -> Void
    let onEdit: (SnippetTag) -> Void
    let onDelete: (SnippetTag) -> Void

    var body: some View {
        List(selection: Binding<LibraryScope?>(
            get: { store.scope }, set: { if let value = $0 { store.scope = value } }
        )) {
            Section("Library") {
                scopeRow("All Snippets", icon: "tray.full", scope: .all)
                scopeRow("Favorites", icon: "star", scope: .favorites)
                scopeRow("Untagged", icon: "tag.slash", scope: .untagged)
            }
            Section("System") {
                ForEach(SystemGroup.allCases) { group in
                    scopeRow(group.title, icon: group.icon, scope: .system(group))
                }
            }
            Section("Tags") {
                OutlineGroup(store.library.tree(), children: \.children) { node in
                    scopeRow(node.tag.name, icon: "folder", scope: .tag(node.id))
                        .contextMenu {
                            Button("New Sub-tag…") { onNew(node.id) }
                            Button("Rename or Move…") { onEdit(node.tag) }
                            Button("Delete Tag…", role: .destructive) { onDelete(node.tag) }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button { onNew(nil) } label: {
                Label("New Tag…", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.primary.opacity(newTagHovered ? 0.06 : 0),
                                in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.borderless)
            .onHover { newTagHovered = $0 }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .navigationTitle("SnippetShelf")
        .navigationSplitViewColumnWidth(min: 200, ideal: 230)
    }

    private func scopeRow(_ title: String, icon: String, scope: LibraryScope) -> some View {
        HStack {
            Label(title, systemImage: icon).lineLimit(1)
            Spacer()
            Text("\((store.library.filtered(scope: scope).count + store.systemItems(in: scope).count))")
                .font(.caption).foregroundStyle(.secondary)
        }.tag(scope)
    }
}
