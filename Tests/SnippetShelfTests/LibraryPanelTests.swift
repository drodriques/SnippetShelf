import XCTest
import SwiftUI
import AppKit
@testable import SnippetShelf

final class LibraryPanelTests: XCTestCase {
    @MainActor
    func testBothNativeDividersResizeWhileProtectingMinimumWidths() {
        let controller = LibraryPanelSplitView<EmptyView, EmptyView, EmptyView>.Controller(
            sidebar: EmptyView(), list: EmptyView(), detail: EmptyView(), expanded: true, onSidebarWidth: { _ in })
        controller.splitView.autosaveName = nil
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1400, height: 600),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentViewController = controller
        window.setContentSize(NSSize(width: 1400, height: 600))
        defer { window.contentViewController = nil }
        window.contentView?.layoutSubtreeIfNeeded()
        controller.splitView.setPosition(280, ofDividerAt: 0)
        controller.splitView.setPosition(780, ofDividerAt: 1)
        window.contentView?.layoutSubtreeIfNeeded()
        XCTAssertEqual(controller.sidebarHost.view.frame.width, 280, accuracy: 1)
        XCTAssertEqual(controller.listHost.view.frame.width, 499, accuracy: 1)
        XCTAssertGreaterThanOrEqual(controller.detailHost.view.frame.width, 360)
        controller.splitView.setPosition(320, ofDividerAt: 0)
        window.contentView?.layoutSubtreeIfNeeded()
        XCTAssertEqual(controller.sidebarHost.view.frame.width, 320, accuracy: 1)
        XCTAssertGreaterThanOrEqual(controller.listHost.view.frame.width, 360)
    }

    @MainActor
    func testCompactRailRestoresExpandedSidebarWidth() {
        let controller = LibraryPanelSplitView<EmptyView, EmptyView, EmptyView>.Controller(
            sidebar: EmptyView(), list: EmptyView(), detail: EmptyView(), expanded: true, onSidebarWidth: { _ in })
        controller.splitView.autosaveName = nil
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1400, height: 600),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentViewController = controller
        window.setContentSize(NSSize(width: 1400, height: 600))
        defer { window.contentViewController = nil }
        window.contentView?.layoutSubtreeIfNeeded()
        controller.splitView.setPosition(290, ofDividerAt: 0)
        controller.setSidebarExpanded(false)
        window.contentView?.layoutSubtreeIfNeeded()
        XCTAssertEqual(controller.sidebarHost.view.frame.width, 64, accuracy: 1)
        controller.setSidebarExpanded(true)
        window.contentView?.layoutSubtreeIfNeeded()
        XCTAssertEqual(controller.sidebarHost.view.frame.width, 290, accuracy: 1)
    }
}
