import AppKit

/// A small template rendering of the app's shelf and three snippet cards.
/// macOS tints template images for the current menu bar appearance.
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()

            // Only the exposed edges of rear cards are drawn, avoiding overlaps.
            let rearCards = NSBezierPath()
            rearCards.move(to: NSPoint(x: 4, y: 5))
            rearCards.line(to: NSPoint(x: 2.5, y: 13))
            rearCards.curve(to: NSPoint(x: 3.25, y: 14),
                            controlPoint1: NSPoint(x: 2.4, y: 13.6),
                            controlPoint2: NSPoint(x: 2.7, y: 13.9))
            rearCards.line(to: NSPoint(x: 6, y: 14.5))
            rearCards.move(to: NSPoint(x: 12, y: 14.5))
            rearCards.line(to: NSPoint(x: 14.75, y: 14))
            rearCards.curve(to: NSPoint(x: 15.5, y: 13),
                            controlPoint1: NSPoint(x: 15.3, y: 13.9),
                            controlPoint2: NSPoint(x: 15.6, y: 13.6))
            rearCards.line(to: NSPoint(x: 14, y: 5))
            rearCards.lineWidth = 1
            rearCards.lineJoinStyle = .round
            rearCards.stroke()

            let centerCard = NSBezierPath(roundedRect: NSRect(x: 6, y: 4, width: 6, height: 12),
                                         xRadius: 1, yRadius: 1)
            centerCard.lineWidth = 1
            centerCard.stroke()

            let text = NSBezierPath()
            for y in [11.5, 9.0] {
                text.move(to: NSPoint(x: 7.5, y: y))
                text.line(to: NSPoint(x: 10.5, y: y))
            }
            text.lineWidth = 1
            text.lineCapStyle = .round
            text.stroke()

            let shelf = NSBezierPath(roundedRect: NSRect(x: 1, y: 2, width: 16, height: 3.5),
                                    xRadius: 1, yRadius: 1)
            shelf.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "SnippetShelf"
        return image
    }()
}
