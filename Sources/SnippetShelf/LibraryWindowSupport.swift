import SwiftUI
import AppKit

// Keep content below the native toolbar in windowed and fullscreen modes.
struct LibraryWindowObserver: NSViewRepresentable {
    @Binding var isVisible: Bool
    let allowsTranslucency: Bool
    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onVisibility = { isVisible = $0 }
        view.allowsTranslucency = allowsTranslucency
        return view
    }
    func updateNSView(_ nsView: ObserverView, context: Context) {
        nsView.allowsTranslucency = allowsTranslucency
    }
    final class ObserverView: NSView {
        private var observers: [MainActorNotification] = []
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        var onVisibility: ((Bool) -> Void)?
        var allowsTranslucency = false {
            didSet { if oldValue != allowsTranslucency { updateWindowAppearance() } }
        }
        private func updateWindowAppearance() {
            guard let window else { return }
            window.isOpaque = !allowsTranslucency
            window.backgroundColor = allowsTranslucency ? .clear : LibraryAppearance.containerColor
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.removeAll()
            guard let window else { return }
            updateWindowAppearance()
            window.titleVisibility = .hidden
            DispatchQueue.main.async { [weak self, weak window] in
                self?.onVisibility?(window?.isVisible == true && window?.isMiniaturized == false)
            }
            for name in [NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification,
                         NSWindow.didBecomeKeyNotification, NSWindow.willCloseNotification] {
                observers.append(MainActorNotification(name, object: window) {
                    [weak self, weak window] notification in
                    let visible = notification.name != NSWindow.willCloseNotification
                        && window?.isVisible == true && window?.isMiniaturized == false
                    DispatchQueue.main.async { self?.onVisibility?(visible) }
                })
            }
        }
    }
}

// Native toolbar leading margins differ between windowed/fullscreen modes.
// Measure only origin after layout; changing this item's width cannot change its
// leading anchor. Coalesce and publish changes outside AppKit's layout pass.
struct ToolbarOriginReader: NSViewRepresentable {
    let onOrigin: (CGFloat) -> Void
    func makeNSView(context: Context) -> OriginView {
        let view = OriginView()
        view.onOrigin = onOrigin
        return view
    }
    func updateNSView(_ view: OriginView, context: Context) {
        view.onOrigin = onOrigin
        view.queueReport()
    }
    final class OriginView: NSView {
        var onOrigin: ((CGFloat) -> Void)?
        private var queued = false
        private var lastOrigin: CGFloat?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); queueReport() }
        override func layout() { super.layout(); queueReport() }
        func queueReport() {
            guard !queued else { return }
            queued = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.queued = false
                guard self.window != nil else { return }
                let origin = self.convert(.zero, to: nil).x
                guard self.lastOrigin.map({ abs($0 - origin) > 0.5 }) ?? true else { return }
                self.lastOrigin = origin
                self.onOrigin?(origin)
            }
        }
    }
}
