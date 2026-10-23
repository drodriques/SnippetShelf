import SwiftUI
import AppKit

// All three columns participate in one native split view. AppKit owns drag
// constraints and saved divider positions; SwiftUI only observes sidebar width
// for toolbar alignment, asynchronously after native layout has completed.
struct LibraryPanelSplitView<Sidebar: View, ListContent: View, DetailContent: View>: NSViewControllerRepresentable {
    let sidebar: Sidebar
    let list: ListContent
    let detail: DetailContent
    let sidebarExpanded: Bool
    let onSidebarWidth: (CGFloat) -> Void

    func makeNSViewController(context: Context) -> Controller {
        Controller(sidebar: sidebar, list: list, detail: detail,
                   expanded: sidebarExpanded, onSidebarWidth: onSidebarWidth)
    }
    func updateNSViewController(_ controller: Controller, context: Context) {
        controller.onSidebarWidth = onSidebarWidth
        controller.sidebarHost.rootView = sidebar
        controller.listHost.rootView = list
        controller.detailHost.rootView = detail
        controller.setSidebarExpanded(sidebarExpanded)
        controller.splitView.needsDisplay = true
    }

    final class Controller: NSSplitViewController {
        let sidebarHost: NSHostingController<Sidebar>
        let listHost: NSHostingController<ListContent>
        let detailHost: NSHostingController<DetailContent>
        var onSidebarWidth: (CGFloat) -> Void
        private(set) var expanded: Bool
        private var expandedWidth: CGFloat = 230
        private var reportQueued = false
        private var reportedWidth: CGFloat?

        init(sidebar: Sidebar, list: ListContent, detail: DetailContent,
             expanded: Bool, onSidebarWidth: @escaping (CGFloat) -> Void) {
            sidebarHost = NSHostingController(rootView: sidebar)
            listHost = NSHostingController(rootView: list)
            detailHost = NSHostingController(rootView: detail)
            self.expanded = expanded
            self.onSidebarWidth = onSidebarWidth
            super.init(nibName: nil, bundle: nil)
            for host in [sidebarHost as NSViewController, listHost, detailHost] {
                host.view.translatesAutoresizingMaskIntoConstraints = false
            }
            sidebarHost.sizingOptions = []
            listHost.sizingOptions = []
            detailHost.sizingOptions = []
            splitView = PanelSplitView()
            splitView.isVertical = true
            splitView.dividerStyle = .thin
            splitView.autosaveName = "SnippetShelf.threePanels"
            let sidebarItem = NSSplitViewItem(viewController: sidebarHost)
            sidebarItem.minimumThickness = expanded ? 200 : 64
            sidebarItem.maximumThickness = expanded ? 360 : 64
            sidebarItem.holdingPriority = NSLayoutConstraint.Priority(252)
            let listItem = NSSplitViewItem(viewController: listHost)
            listItem.minimumThickness = 360
            listItem.maximumThickness = 640
            listItem.holdingPriority = NSLayoutConstraint.Priority(251)
            let detailItem = NSSplitViewItem(viewController: detailHost)
            detailItem.minimumThickness = 360
            addSplitViewItem(sidebarItem)
            addSplitViewItem(listItem)
            addSplitViewItem(detailItem)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func setSidebarExpanded(_ value: Bool) {
            guard value != expanded else { return }
            let item = splitViewItems[0]
            if !value {
                expandedWidth = min(360, max(200, sidebarHost.view.frame.width))
                item.minimumThickness = 64
                item.maximumThickness = 64
            } else {
                item.maximumThickness = 360
                item.minimumThickness = 200
            }
            expanded = value
            splitView.setPosition(value ? expandedWidth : 64, ofDividerAt: 0)
            queueWidthReport()
        }

        override func splitViewDidResizeSubviews(_ notification: Notification) {
            super.splitViewDidResizeSubviews(notification)
            queueWidthReport()
        }
        override func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect,
                                forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
            let native = super.splitView(splitView, effectiveRect: proposedEffectiveRect,
                                         forDrawnRect: drawnRect, ofDividerAt: dividerIndex)
            // A generous invisible drag target retains a one-point visible line.
            guard dividerIndex != 0 || expanded else { return .zero }
            return native.union(drawnRect.insetBy(dx: -3, dy: 0)).intersection(splitView.bounds)
        }
        private func queueWidthReport() {
            guard !reportQueued else { return }
            reportQueued = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.reportQueued = false
                let width = self.sidebarHost.view.frame.width
                guard width > 0, self.reportedWidth.map({ abs($0 - width) > 0.5 }) ?? true else { return }
                self.reportedWidth = width
                self.onSidebarWidth(width)
            }
        }
    }
}

private final class PanelSplitView: NSSplitView {
    override var dividerThickness: CGFloat { 1 }
    override var dividerColor: NSColor { LibraryAppearance.containerColor }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
