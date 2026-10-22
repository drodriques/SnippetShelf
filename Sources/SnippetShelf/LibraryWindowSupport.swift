import SwiftUI
import AppKit

// Keep native traffic lights centered on the 52-point column headers. Only a
// transparent sizing item lives in the native toolbar; actions stay in their
// columns so AppKit cannot move them into its overflow menu.
struct LibraryWindowChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            chrome(content).toolbar(removing: .sidebarToggle)
        } else {
            chrome(content)
        }
    }

    private func chrome(_ content: Content) -> some View {
        content.toolbar {
            ToolbarItem {
                Color.clear.frame(width: 1, height: 36)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

// Observe fullscreen appearance and remove the automatic native sidebar item.
// Column headers own the controls in both windowed and fullscreen modes.
struct LibraryWindowObserver: NSViewRepresentable {
    @Binding var isFullScreen: Bool
    @Binding var isVisible: Bool
    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onChange = { isFullScreen = $0 }
        view.onVisibility = { isVisible = $0 }
        return view
    }
    func updateNSView(_ nsView: ObserverView, context: Context) {
        DispatchQueue.main.async { nsView.removeAutomaticSidebarToggle() }
    }
    final class ObserverView: NSView {
        private var observers: [MainActorNotification] = []
        var onChange: ((Bool) -> Void)?
        var onVisibility: ((Bool) -> Void)?
        func removeAutomaticSidebarToggle() {
            guard let toolbar = window?.toolbar else { return }
            for index in toolbar.items.indices.reversed()
                where toolbar.items[index].itemIdentifier == .toggleSidebar ||
                      toolbar.items[index].itemIdentifier.rawValue == "com.apple.SwiftUI.navigationSplitView.toggleSidebar" {
                toolbar.removeItem(at: index)
            }
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.removeAll()
            guard let window else { return }
            DispatchQueue.main.async { [weak self, weak window] in
                self?.removeAutomaticSidebarToggle()
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
            DispatchQueue.main.async { [weak self] in self?.removeAutomaticSidebarToggle() }
            observers.append(MainActorNotification(NSToolbar.willAddItemNotification) { [weak self] _ in
                DispatchQueue.main.async { self?.removeAutomaticSidebarToggle() }
            })
            for (name, fullScreen) in [(NSWindow.didEnterFullScreenNotification, true),
                                       (NSWindow.didExitFullScreenNotification, false)] {
                observers.append(MainActorNotification(name, object: window) { [weak self] _ in
                    self?.onChange?(fullScreen)
                })
            }
        }
    }
}

// Measure column bounds in window coordinates for header sizing and dividers.
// Publish after AppKit layout finishes to avoid invalidating its current pass.
struct WindowFrameReader: NSViewRepresentable {
    let onFrame: (CGRect) -> Void
    func makeNSView(context: Context) -> FrameView {
        let view = FrameView()
        view.onFrame = onFrame
        return view
    }
    func updateNSView(_ view: FrameView, context: Context) {
        view.onFrame = onFrame
        view.reportFrame()
    }
    final class FrameView: NSView {
        var onFrame: ((CGRect) -> Void)?
        private var resizeObserver: MainActorNotification?
        private var reportQueued = false
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            resizeObserver = nil
            guard let window else { return }
            resizeObserver = MainActorNotification(NSWindow.didResizeNotification, object: window) { [weak self] _ in self?.reportFrame() }
            reportFrame()
        }
        override func layout() { super.layout(); reportFrame() }
        func reportFrame() {
            guard !reportQueued else { return }
            reportQueued = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.reportQueued = false
                guard self.window != nil, self.bounds.width > 0 else { return }
                self.onFrame?(self.convert(self.bounds, to: nil))
            }
        }
    }
}
