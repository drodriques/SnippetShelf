import AppKit
import XCTest
import SwiftUI
@testable import SnippetShelf

final class ScrollAppearanceTests: XCTestCase {
    @MainActor
    func testStylingPreservesNativeScrollerConfigurationAndIsIdempotent() {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.scrollerStyle = .legacy
        scroll.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 800))
        scroll.tile()
        let vertical = scroll.verticalScroller!
        vertical.isEnabled = true
        vertical.doubleValue = 0.4
        vertical.knobProportion = 0.25
        let proportion = vertical.knobProportion
        PanelScroller.apply(to: scroll)
        XCTAssertFalse(scroll.drawsBackground)
        XCTAssertFalse(scroll.contentView.drawsBackground)
        XCTAssertTrue(scroll.verticalScroller is PanelScroller)
        XCTAssertTrue(scroll.verticalScroller!.isEnabled)
        XCTAssertTrue(scroll.horizontalScroller is PanelScroller)
        XCTAssertEqual(scroll.verticalScroller!.scrollerStyle, .legacy)
        XCTAssertEqual(scroll.verticalScroller!.doubleValue, 0.4, accuracy: 0.001)
        XCTAssertEqual(scroll.verticalScroller!.knobProportion, proportion, accuracy: 0.001)
        XCTAssertTrue(scroll.verticalScroller!.target as? NSScrollView === scroll)
        let styled = scroll.verticalScroller
        PanelScroller.apply(to: scroll)
        XCTAssertTrue(styled === scroll.verticalScroller)
        XCTAssertTrue(PanelScroller.isCompatibleWithOverlayScrollers)
    }
    @MainActor
    func testSeparateSwiftUIScrollSurfacesReceiveTheSharedStyle() async {
        let host = NSHostingController(rootView: VStack {
            ScrollView { Text(String(repeating: "First surface\n", count: 100)) }
                .snippetScrollbars()
            ScrollView { Text(String(repeating: "Second surface\n", count: 100)) }
                .snippetScrollbars()
            List { Text("Selectable row").tag(1) }.snippetScrollbars()
        })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentViewController = host
        window.setContentSize(NSSize(width: 400, height: 400))
        defer { window.contentViewController = nil }
        window.contentView?.layoutSubtreeIfNeeded()
        // Let representable attachment and its coalesced main-queue styling finish.
        try? await Task.sleep(for: .milliseconds(100))
        func scrollViews(in view: NSView) -> [NSScrollView] {
            (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
        }
        let surfaces = scrollViews(in: host.view)
        XCTAssertEqual(surfaces.count, 3)
        let table = surfaces.compactMap { $0.documentView as? NSTableView }.first
        XCTAssertNotNil(table)
        XCTAssertEqual(table?.selectionHighlightStyle, NSTableView.SelectionHighlightStyle.none)
        table?.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        XCTAssertEqual(table?.selectedRow, 0)
        for surface in surfaces {
            XCTAssertTrue(surface.verticalScroller is PanelScroller)
            XCTAssertFalse(surface.drawsBackground)
        }
    }

}
