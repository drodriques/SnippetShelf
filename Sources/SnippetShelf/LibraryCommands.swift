import SwiftUI
import AppKit
import SnippetCore

// Edit commands follow the native text responder, including search and sheets.
@MainActor
private final class TextCommandState: NSObject, ObservableObject, NSMenuItemValidation {
    struct Availability: Equatable {
        var editing = false
        var selection = false
        var canPaste = false
        var canUndo = false
        var canRedo = false
    }
    @Published private(set) var availability = Availability()
    private var observers: [MainActorNotification] = []
    private var refreshQueued = false
    private var normalizeQueued = false
    private var menuMonitor: NativeMenuMutationMonitor?

    override init() {
        super.init()
        menuMonitor = NativeMenuMutationMonitor(root: { NSApp.mainMenu }) { [weak self] menu in
            self?.normalizeTextCommands(in: menu)
        }
        for name in [NSApplication.didUpdateNotification, NSText.didChangeNotification,
                     NSText.didBeginEditingNotification, NSText.didEndEditingNotification,
                     NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification, NSMenu.didBeginTrackingNotification] {
            observers.append(MainActorNotification(name) {
                [weak self] _ in
                if name == NSMenu.didBeginTrackingNotification {
                    self?.refresh()
                    if let menu = NSApp.mainMenu { self?.normalizeTextCommands(in: menu) }
                    // A single deferred pass catches native items inserted as a menu opens.
                    self?.queueRefresh(normalize: true)
                } else {
                    self?.queueRefresh()
                }
            })
        }
    }
    private func queueRefresh(normalize: Bool = false) {
        normalizeQueued = normalizeQueued || normalize
        guard !refreshQueued else { return }
        refreshQueued = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshQueued = false
            self.refresh()
            if self.normalizeQueued, let menu = NSApp.mainMenu {
                self.normalizeTextCommands(in: menu)
            }
            self.normalizeQueued = false
        }
    }

    private var editor: NSTextView? {
        guard let view = NSApp.keyWindow?.firstResponder as? NSTextView, view.isEditable else { return nil }
        return view
    }
    private func refresh() {
        var next = Availability()
        if let editor {
            next.editing = true
            next.selection = editor.selectedRange().length > 0
            next.canPaste = NSPasteboard.general.availableType(from: [.string]) != nil
            next.canUndo = editor.undoManager?.canUndo == true
            next.canRedo = editor.undoManager?.canRedo == true
        }
        if next != availability { availability = next }
    }
    private func normalizeTextCommands(in menu: NSMenu) {
        NativeMenuCompatibility.normalize(menu, dictationTarget: self,
                                          dictationAction: #selector(startDictation(_:)))
    }
    @objc private func startDictation(_ sender: Any?) {
        guard let editor else { return }
        NSApp.sendAction(NSSelectorFromString("startDictation:"), to: editor, from: sender)
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool { editor != nil }
    func perform(_ action: String) {
        guard let editor else { return }
        switch action {
        case "undo:": editor.undoManager?.undo()
        case "redo:": editor.undoManager?.redo()
        default: NSApp.sendAction(NSSelectorFromString(action), to: editor, from: nil)
        }
        refresh()
    }
    func emoji() {
        guard editor != nil else { return }
        NSApp.orderFrontCharacterPalette(nil)
    }
}

struct LibraryCommands: Commands {
    @StateObject private var text = TextCommandState()
    @Environment(\.openWindow) private var openWindow
    @FocusedBinding(\.sidebarExpansion) private var sidebarExpanded
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About SnippetShelf") {
                let info = Bundle.main.infoDictionary ?? [:]
                let release = info["SnippetShelfReleaseVersion"] as? String
                    ?? info["CFBundleShortVersionString"] as? String ?? "Unknown"
                NSApp.orderFrontStandardAboutPanel(options: [
                    .applicationVersion: release,
                    .version: info["CFBundleVersion"] as? String ?? ""
                ])
            }
        }
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { text.perform("undo:") }.keyboardShortcut("z")
                .disabled(!text.availability.canUndo)
            Button("Redo") { text.perform("redo:") }.keyboardShortcut("z", modifiers: [.shift, .command])
                .disabled(!text.availability.canRedo)
        }
        CommandGroup(replacing: .pasteboard) {
            Button("Cut") { text.perform("cut:") }.keyboardShortcut("x")
                .disabled(!text.availability.selection)
            Button("Copy") { text.perform("copy:") }.keyboardShortcut("c")
                .disabled(!text.availability.selection)
            Button("Paste") { text.perform("paste:") }.keyboardShortcut("v")
                .disabled(!text.availability.canPaste)
            Button("Delete") { text.perform("delete:") }.disabled(!text.availability.selection)
            Button("Select All") { text.perform("selectAll:") }.keyboardShortcut("a")
                .disabled(!text.availability.editing)
        }
        CommandGroup(replacing: .textEditing) {
            Button("Emoji & Symbols") { text.emoji() }
                .keyboardShortcut(.space, modifiers: [.control, .command])
                .disabled(!text.availability.editing)
        }
        CommandGroup(replacing: .sidebar) {
            Button(sidebarExpanded == false ? "Expand Sidebar" : "Contract Sidebar") {
                sidebarExpanded?.toggle()
            }.keyboardShortcut("s", modifiers: [.control, .command])
                .disabled(sidebarExpanded == nil)
        }
        CommandGroup(replacing: .windowArrangement) { }
        CommandGroup(replacing: .help) {
            Button("SnippetShelf Help") { openWindow(id: "help") }
        }
    }
}
