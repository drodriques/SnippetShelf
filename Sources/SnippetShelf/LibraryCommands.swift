import SwiftUI
import AppKit

// Edit commands follow the native text responder, including search and sheets.
private final class TextCommandState: NSObject, ObservableObject, NSMenuItemValidation {
    struct Availability: Equatable {
        var editing = false
        var selection = false
        var canPaste = false
        var canUndo = false
        var canRedo = false
    }
    @Published private(set) var availability = Availability()
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        for name in [NSApplication.didUpdateNotification, NSText.didChangeNotification,
                     NSText.didBeginEditingNotification, NSText.didEndEditingNotification,
                     NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification, NSMenu.didBeginTrackingNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in
                if name == NSMenu.didBeginTrackingNotification { self?.refresh() }
                else { DispatchQueue.main.async { self?.refresh() } }
            })
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
        if let menu = NSApp.mainMenu {
            normalizeTextCommands(in: menu)
        }
    }
    private func normalizeTextCommands(in menu: NSMenu) {
        var sawEmoji = false
        for item in menu.items {
            if let submenu = item.submenu { normalizeTextCommands(in: submenu) }
            if item.action == NSSelectorFromString("orderFrontCharacterPalette:") ||
               item.action == NSSelectorFromString("arrangeInFront:") ||
               item.action == NSSelectorFromString("alternateArrangeInFront:") {
                menu.removeItem(item)
                continue
            }
            if item.title == "Emoji & Symbols" {
                if sawEmoji { menu.removeItem(item) } else { sawEmoji = true }
            }
            if item.title.hasPrefix("Start Dictation") {
                item.target = self
                item.action = #selector(startDictation(_:))
            }
        }
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
    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
}

struct LibraryCommands: Commands {
    @StateObject private var text = TextCommandState()
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
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
        CommandGroup(replacing: .windowArrangement) { }
        CommandGroup(replacing: .help) {
            Button("SnippetShelf Help") { openWindow(id: "help") }
        }
    }
}
