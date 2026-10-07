import SwiftUI
import AppKit
import SnippetCore

struct LibraryView: View {
    @EnvironmentObject private var store: SnippetStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var query = ""
    @State private var isFullScreen = false
    @State private var snippetColumnFrame = CGRect(x: 0, y: 0, width: 360, height: 0)
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchFocused = false
    @State private var searchExpanded = false
    @State private var searchHasFocus = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            LibraryWindowObserver(isFullScreen: $isFullScreen)
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
                            if geometry.size.width < 420 {
                                Menu {
                                    Button("New Snippet…") { newSnippet() }.keyboardShortcut("n")
                                    Button("New Top-level Tag…") { newTag(nil) }
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

    @ViewBuilder
    private var detailContent: some View {
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

    @ViewBuilder
    private var libraryActions: some View {
        Button { newSnippet() } label: { Label("New Snippet", systemImage: "plus") }.keyboardShortcut("n")
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
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
            .fixedSize()
            .frame(width: 36, height: 36)
            .background(Color.primary.opacity(0.08), in: Circle())
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.12)))
    }

    private var snippetList: some View {
        snippetRows
            .navigationTitle("")
            .navigationSplitViewColumnWidth(min: 360, ideal: 420, max: 640)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    if columnVisibility != .all { sidebarToggle }
                    groupHeading
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
                Button("Find") { openSearch() }
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

    private var searchFieldWidth: CGFloat { min(200, max(120, groupHeaderWidth - 150)) }

    private var groupHeading: some View {
        HStack(spacing: 16) {
            Text(scopeTitle)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(scopeTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            searchControl
                .frame(width: searchFieldWidth, alignment: .trailing)
        }
        .padding(.leading, 12)
        .frame(width: groupHeaderWidth)
    }

    private var sidebarToggle: some View {
        Button {
            columnVisibility = columnVisibility == .doubleColumn ? .all : .doubleColumn
        } label: { Image(systemName: "sidebar.left") }
            .buttonStyle(HeaderActionStyle())
            .accessibilityLabel(columnVisibility == .doubleColumn ? "Show Sidebar" : "Hide Sidebar")
    }

    private let searchControlHeight: CGFloat = 36

    private var searchControl: some View {
        HStack(spacing: 6) {
            if searchExpanded {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                ToolbarSearchTextField(text: $query, requestsFocus: $searchFocused,
                    onFocusChange: { focused in
                        searchHasFocus = focused
                        if !focused {
                            DispatchQueue.main.async {
                                if !searchHasFocus && !searchFocused && query.isEmpty {
                                    searchExpanded = false
                                }
                            }
                        }
                    }, onEscape: {
                        if query.isEmpty {
                            searchExpanded = false
                            searchHasFocus = false
                        } else {
                            searchFocused = true
                            query = ""
                        }
                    })
                    .frame(height: 18)
                if !query.isEmpty {
                    Button { searchFocused = true; query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            } else {
                Button { openSearch() } label: {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search this group")
                .help("Search this group (⌘F)")
            }
        }
        .padding(.horizontal, searchExpanded ? 10 : 8)
        .frame(width: searchExpanded ? searchFieldWidth : searchControlHeight, height: searchControlHeight)
        .overlay(RoundedRectangle(cornerRadius: searchExpanded ? 7 : searchControlHeight / 2)
            .strokeBorder(searchHasFocus ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.12)))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: searchExpanded)
    }

    private func openSearch() {
        searchExpanded = true
        searchFocused = true
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
                                    store.toggleSystemFavorite(item.action)
                                }
                            }
                    }
                }
            }
        }
        .scrollContentBackground(isFullScreen ? .hidden : .automatic)
        .background(isFullScreen ? Color(nsColor: .controlBackgroundColor) : Color.clear)
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

// Toolbar content has a separate hosting view. Focus its native field explicitly
// so Command-F works when the snippet list or detail pane owns the first responder.
private struct ToolbarSearchTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var requestsFocus: Bool
    let onFocusChange: (Bool) -> Void
    let onEscape: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> SearchField {
        let field = SearchField(string: text)
        field.placeholderString = "Search this group"
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.setAccessibilityLabel("Search this group")
        field.delegate = context.coordinator
        field.onAttached = { [weak field, weak coordinator = context.coordinator] in
            guard let field, let coordinator else { return }
            coordinator.focusIfRequested(field)
        }
        return field
    }

    func updateNSView(_ field: SearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        context.coordinator.focusIfRequested(field)
    }

    final class SearchField: NSTextField {
        var onAttached: (() -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil { onAttached?() }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ToolbarSearchTextField
        init(_ parent: ToolbarSearchTextField) { self.parent = parent }
        func focusIfRequested(_ field: NSTextField) {
            guard parent.requestsFocus else { return }
            DispatchQueue.main.async {
                if self.parent.requestsFocus, let window = field.window {
                    window.makeFirstResponder(field)
                    self.parent.requestsFocus = false
                }
            }
        }
        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.onFocusChange(true)
        }
        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            // Clearing a toolbar query can rebuild its hosting view. Let an
            // explicit focus request settle before treating that as focus loss.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.parent.onFocusChange(field.currentEditor() != nil)
            }
        }
        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.cancelOperation(_:)) else { return false }
            parent.onEscape()
            return true
        }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}

// Keep native traffic lights centered on the 52-point column headers. Only a
// transparent sizing item lives in the native toolbar; actions stay in their
// columns so AppKit cannot move them into its overflow menu.
private struct LibraryWindowChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            chrome(content).toolbar(removing: .sidebarToggle)
        } else {
            chrome(content)
        }
    }

    private func chrome(_ content: Content) -> some View {
        content.toolbar {
            ToolbarItem {
                Color.clear.frame(width: 1, height: 36)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

// Observe fullscreen appearance and remove the automatic native sidebar item.
// Column headers own the controls in both windowed and fullscreen modes.
private struct LibraryWindowObserver: NSViewRepresentable {
    @Binding var isFullScreen: Bool
    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onChange = { isFullScreen = $0 }
        return view
    }
    func updateNSView(_ nsView: ObserverView, context: Context) {
        DispatchQueue.main.async { nsView.removeAutomaticSidebarToggle() }
    }
    final class ObserverView: NSView {
        private var observers: [NSObjectProtocol] = []
        var onChange: ((Bool) -> Void)?
        func removeAutomaticSidebarToggle() {
            guard let toolbar = window?.toolbar else { return }
            for index in toolbar.items.indices.reversed()
                where toolbar.items[index].itemIdentifier == .toggleSidebar ||
                      toolbar.items[index].itemIdentifier.rawValue == "com.apple.SwiftUI.navigationSplitView.toggleSidebar" {
                toolbar.removeItem(at: index)
            }
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            guard let window else { return }
            DispatchQueue.main.async { [weak self] in self?.removeAutomaticSidebarToggle() }
            observers.append(NotificationCenter.default.addObserver(
                forName: NSToolbar.willAddItemNotification, object: nil, queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.async { self?.removeAutomaticSidebarToggle() }
            })
            for (name, fullScreen) in [(NSWindow.didEnterFullScreenNotification, true),
                                       (NSWindow.didExitFullScreenNotification, false)] {
                observers.append(NotificationCenter.default.addObserver(
                    forName: name, object: window, queue: .main
                ) { [weak self] _ in
                    self?.onChange?(fullScreen)
                })
            }
        }
        deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    }
}

private struct HeaderActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 36, height: 36)
            .background(Color.primary.opacity(configuration.isPressed ? 0.16 : 0.08), in: Circle())
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.12)))
    }
}

// Measure column bounds in window coordinates for header sizing and dividers.
// Publish after AppKit layout finishes to avoid invalidating its current pass.
private struct WindowFrameReader: NSViewRepresentable {
    let onFrame: (CGRect) -> Void
    func makeNSView(context: Context) -> FrameView {
        let view = FrameView()
        view.onFrame = onFrame
        return view
    }
    func updateNSView(_ view: FrameView, context: Context) {
        view.onFrame = onFrame
        view.reportFrame()
    }
    final class FrameView: NSView {
        var onFrame: ((CGRect) -> Void)?
        private var resizeObserver: NSObjectProtocol?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let resizeObserver { NotificationCenter.default.removeObserver(resizeObserver) }
            guard let window else { return }
            resizeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification, object: window, queue: .main
            ) { [weak self] _ in self?.reportFrame() }
            reportFrame()
        }
        override func layout() { super.layout(); reportFrame() }
        func reportFrame() {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil, self.bounds.width > 0 else { return }
                self.onFrame?(self.convert(self.bounds, to: nil))
            }
        }
        deinit {
            if let resizeObserver { NotificationCenter.default.removeObserver(resizeObserver) }
        }
    }
}
