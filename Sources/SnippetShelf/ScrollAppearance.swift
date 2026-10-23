import SwiftUI
import AppKit

// Keep native scrolling, tracking, accessibility and system visibility preferences.
// Only drawing changes: the track reveals its own surface and the thumb is a subtle neutral gray.
final class PanelScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { true }
    override func draw(_ dirtyRect: NSRect) { drawKnob() }
    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) { }
    override func drawKnob() {
        let knob = rect(for: .knob).insetBy(dx: 2, dy: 2)
        guard knob.width > 0, knob.height > 0 else { return }
        NSColor.gray.withAlphaComponent(0.25).setFill()
        NSBezierPath(roundedRect: knob, xRadius: min(knob.width, knob.height) / 2,
                     yRadius: min(knob.width, knob.height) / 2).fill()
    }

    static func apply(to scrollView: NSScrollView) {
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        if let old = scrollView.verticalScroller, !(old is PanelScroller) {
            scrollView.verticalScroller = replacement(for: old)
        }
        if let old = scrollView.horizontalScroller, !(old is PanelScroller) {
            scrollView.horizontalScroller = replacement(for: old)
        }
    }
    private static func replacement(for original: NSScroller) -> PanelScroller {
        let scroller = PanelScroller(frame: original.frame)
        scroller.isEnabled = original.isEnabled
        scroller.controlSize = original.controlSize
        scroller.scrollerStyle = original.scrollerStyle
        scroller.knobStyle = original.knobStyle
        scroller.doubleValue = original.doubleValue
        scroller.knobProportion = original.knobProportion
        return scroller
    }
}

extension View {
    func snippetScrollbars() -> some View {
        background(ScrollAppearanceProbe().allowsHitTesting(false).accessibilityHidden(true))
    }
}

private struct ScrollAppearanceProbe: NSViewRepresentable {
    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ view: Probe, context: Context) { view.scheduleStyling() }

    final class Probe: NSView {
        private let styledScrollViews = NSHashTable<NSScrollView>.weakObjects()
        private var queued = false
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            styledScrollViews.removeAllObjects()
            scheduleStyling()
        }
        override func layout() {
            super.layout()
            if styledScrollViews.allObjects.isEmpty { scheduleStyling() }
        }
        func scheduleStyling() {
            guard window != nil, !queued else { return }
            queued = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.queued = false
                let cached = self.styledScrollViews.allObjects
                if !cached.isEmpty {
                    cached.forEach { self.style($0) }
                    return
                }
                // SwiftUI can place a background beside, rather than inside,
                // its native scroll view. Search the nearest containing subtree.
                var ancestor = self.superview
                while let current = ancestor {
                    let scrolls = self.scrollViews(in: current)
                    if !scrolls.isEmpty {
                        for scroll in scrolls {
                            self.styledScrollViews.add(scroll)
                            self.style(scroll)
                        }
                        return
                    }
                    ancestor = current.superview
                }
            }
        }
        private func style(_ scroll: NSScrollView) {
            PanelScroller.apply(to: scroll)
            // SwiftUI's macOS List ignores tint for native blue selection.
            // Its rows provide the shared purple background while AppKit keeps
            // selection state, keyboard navigation and accessibility semantics.
            if let table = scroll.documentView as? NSTableView {
                table.selectionHighlightStyle = .none
            }
        }
        private func scrollViews(in view: NSView) -> [NSScrollView] {
            if let scroll = view as? NSScrollView { return [scroll] }
            return view.subviews.flatMap { scrollViews(in: $0) }
        }
    }
}
