import SwiftUI
import AppKit
import SnippetCore

struct LibraryView: View {
    @EnvironmentObject private var store: SnippetStore
    @EnvironmentObject private var words: WordStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var libraryWindowVisible = true
    @Environment(\.colorScheme) private var colorScheme
    @State private var query = ""
    @State private var isFullScreen = false
    @State private var snippetColumnFrame = CGRect(x: 0, y: 0, width: 360, height: 0)
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchFocused = false
    @State private var draft: Snippet?
    @State private var tagDraft: SnippetTag?
    @State private var pendingDelete: Snippet?
    @State private var pendingTagDelete: SnippetTag?

    private var visibleSnippets: [Snippet] { store.filteredSnippets(scope: store.scope, query: query) }
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
        case .wordOfDay: return "Word of the Day"
        case .tag(let id): return store.tagPath(for: id)
        case .system(let group): return group.title
        }
    }

    private var dividerColor: Color { Color(white: colorScheme == .dark ? 0.24 : 0.8) }

    var body: some View {
        VStack(spacing: 0) {
            navigation
            dividerColor.frame(height: 1)
            statusBar.fixedSize(horizontal: false, vertical: true)
        }
        .frame(minWidth: 960, minHeight: 480)
        .ignoresSafeArea(.container, edges: .top)
        .background {
            LibraryWindowObserver(isFullScreen: $isFullScreen, isVisible: $libraryWindowVisible)
                .frame(width: 0, height: 0)
        }
        .background {
            Button("Toggle Full Screen") { NSApp.mainWindow?.toggleFullScreen(nil) }
                .keyboardShortcut("f", modifiers: [.control, .command])
                .hidden()
                .accessibilityHidden(true)
        }
    }

    private var navigation: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            TagSidebar(matchesContentBackground: isFullScreen, onNew: newTag, onEdit: { tagDraft = $0 }, onDelete: { pendingTagDelete = $0 })
                .overlay(alignment: .trailing) {
                    dividerColor.frame(width: 1).offset(x: 1)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    HStack { Spacer(); sidebarToggle }
                        .padding(.horizontal, 12)
                        .frame(height: 52)
                }
                .ignoresSafeArea(.container, edges: .top)
        } content: {
            snippetList
        } detail: {
            detailContent
                .frame(minWidth: 360)
                .safeAreaInset(edge: .top, spacing: 0) {
                    GeometryReader { geometry in
                        HStack(spacing: 10) {
                            Spacer()
                            if store.scope == .wordOfDay {
                                Button { words.draft = WordDraft(entry: nil) } label: {
                                    Label("New Word", systemImage: "plus")
                                }.keyboardShortcut("n").disabled(!words.canEdit)
                            } else if geometry.size.width < 420 {
                                Menu {
                                    Button("New Snippet…") { newSnippet() }.keyboardShortcut("n").disabled(!store.canEdit)
                                    Button("New Top-level Tag…") { newTag(nil) }.disabled(!store.canEdit)
                                } label: { Image(systemName: "ellipsis").accessibilityLabel("More actions") }
                                .menuStyle(.borderlessButton)
                                .menuIndicator(.hidden)
                                .fixedSize()
                                .frame(width: 36, height: 36)
                                .background(Color.primary.opacity(0.08), in: Circle())
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.12)))
                            } else {
                                libraryActions
                            }
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(HeaderActionStyle())
                        .padding(.horizontal, 12)
                        .frame(height: 52)
                    }.frame(height: 52)
                }
                .ignoresSafeArea(.container, edges: .top)
        }
        .overlay(alignment: .leading) {
            if columnVisibility != .detailOnly {
                ZStack(alignment: .leading) {
                    if columnVisibility == .all {
                        dividerColor.frame(width: 1)
                            .offset(x: snippetColumnFrame.minX - 1)
                    }
                    dividerColor.frame(width: 1)
                        .offset(x: snippetColumnFrame.maxX)
                }
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .top)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .modifier(LibraryWindowChrome())
        .toolbarBackground(.hidden, for: .windowToolbar)
        .sheet(item: $words.draft) { draft in
            WordEditor(entry: draft.entry)
        }
        .sheet(item: $draft) { snippet in
            SnippetEditor(snippet: snippet) { await store.save($0) }.environmentObject(store)
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
                if let snippet = pendingDelete { Task { await store.delete(snippet) } }
                pendingDelete = nil
            }
        } message: { Text("\(pendingDelete?.title ?? "This snippet") will be permanently removed.") }
        .alert("Delete this tag and its sub-tags?", isPresented: Binding(
            get: { pendingTagDelete != nil }, set: { if !$0 { pendingTagDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingTagDelete = nil }
            Button("Delete Tags", role: .destructive) {
                if let tag = pendingTagDelete { Task { await store.deleteTag(tag) } }
                pendingTagDelete = nil
            }
        } message: {
            if let tag = pendingTagDelete {
                Text("Remove \(store.tagPath(for: tag.id)) and \(store.library.subtreeIDs(of: tag.id).count - 1) sub-tags? All snippets will be kept, along with their other tags.")
            }
        }
        .onChange(of: store.scope) { _ in
            store.selection = nil
            if store.scope == .wordOfDay, words.selectedID == nil { words.selectedID = words.library.currentID }
            query = ""
            if shouldRefreshSystemPreviews { store.requestSystemRefresh() }
        }
        .onChange(of: query) { _ in clearHiddenSelection() }
        .onChange(of: store.library) { _ in clearHiddenSelection() }
        .onChange(of: words.library) { _ in
            if store.scope == .wordOfDay { query = "" }
        }
        .onChange(of: store.systemItems) { _ in clearHiddenSelection() }
        .task(id: shouldRefreshSystemPreviews) {
            guard shouldRefreshSystemPreviews else { return }
            store.requestSystemRefresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                guard !Task.isCancelled else { return }
                store.requestSystemRefresh()
            }
        }
        .onChange(of: store.wantsNewSnippet) { requested in if requested { consumeNewSnippetRequest() } }
        .onAppear { consumeNewSnippetRequest() }
    }

    private var shouldRefreshSystemPreviews: Bool {
        guard scenePhase == .active, libraryWindowVisible else { return false }
        switch store.scope {
        case .system: return true
        case .favorites: return !store.library.systemFavorites.isEmpty
        default: return false
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if store.scope == .wordOfDay {
            WordDetailView()
        } else if let snippet = selected {
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

    @ViewBuilder
    private var libraryActions: some View {
        Button { newSnippet() } label: { Label("New Snippet", systemImage: "plus") }.keyboardShortcut("n").disabled(!store.canEdit)
        Menu {
            Button("New Top-level Tag…") { newTag(nil) }
            if let tag = selectedTag {
                Button("New Sub-tag…") { newTag(tag.id) }
                Divider()
                Button("Rename or Move Tag…") { tagDraft = tag }
                Button("Delete Tag…", role: .destructive) { pendingTagDelete = tag }
            }
        } label: {
            Image(systemName: "folder.badge.gearshape")
                .accessibilityLabel("Manage Tags")
        }
            .disabled(!store.canEdit)
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
            .fixedSize()
            .frame(width: 36, height: 36)
            .background(Color.primary.opacity(0.08), in: Circle())
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.12)))
    }

    private var snippetList: some View {
        Group {
            if store.scope == .wordOfDay {
                WordListView(query: query)
                    .background(Color(nsColor: .controlBackgroundColor))
            } else {
                snippetRows
            }
        }
            .navigationTitle("")
            .navigationSplitViewColumnWidth(min: 360, ideal: 420, max: 640)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    if columnVisibility != .all { sidebarToggle }
                    LibrarySearchHeader(title: scopeTitle, width: groupHeaderWidth, query: $query,
                                        requestsFocus: $searchFocused)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .padding(.leading, windowControlsInset)
                .frame(height: 52)
            }
            .ignoresSafeArea(.container, edges: .top)
            .background {
                WindowFrameReader { frame in
                    if abs(snippetColumnFrame.minX - frame.minX) > 0.5 ||
                       abs(snippetColumnFrame.width - frame.width) > 0.5 {
                        snippetColumnFrame = frame
                    }
                }
            }
            .background {
                Button("Find") { searchFocused = true }
                    .keyboardShortcut("f", modifiers: .command)
                    .hidden()
                    .accessibilityHidden(true)
            }
    }

    // Reserve the native traffic-light area when the sidebar is hidden.
    private var windowControlsInset: CGFloat {
        columnVisibility != .all && !isFullScreen ? 90 : 0
    }

    private var groupHeaderWidth: CGFloat {
        max(120, snippetColumnFrame.width - 24 - (columnVisibility == .all ? 0 : 42) - windowControlsInset)
    }

    private var sidebarToggle: some View {
        Button {
            columnVisibility = columnVisibility == .doubleColumn ? .all : .doubleColumn
        } label: { Image(systemName: "sidebar.left") }
            .buttonStyle(HeaderActionStyle())
            .accessibilityLabel(columnVisibility == .doubleColumn ? "Show Sidebar" : "Hide Sidebar")
    }

    private var snippetRows: some View {
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
                                    Task { await store.toggleSystemFavorite(item.action) }
                                }
                            }
                    }
                }
            }
        }
        .scrollContentBackground(isFullScreen ? .hidden : .automatic)
        .background(isFullScreen ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        .overlay {
            if store.loadState == .idle || store.loadState == .loading {
                ProgressView("Loading snippets…")
            } else if visibleCount == 0 {
                VStack(spacing: 10) {
                    Text(emptyMessage).font(.headline)
                    if query.isEmpty {
                        if case .system = store.scope { Button("Refresh") { store.refreshSystem() } }
                        else { Button("Create a Snippet") { newSnippet() }.disabled(!store.canEdit) }
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
                    Button("Retry Loading") { Task { await store.reload() } }
                }
            }
            HStack {
                if store.scope == .wordOfDay {
                    Text("New Word saves your previous word in History.")
                    Spacer()
                    Text("\(words.current == nil ? 0 : 1) current · \(words.history.count) past")
                } else {
                    Text(store.notice ?? "Choose a snippet from the menu bar to copy it instantly.")
                    Spacer()
                    Text("\(visibleCount) shown · \(store.snippets.count) saved")
                }
            }.foregroundStyle(.secondary)
        }.font(.caption).padding(12).background(.bar)
    }

    private func clearHiddenSelection() {
        if store.scope == .wordOfDay,
           let entry = words.library.entries.first(where: { $0.id == words.selectedID }),
           !entry.matches(query) {
            words.selectedID = nil
        }
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
