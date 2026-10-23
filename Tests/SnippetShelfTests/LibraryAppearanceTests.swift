import XCTest
import AppKit
import SwiftUI
@testable import SnippetShelf

final class LibraryAppearanceTests: XCTestCase {
    func testAppearanceChoicesFollowSystemOrResolveExplicitMode() {
        XCTAssertNil(AppAppearanceMode.auto.colorScheme)
        XCTAssertEqual(AppAppearanceMode.light.colorScheme, .light)
        XCTAssertEqual(AppAppearanceMode.dark.colorScheme, .dark)
        XCTAssertEqual(AppAppearanceMode.allCases.map(\.title), ["Auto", "Light", "Dark"])
    }

    func testInvalidPreferencesCannotProduceInvalidMaterialOpacity() {
        XCTAssertEqual(LibraryAppearance.clampedTranslucency(.nan), 0)
        XCTAssertEqual(LibraryAppearance.clampedTranslucency(.infinity), 0)
        XCTAssertEqual(LibraryAppearance.clampedTranslucency(-1), 0)
        XCTAssertEqual(LibraryAppearance.clampedTranslucency(2), 1)
        XCTAssertEqual(LibraryAppearance.clampedTranslucency(0.35), 0.35)
    }
    @MainActor
    func testDecorativeMaterialPassesNativePointerHitsToControls() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        let buttons = [NSButton(title: "Search", target: nil, action: nil),
                       NSButton(title: "Add", target: nil, action: nil)]
        for (index, button) in buttons.enumerated() {
            button.frame = NSRect(x: 20 + index * 130, y: 20, width: 100, height: 40)
            root.addSubview(button)
        }
        // Exercise AppKit's real sibling traversal, including an effect view
        // covering controls, as can occur during hosting/material reordering.
        let material = LibraryMaterialView(frame: root.bounds)
        root.addSubview(material)
        for button in buttons {
            let point = NSPoint(x: button.frame.midX, y: button.frame.midY)
            let hit = root.hitTest(point)
            XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true)
        }
    }

}
