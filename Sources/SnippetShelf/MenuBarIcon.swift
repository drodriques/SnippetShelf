import AppKit

/// An 18-point template rendering of the app's overlapping code cards.
/// macOS tints the monochrome symbol for the current menu bar appearance.
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            func rotated(_ angle: CGFloat, around center: NSPoint, draw: () -> Void) {
                NSGraphicsContext.saveGraphicsState()
                let transform = NSAffineTransform()
                transform.translateX(by: center.x, yBy: center.y)
                transform.rotate(byDegrees: angle)
                transform.translateX(by: -center.x, yBy: -center.y)
                transform.concat()
                draw()
                NSGraphicsContext.restoreGraphicsState()
            }

            rotated(9, around: NSPoint(x: 7, y: 10)) {
                NSColor.black.setStroke()
                let rear = NSBezierPath(roundedRect: NSRect(x: 2, y: 4, width: 10, height: 12),
                                        xRadius: 1.5, yRadius: 1.5)
                rear.lineWidth = 1
                rear.stroke()
                let lines = NSBezierPath()
                for y in [12, 8.5] {
                    lines.move(to: NSPoint(x: 3.5, y: y))
                    lines.line(to: NSPoint(x: 7.5, y: y))
                }
                lines.lineWidth = 1
                lines.lineCapStyle = .round
                lines.stroke()
            }

            rotated(-8, around: NSPoint(x: 10.5, y: 8.5)) {
                let front = NSBezierPath(roundedRect: NSRect(x: 5, y: 2, width: 11, height: 13),
                                         xRadius: 1.5, yRadius: 1.5)
                // Clear rear-card strokes behind the front card, keeping the
                // interior transparent so the system tint works in either mode.
                NSColor.clear.setFill()
                NSGraphicsContext.current?.compositingOperation = .copy
                front.fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
                NSColor.black.setStroke()
                front.lineWidth = 1
                front.stroke()

                let brace = NSBezierPath()
                brace.move(to: NSPoint(x: 8.8, y: 12))
                brace.curve(to: NSPoint(x: 7.6, y: 10.8),
                            controlPoint1: NSPoint(x: 7.6, y: 12),
                            controlPoint2: NSPoint(x: 7.6, y: 11.7))
                brace.curve(to: NSPoint(x: 6.6, y: 8.5),
                            controlPoint1: NSPoint(x: 7.6, y: 9),
                            controlPoint2: NSPoint(x: 7.6, y: 8.5))
                brace.curve(to: NSPoint(x: 7.6, y: 6.2),
                            controlPoint1: NSPoint(x: 7.6, y: 8.5),
                            controlPoint2: NSPoint(x: 7.6, y: 8))
                brace.curve(to: NSPoint(x: 8.8, y: 5),
                            controlPoint1: NSPoint(x: 7.6, y: 5.3),
                            controlPoint2: NSPoint(x: 7.6, y: 5))
                brace.lineWidth = 1.2
                brace.lineCapStyle = .round
                brace.lineJoinStyle = .round
                brace.stroke()

                let mirror = NSAffineTransform()
                mirror.translateX(by: 21, yBy: 0)
                mirror.scaleX(by: -1, yBy: 1)
                let rightBrace = brace.copy() as! NSBezierPath
                rightBrace.transform(using: mirror as AffineTransform)
                rightBrace.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "SnippetShelf"
        return image
    }()
}
