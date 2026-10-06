import SwiftUI
import SnippetCore

struct LibraryView: View {
    @EnvironmentObject private var store: SnippetStore
    @State private var query = ""
    @State private var draft: Snippet?
    @State private var tagDraft: SnippetTag?
    @State private var pendingDelete: Snippet?
    @State private var pendingTagDelete: SnippetTag?

    private var visibleSnippets: [Snippet] { store.library.filtered(scope: store.scope, query: query) }
    private var visibleSystemItems: [SystemItem] { store.systemItems(in: store.scope, query: query) }
    private var visibleCount: Int { visibleSnippets.count + visibleSystemItems.count }
    private var selected: Snippet? {
        guard case .snippet(let id) = store.selection else { return nil }
        return store.snippets.first { $0.id == id }
    }
    private var selectedSystem: SystemItem? {
        guard case .system(let action) = store.selection else { return nil }
        return store.systemItems.first { $0.action == action }
    }
    private var selectedTag: SnippetTag? {
        guard case .tag(let id) = store.scope else { return nil }
        return store.library.tags.first { $0.id == id }
    }
    private var scopeTitle: String {
        switch store.scope {
        case .all: return "All Snippets"
        case .favorites: return "Favorites"
        case .untagged: return "Untagged"
        case .tag(let id): return store.library.path(for: id)
        case .system(let group): return group.title
        }
    }

    var body: some View {
        NavigationSplitView {
            TagSidebar(onNew: newTag, onEdit: { tagDraft = $0 }, onDelete: { pendingTagDelete = $0 })
        } content: {
            snippetList
        } detail: {
            if let snippet = selected {
                SnippetDetailView(snippet: snippet, onEdit: { draft = snippet },
                                  onDelete: { pendingDelete = snippet })
            } else if let item = selectedSystem {
                SystemDetailView(item: item)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.alignleft").font(.system(size: 42)).foregroundStyle(.secondary)
                    Text("Select a snippet").font(.title2.bold())
                    Text("Choose a group, or create a new snippet.").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 960, minHeight: 480)
        .toolbar {
            Button { newSnippet() } label: { Label("New Snippet", systemImage: "plus") }.keyboardShortcut("n")
            Menu {
                Button("New Top-level Tag…") { newTag(nil) }
                if let tag = selectedTag {
                    Button("New Sub-tag…") { newTag(tag.id) }
                    Divider()
                    Button("Rename or Move Tag…") { tagDraft = tag }
                    Button("Delete Tag…", role: .destructive) { pendingTagDelete = tag }
                }
            } label: { Label("Manage Tags", systemImage: "folder.badge.gearshape") }
        }
        .safeAreaInset(edge: .bottom) { statusBar }
        .sheet(item: $draft) { snippet in
            SnippetEditor(snippet: snippet) { store.save($0) }.environmentObject(store)
        }
        .sheet(item: $tagDraft) { tag in
            TagEditor(tag: tag, isExisting: store.library.tags.contains { $0.id == tag.id })
                .environmentObject(store)
        }
        .alert("Delete this snippet?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let snippet = pendingDelete { store.delete(snippet) }
                pendingDelete = nil
            }
        } message: { Text("\(pendingDelete?.title ?? "This snippet") will be permanently removed.") }
        .alert("Delete this tag and its sub-tags?", isPresented: Binding(
            get: { pendingTagDelete != nil }, set: { if !$0 { pendingTagDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingTagDelete = nil }
            Button("Delete Tags", role: .destructive) {
                if let tag = pendingTagDelete { store.deleteTag(tag) }
                pendingTagDelete = nil
            }
        } message: {
            if let tag = pendingTagDelete {
                Text("Remove \(store.library.path(for: tag.id)) and \(store.library.subtreeIDs(of: tag.id).count - 1) sub-tags? All snippets will be kept, along with their other tags.")
            }
        }
        .onChange(of: store.scope) { _ in
            store.selection = nil
            query = ""
            store.refreshSystem()
        }
        .onChange(of: query) { _ in clearHiddenSelection() }
        .onChange(of: store.library) { _ in clearHiddenSelection() }
        .onChange(of: store.systemItems) { _ in clearHiddenSelection() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in store.refreshSystem() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refreshSystem()
        }
        .onChange(of: store.wantsNewSnippet) { requested in if requested { consumeNewSnippetRequest() } }
        .onAppear { store.refreshSystem(); consumeNewSnippetRequest() }
    }

    private var snippetList: some View {
        List(selection: $store.selection) {
            ForEach(visibleSnippets) { snippet in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: snippet.isFavorite ? "star.fill" : "doc.text")
                        .foregroundStyle(snippet.isFavorite ? Color.orange : Color.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snippet.title).font(.headline).lineLimit(1)
                        Text(snippet.content.replacingOccurrences(of: "\n", with: " "))
                            .foregroundStyle(.secondary).lineLimit(2)
                    }
                }.padding(.vertical, 5).tag(LibrarySelection.snippet(snippet.id))
                    .contextMenu {
                        Button("Copy") { store.copy(snippet) }
                        Button("Edit…") { draft = snippet }
                        Button("Delete…", role: .destructive) { pendingDelete = snippet }
                    }
            }
            if !visibleSystemItems.isEmpty {
                Section("Built-in") {
                    ForEach(visibleSystemItems) { item in
                        systemRow(item).tag(LibrarySelection.system(item.action))
                            .contextMenu {
                                Button(item.copyLabel) { store.copySystem(item.action) }
                                    .disabled(!item.isAvailable)
                                Button(store.library.systemFavorites.contains(item.action)
                                    ? "Remove from Favorites" : "Add to Favorites") {
                                    store.toggleSystemFavorite(item.action)
                                }
                            }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search this group")
        .navigationTitle(scopeTitle)
        .navigationSplitViewColumnWidth(min: 230, ideal: 280)
        .overlay {
            if visibleCount == 0 {
                VStack(spacing: 10) {
                    Text(emptyMessage).font(.headline)
                    if query.isEmpty {
                        if case .system = store.scope { Button("Refresh") { store.refreshSystem() } }
                        else { Button("Create a Snippet") { newSnippet() } }
                    }
                }.padding().multilineTextAlignment(.center)
            }
        }
    }

    private var emptyMessage: String {
        if !query.isEmpty { return "No matching items" }
        if case .system(.network) = store.scope { return store.networkMessage ?? "No active network address" }
        if case .system = store.scope { return "System values are unavailable" }
        return "No snippets in this group"
    }

    private func systemRow(_ item: SystemItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: store.library.systemFavorites.contains(item.action) ? "star.fill" : item.group.icon)
                .foregroundStyle(store.library.systemFavorites.contains(item.action) ? Color.orange : Color.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline).lineLimit(2)
                Text(item.value ?? item.unavailableReason ?? "Unavailable")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).lineLimit(2)
            }
        }.padding(.vertical, 5)
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let error = store.errorMessage {
                HStack {
                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                    Spacer()
                    Button("Retry Loading") { store.reload() }
                }
            }
            HStack {
                Text(store.notice ?? "Choose a snippet from the menu bar to copy it instantly.")
                Spacer()
                Text("\(visibleCount) shown · \(store.snippets.count) saved")
            }.foregroundStyle(.secondary)
        }.font(.caption).padding(12).background(.bar)
    }

    private func clearHiddenSelection() {
        switch store.selection {
        case .snippet(let id):
            if !visibleSnippets.contains(where: { $0.id == id }) { store.selection = nil }
        case .system(let action):
            if !visibleSystemItems.contains(where: { $0.action == action }) { store.selection = nil }
        case nil: break
        }
    }
    private func consumeNewSnippetRequest() {
        guard store.wantsNewSnippet else { return }
        newSnippet()
        store.wantsNewSnippet = false
    }
    private func newTag(_ parentID: UUID?) { tagDraft = SnippetTag(name: "", parentID: parentID) }
    private func newSnippet() {
        query = ""
        let ids: Set<UUID>
        if case .tag(let id) = store.scope { ids = [id] } else { ids = [] }
        draft = Snippet(title: "", content: "", isFavorite: store.scope == .favorites, tagIDs: ids)
    }
}
