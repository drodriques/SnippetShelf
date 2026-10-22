import SwiftUI
import AppKit

// Toolbar content has a separate hosting view. Focus its native field explicitly
// so Command-F works when the snippet list or detail pane owns the first responder.
struct ToolbarSearchTextField: NSViewRepresentable {
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

    @MainActor
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
