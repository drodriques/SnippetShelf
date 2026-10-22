import SwiftUI
import SnippetCore

struct TagSidebar: View {
    @EnvironmentObject private var store: SnippetStore
    @State private var settingsHovered = false
    @AppStorage("tagsExpanded") private var tagsExpanded = true
    var matchesContentBackground = false
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
                Label("Word of the Day", systemImage: "character.book.closed").tag(LibraryScope.wordOfDay)
            }
            Section("System") {
                ForEach(SystemGroup.allCases) { group in
                    scopeRow(group.title, icon: group.icon, scope: .system(group))
                }
            }
            Section {
                if tagsExpanded {
                    OutlineGroup(store.index.tree, children: \.children) { node in
                        scopeRow(node.tag.name, icon: "folder", scope: .tag(node.id))
                            .contextMenu {
                                Button("New Sub-tag…") { onNew(node.id) }
                                Button("Rename or Move…") { onEdit(node.tag) }
                                Button("Delete Tag…", role: .destructive) { onDelete(node.tag) }
                            }.disabled(!store.canEdit)
                    }
                }
            } header: {
                HStack(spacing: 0) {
                    Button { tagsExpanded.toggle() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tagsExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .semibold)).frame(width: 12)
                            Text("Tags")
                        }.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tagsExpanded ? "Collapse Tags" : "Expand Tags")
                    Button { onNew(nil) } label: {
                        Image(systemName: "plus")
                            .frame(width: 24, height: 24).contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .disabled(!store.canEdit)
                    .help("New Top-level Tag")
                    .accessibilityLabel("New Top-level Tag")
                    Spacer(minLength: 0)
                }
            }
            .collapsible(false)

        }
        .listStyle(.sidebar)
        .scrollContentBackground(matchesContentBackground ? .hidden : .automatic)
        .background(matchesContentBackground ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if #available(macOS 14.0, *) {
                    SettingsLink { settingsLabel }
                } else {
                    Button {
                        if !NSApp.sendAction(NSSelectorFromString("showSettingsWindow:"), to: nil, from: nil) {
                            NSApp.sendAction(NSSelectorFromString("showPreferencesWindow:"), to: nil, from: nil)
                        }
                    } label: { settingsLabel }
                }
            }
            .buttonStyle(.borderless)
            .onHover { settingsHovered = $0 }
            .help("Settings (⌘,)")
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .navigationTitle("SnippetShelf")
        .navigationSplitViewColumnWidth(min: 200, ideal: 230)
    }

    private var settingsLabel: some View {
        Label("Settings…", systemImage: "gearshape")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.primary.opacity(settingsHovered ? 0.06 : 0),
                        in: RoundedRectangle(cornerRadius: 6))
    }

    private func scopeRow(_ title: String, icon: String, scope: LibraryScope) -> some View {
        HStack {
            Label(title, systemImage: icon).lineLimit(1)
            Spacer()
            Text("\(store.snippetCount(in: scope))")
                .font(.caption).foregroundStyle(.secondary)
        }.tag(scope)
    }
}
