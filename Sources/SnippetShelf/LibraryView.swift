import SwiftUI
import AppKit
import SnippetCore

struct LibraryView: View {
    @EnvironmentObject private var store: SnippetStore
    @EnvironmentObject private var words: WordStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var libraryWindowVisible = true
    @State private var toolbarOrigin: CGFloat = 98
    @State private var sidebarWidth: CGFloat = 230
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage("sidebarExpanded") private var sidebarExpanded = true
    @AppStorage("backgroundTranslucency") private var translucency = 0.0
    @State private var query = ""
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

    private var effectiveTranslucency: Double {
        reduceTransparency ? 0 : LibraryAppearance.clampedTranslucency(translucency)
    }

    var body: some View {
        VStack(spacing: 0) {
            navigation
                .background(LibraryAppearance.panel.opacity(1 - effectiveTranslucency * 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(LibraryAppearance.container, lineWidth: 1)
                    .allowsHitTesting(false))
                .padding(.horizontal, 8)
                .padding(.top, 4)
            statusBar.fixedSize(horizontal: false, vertical: true)
        }
        .frame(minWidth: 1000, minHeight: 480)
        .background(LibraryBackground(translucency: effectiveTranslucency))
        .background {
            LibraryWindowObserver(isVisible: $libraryWindowVisible, allowsTranslucency: effectiveTranslucency > 0)
                .frame(width: 0, height: 0)
        }
        .focusedSceneValue(\.sidebarExpansion, $sidebarExpanded)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 12) {
                    Button { sidebarExpanded.toggle() } label: { Image(systemName: "sidebar.left").foregroundStyle(LibraryAppearance.icon) }
                        .help(sidebarExpanded ? "Contract Sidebar" : "Expand Sidebar")
                        .accessibilityLabel(sidebarExpanded ? "Contract Sidebar" : "Expand Sidebar")
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.65))
                        .frame(width: 1, height: 20)
                        .accessibilityHidden(true)
                }
                // Align with the measured sidebar edge plus the container inset.
                // Read only the native toolbar origin, never a self-dependent width.
                .frame(width: sidebarExpanded ? max(44, 8 + sidebarWidth + 1 - toolbarOrigin) : 44, alignment: .trailing)
                .background(ToolbarOriginReader { toolbarOrigin = $0 }.allowsHitTesting(false))
            }
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                ToolbarSpacer(.flexible)
            } else {
                ToolbarItem(placement: .principal) { Spacer() }
            }
            #else
            ToolbarItem(placement: .principal) { Spacer() }
            #endif
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    LibrarySettingsLink()
                    Button { openWindow(id: "help") } label: {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                } label: { Image(systemName: "ellipsis").foregroundStyle(LibraryAppearance.icon) }
                    .help("App menu")
                    .accessibilityLabel("App menu")
                    .menuIndicator(.hidden)
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .background {
            Button("Toggle Full Screen") { NSApp.mainWindow?.toggleFullScreen(nil) }
                .keyboardShortcut("f", modifiers: [.control, .command])
                .hidden()
                .accessibilityHidden(true)
        }
    }

    private var navigation: some View {
        LibraryPanelSplitView(
            sidebar: sidebarContent.environmentObject(store).appAppearance(),
            list: snippetList.environmentObject(store).environmentObject(words).appAppearance(),
            detail: detailPanel.environmentObject(store).environmentObject(words).appAppearance(),
            sidebarExpanded: sidebarExpanded,
            onSidebarWidth: { sidebarWidth = $0 })
        .sheet(item: $words.draft) { draft in
            WordEditor(entry: draft.entry).appAppearance()
        }
        .sheet(item: $draft) { snippet in
            SnippetEditor(snippet: snippet) { await store.save($0) }.environmentObject(store).appAppearance()
        }
        .sheet(item: $tagDraft) { tag in
            TagEditor(tag: tag, isExisting: store.library.tags.contains { $0.id == tag.id })
                .environmentObject(store).appAppearance()
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

    @ViewBuilder
    private var sidebarContent: some View {
        if sidebarExpanded {
            TagSidebar(onNew: newTag, onEdit: { tagDraft = $0 }, onDelete: { pendingTagDelete = $0 })
        } else {
            CompactSidebar(onNew: newTag, onEdit: { tagDraft = $0 }, onDelete: { pendingTagDelete = $0 })
        }
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
            Image(systemName: "folder.badge.gearshape").foregroundStyle(LibraryAppearance.icon)
                .accessibilityLabel("Manage Tags")
        }
            .disabled(!store.canEdit)
            .tint(LibraryAppearance.icon)
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
            .fixedSize()
            .frame(width: 36, height: 36)
            .background(Color.primary.opacity(0.08), in: Circle())
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.12)))
    }

    private var detailPanel: some View {
        VStack(spacing: 0) {
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
                            .menuStyle(.borderlessButton).menuIndicator(.hidden)
                            .fixedSize().frame(width: 36, height: 36)
                            .background(Color.primary.opacity(0.08), in: Circle())
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.12)))
                    } else {
                        libraryActions
                    }
                }
                .labelStyle(.iconOnly).buttonStyle(HeaderActionStyle()).tint(LibraryAppearance.icon)
                .padding(.horizontal, 12).frame(height: 52)
            }.frame(height: 52)
            detailContent.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var snippetList: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                LibrarySearchHeader(title: scopeTitle, width: max(0, geometry.size.width - 16), query: $query,
                                    requestsFocus: $searchFocused)
                    .padding(.horizontal, 8).frame(height: 52)
            }.frame(height: 52)
            Group {
                if store.scope == .wordOfDay { WordListView(query: query) }
                else { snippetRows }
            }
        }
        .background {
            Button("Find") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command).hidden().accessibilityHidden(true)
        }
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
                    .listRowBackground(RowSelectionBackground(isSelected: store.selection == .snippet(snippet.id)))
                    .contextMenu {
                        Button("Copy") { store.copy(snippet) }
                        Button("Edit…") { draft = snippet }
                        Button("Delete…", role: .destructive) { pendingDelete = snippet }
                    }
            }
            if !visibleSystemItems.isEmpty {
                PanelSectionLabel(title: "Built-in")
                ForEach(visibleSystemItems) { item in
                    systemRow(item).tag(LibrarySelection.system(item.action))
                        .listRowBackground(RowSelectionBackground(isSelected: store.selection == .system(item.action)))
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
        .scrollContentBackground(.hidden)
        .snippetScrollbars()
        .overlay {
            if store.loadState == .idle || store.loadState == .loading {
                ProgressView("Loading snippets…")
            } else if visibleCount == 0 {
                VStack(spacing: 10) {
                    Text(emptyMessage).font(.headline)
                    if !query.isEmpty {
                        Button("Clear Search") { query = "" }
                    } else if case .system = store.scope {
                        Button("Refresh") { store.refreshSystem() }
                    } else if selectedTag == nil {
                        Button("Create a Snippet") { newSnippet() }.disabled(!store.canEdit)
                    }
                }.padding().multilineTextAlignment(.center)
            }
        }
    }

    private var emptyMessage: String {
        if !query.isEmpty {
            if case .system = store.scope { return "No matching items" }
            return "No matching snippets"
        }
        if case .tag = store.scope { return "No snippets are associated with this tag yet." }
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
        }.font(.caption).padding(.horizontal, 16).padding(.vertical, 10)
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
