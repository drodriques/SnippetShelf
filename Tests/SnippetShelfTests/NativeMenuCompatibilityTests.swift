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

}
