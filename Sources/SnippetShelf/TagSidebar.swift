import SwiftUI
import SnippetCore

struct TagSidebar: View {
    @EnvironmentObject private var store: SnippetStore
    @AppStorage("tagsExpanded") private var tagsExpanded = true
    let onNew: (UUID?) -> Void
    let onEdit: (SnippetTag) -> Void
    let onDelete: (SnippetTag) -> Void
    var onSelect: ((LibraryScope) -> Void)? = nil

    var body: some View {
        List(selection: Binding<LibraryScope?>(
            get: { store.scope }, set: { if let value = $0 { store.scope = value } }
        )) {
            Section("Library") {
                scopeRow("All Snippets", icon: "tray.full", scope: .all)
                scopeRow("Favorites", icon: "star", scope: .favorites)
                scopeRow("Untagged", icon: "tag.slash", scope: .untagged)
                scopeRow("Word of the Day", icon: "character.book.closed", scope: .wordOfDay, showsCount: false)
            }
            Section("System") {
                ForEach(SystemGroup.allCases) { group in
                    scopeRow(group.title, icon: group.icon, scope: .system(group))
                }
            }
            Section {
                if tagsExpanded {
                    OutlineGroup(store.index.tree, id: \.libraryScope, children: \.children) { node in
                        scopeRow(node.tag.name, icon: "folder", scope: node.libraryScope)
                        .contextMenu {
                            Button("New Sub-tag…") { onNew(node.id) }.disabled(!store.canEdit)
                            Button("Rename or Move…") { onEdit(node.tag) }.disabled(!store.canEdit)
                            Button("Delete Tag…", role: .destructive) { onDelete(node.tag) }.disabled(!store.canEdit)
                        }
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
                        Image(systemName: "plus").foregroundStyle(LibraryAppearance.icon)
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
        .scrollContentBackground(.hidden)
        .snippetScrollbars()
    }

    private func scopeRow(_ title: String, icon: String, scope: LibraryScope, showsCount: Bool = true) -> some View {
        Group {
            if let onSelect {
                // Popovers do not reliably activate native List selection. Use
                // explicit actions there, including reselecting the current tag.
                Button { onSelect(scope) } label: {
                    scopeLabel(title, icon: icon, scope: scope, showsCount: showsCount)
                }.buttonStyle(.plain)
            } else {
                scopeLabel(title, icon: icon, scope: scope, showsCount: showsCount)
            }
        }.tag(scope)
            .listRowBackground(RowSelectionBackground(isSelected: store.scope == scope))
    }

    private func scopeLabel(_ title: String, icon: String, scope: LibraryScope, showsCount: Bool) -> some View {
        HStack {
            Label { Text(title) } icon: { SidebarSymbol(name: icon) }.lineLimit(1)
            Spacer()
            if showsCount {
                Text("\(store.snippetCount(in: scope))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity).contentShape(Rectangle())
    }
}

// Compact navigation retains every destination; the tag tree opens on demand.
struct CompactSidebar: View {
    @EnvironmentObject private var store: SnippetStore
    @State private var showingTags = false
    let onNew: (UUID?) -> Void
    let onEdit: (SnippetTag) -> Void
    let onDelete: (SnippetTag) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                destination("All Snippets", icon: "tray.full", scope: .all)
                destination("Favorites", icon: "star", scope: .favorites)
                destination("Untagged", icon: "tag.slash", scope: .untagged)
                destination("Word of the Day", icon: "character.book.closed", scope: .wordOfDay)
                Divider().padding(.vertical, 8)
                ForEach(SystemGroup.allCases) { group in
                    destination(group.title, icon: group.icon, scope: .system(group))
                }
                Divider().padding(.vertical, 8)
                Button { showingTags.toggle() } label: {
                    SidebarSymbol(name: "ellipsis").frame(width: 40, height: 36)
                        .background(RowSelectionBackground(isSelected: tagSelected, horizontalInset: 0))
                        .padding(2).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Tags").accessibilityLabel("Tags")
                .popover(isPresented: $showingTags, attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) {
                    TagSidebar(onNew: { showingTags = false; onNew($0) },
                               onEdit: { showingTags = false; onEdit($0) },
                               onDelete: { showingTags = false; onDelete($0) },
                               onSelect: { scope in
                                   store.scope = scope
                                   showingTags = false
                               })
                        .frame(width: 260, height: 440)
                        .onChange(of: store.scope) { _ in showingTags = false }
                }
            }.padding(.horizontal, 10).padding(.vertical, 12)
        }.snippetScrollbars()
    }

    private var tagSelected: Bool {
        if case .tag = store.scope { return true }
        return false
    }

    private func destination(_ title: String, icon: String, scope: LibraryScope) -> some View {
        Button { store.scope = scope } label: {
            SidebarSymbol(name: icon).frame(width: 40, height: 36)
                .background(RowSelectionBackground(isSelected: store.scope == scope, horizontalInset: 0))
                .padding(2).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title).accessibilityLabel(title)
        .accessibilityAddTraits(store.scope == scope ? .isSelected : [])
    }
}

// Share symbol rendering/color across native list rows and the compact rail.
private struct SidebarSymbol: View {
    let name: String
    var body: some View {
        Image(systemName: name).symbolRenderingMode(.monochrome).foregroundStyle(LibraryAppearance.icon)
    }
}

// OutlineGroup supplies implicit row identities. They must match List's selection
// type; UUID identities cannot select a LibraryScope, even with an inner .tag.
private extension TagNode {
    var libraryScope: LibraryScope { .tag(id) }
}
