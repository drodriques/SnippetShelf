import AppKit

/// AppKit/SwiftUI compatibility workarounds live here, outside command state.
/// Match native commands by selectors, independent of the macOS display language.
@MainActor
enum NativeMenuCompatibility {
    static let openLibraryTitle = "Open SnippetShelf…"
    private static let quickMenuItemID = NSUserInterfaceItemIdentifier("SnippetShelf.openLibrary")

    static func isQuickMenu(_ menu: NSMenu) -> Bool {
        if menu.items.contains(where: { $0.identifier == quickMenuItemID }) { return true }
        // SwiftUI does not expose NSMenuItem identifiers. Bootstrap from our own
        // app-owned label once; never match a translated system menu title.
        guard let marker = menu.items.first(where: { $0.title == openLibraryTitle }) else { return false }
        marker.identifier = quickMenuItemID
        return true
    }

    static func normalize(_ menu: NSMenu, dictationTarget: AnyObject, dictationAction: Selector) {
        let removed: Set<Selector> = [NSSelectorFromString("orderFrontCharacterPalette:"),
                                     NSSelectorFromString("arrangeInFront:"),
                                     NSSelectorFromString("alternateArrangeInFront:")]
        for item in menu.items {
            if let submenu = item.submenu {
                normalize(submenu, dictationTarget: dictationTarget, dictationAction: dictationAction)
            }
            if let action = item.action, removed.contains(action) {
                menu.removeItem(item)
            } else if item.action == NSSelectorFromString("startDictation:") {
                item.target = dictationTarget
                item.action = dictationAction
            }
        }
    }
}
