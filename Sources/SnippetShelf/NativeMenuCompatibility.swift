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

/// Native entries can arrive after beginTracking's deferred pass. Observe only
/// item insertion/action changes in the main menu, including while tracking.
/// Normalize synchronously so late native items never reach the visible menu.
@MainActor
final class NativeMenuMutationMonitor {
    private var observers: [MainActorNotification] = []
    private var normalizing = false
    private var refreshQueued = false

    init(root: @escaping @MainActor () -> NSMenu?,
         normalize: @escaping @MainActor (NSMenu) -> Void) {
        for name in [NSMenu.didAddItemNotification, NSMenu.didChangeItemNotification] {
            observers.append(MainActorNotification(name) { [weak self] notification in
                guard let self, !self.normalizing,
                      let menu = notification.object as? NSMenu, let rootMenu = root() else { return }
                var ancestor: NSMenu? = menu
                while let current = ancestor, current !== rootMenu { ancestor = current.supermenu }
                guard ancestor === rootMenu else { return }
                self.normalizing = true
                defer { self.normalizing = false }
                normalize(menu)
                if name == NSMenu.didAddItemNotification, !self.refreshQueued {
                    // AppKit may set the action after insertion without emitting
                    // didChangeItem. One coalesced pass catches that assignment.
                    self.refreshQueued = true
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.refreshQueued = false
                        guard let rootMenu = root() else { return }
                        self.normalizing = true
                        defer { self.normalizing = false }
                        normalize(rootMenu)
                    }
                }
            })
        }
    }
}
