import XCTest
import AppKit
@testable import SnippetShelf

final class NativeMenuCompatibilityTests: XCTestCase {
    @MainActor
    func testCleanupUsesNativeActionsRatherThanEnglishTitlesAndIsIdempotent() {
        let menu = NSMenu(title: "Bearbeiten")
        let target = NSObject()
        let nativeEmoji = NSMenuItem(title: "Emoji und Symbole", action: NSSelectorFromString("orderFrontCharacterPalette:"), keyEquivalent: "")
        let front = NSMenuItem(title: "Alle nach vorne bringen", action: NSSelectorFromString("arrangeInFront:"), keyEquivalent: "")
        let customEmoji = NSMenuItem(title: "Emoji & Symbols", action: NSSelectorFromString("appEmoji:"), keyEquivalent: "")
        let dictation = NSMenuItem(title: "Diktat starten", action: NSSelectorFromString("startDictation:"), keyEquivalent: "")
        [nativeEmoji, front, customEmoji, dictation].forEach(menu.addItem)
        for _ in 0..<2 {
            NativeMenuCompatibility.normalize(menu, dictationTarget: target,
                                              dictationAction: NSSelectorFromString("appDictation:"))
        }
        XCTAssertEqual(menu.items, [customEmoji, dictation])
        XCTAssertTrue(dictation.target === target)
        XCTAssertEqual(dictation.action, NSSelectorFromString("appDictation:"))
    }

    @MainActor
    func testOnlyAppQuickMenuIsRecognizedAndMarkerSurvivesTitleChanges() {
        let unrelated = NSMenu(title: "Edit")
        XCTAssertFalse(NativeMenuCompatibility.isQuickMenu(unrelated))
        let quick = NSMenu(title: "")
        let marker = NSMenuItem(title: NativeMenuCompatibility.openLibraryTitle, action: nil, keyEquivalent: "")
        quick.addItem(marker)
        XCTAssertTrue(NativeMenuCompatibility.isQuickMenu(quick))
        marker.title = "Changed label"
        XCTAssertTrue(NativeMenuCompatibility.isQuickMenu(quick))
    }
    @MainActor
    func testMainQueueObserverDeliversSynchronouslyAndUnregistersOnRelease() {
        let name = Notification.Name("SnippetShelfTests.observerLifetime")
        var deliveries = 0
        var observation: MainActorNotification? = MainActorNotification(name) { _ in
            XCTAssertTrue(Thread.isMainThread)
            deliveries += 1
        }
        NotificationCenter.default.post(name: name, object: nil)
        XCTAssertEqual(deliveries, 1)
        withExtendedLifetime(observation) {}
        observation = nil
        NotificationCenter.default.post(name: name, object: nil)
        XCTAssertEqual(deliveries, 1)
    }

    @MainActor
    func testLateNativeInsertionAndActionChangeAreRemovedOnlyFromMainMenu() async {
        let main = NSMenu(title: "Main")
        let edit = NSMenu(title: "Bearbeiten")
        let parent = NSMenuItem(title: "Bearbeiten", action: nil, keyEquivalent: "")
        parent.submenu = edit
        main.addItem(parent)
        let custom = NSMenuItem(title: "Emoji & Symbols", action: NSSelectorFromString("appEmoji:"), keyEquivalent: " ")
        edit.addItem(custom)
        let target = NSObject()
        let monitor = NativeMenuMutationMonitor(root: { main }) { menu in
            NativeMenuCompatibility.normalize(menu, dictationTarget: target,
                                              dictationAction: NSSelectorFromString("appDictation:"))
        }
        // Simulate AppKit inserting after menu-open normalization has finished.
        edit.addItem(NSMenuItem(title: "Emoji und Symbole", action: NSSelectorFromString("orderFrontCharacterPalette:"), keyEquivalent: ""))
        XCTAssertEqual(edit.items, [custom])
        let lateAction = NSMenuItem(title: "System item", action: nil, keyEquivalent: "")
        edit.addItem(lateAction)
        lateAction.action = NSSelectorFromString("orderFrontCharacterPalette:")
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        XCTAssertEqual(edit.items, [custom])
        // Context/status menus belong to other owners and must remain untouched.
        let unrelated = NSMenu(title: "Context")
        let native = NSMenuItem(title: "Emoji", action: NSSelectorFromString("orderFrontCharacterPalette:"), keyEquivalent: "")
        unrelated.addItem(native)
        XCTAssertEqual(unrelated.items, [native])
        withExtendedLifetime(monitor) {}
    }

    @MainActor
    func testMenuMutationMonitorUnregistersWithoutRetainingItsOwner() {
        let menu = NSMenu(title: "Main")
        var deliveries = 0
        var monitor: NativeMenuMutationMonitor? = NativeMenuMutationMonitor(root: { menu }) { _ in deliveries += 1 }
        menu.addItem(NSMenuItem(title: "One", action: nil, keyEquivalent: ""))
        XCTAssertGreaterThan(deliveries, 0)
        let previous = deliveries
        withExtendedLifetime(monitor) {}
        monitor = nil
        menu.addItem(NSMenuItem(title: "Two", action: nil, keyEquivalent: ""))
        XCTAssertEqual(deliveries, previous)
    }

}
