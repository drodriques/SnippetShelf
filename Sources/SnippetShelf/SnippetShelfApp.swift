import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var libraryWindow: NSWindow?
    var openLibrary: (() -> Void)?
    var hasPendingWrites: (() -> Bool)?
    var finishPendingWrites: (() async -> Void)?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard hasPendingWrites?() == true else { return .terminateNow }
        Task { @MainActor in
            await finishPendingWrites?()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Help or an editor sheet can be visible without the library being open.
        // Target the library explicitly instead of relying on flag or mainWindow.
        if let window = libraryWindow, window.isVisible || window.isMiniaturized {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else if let openLibrary {
            openLibrary()
        } else {
            return true // Let AppKit handle requests before the scene is ready.
        }
        sender.activate(ignoringOtherApps: true)
        return false // This request is handled; suppress AppKit's default reopen.
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct SnippetShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = SnippetStore()
    @StateObject private var words = WordStore()
    @AppStorage("showMenuBarItem") private var showMenuBarItem = true
    @AppStorage("showCurrentWord") private var showCurrentWord = true

    var body: some Scene {
        Window("SnippetShelf", id: "library") {
            LibraryWindowContent(delegate: delegate).environmentObject(store).environmentObject(words)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1140, height: 650)
        .commands {
            SidebarCommands()
            LibraryCommands()
        }
        Window("SnippetShelf Help", id: "help") {
            HelpView()
        }
        .defaultSize(width: 720, height: 620)
        Settings {
            GeneralSettingsView()
        }
        MenuBarExtra(isInserted: $showMenuBarItem) {
            QuickMenuView().environmentObject(store).environmentObject(words)
        } label: {
            HStack(spacing: 5) {
                Image(nsImage: MenuBarIcon.image)
                if showCurrentWord, let current = words.current {
                    Text(current.menuBarTitle)
                }
            }
            .accessibilityLabel(words.current.map { showCurrentWord ? "SnippetShelf — \($0.word)" : "SnippetShelf" } ?? "SnippetShelf")
        }
    }
}

// Capture openWindow inside the library scene's environment. SwiftUI's single
// Window scene owns reopening a closed library, avoiding duplicate windows.
private struct LibraryWindowContent: View {
    @EnvironmentObject private var store: SnippetStore
    @EnvironmentObject private var words: WordStore
    @Environment(\.openWindow) private var openWindow
    let delegate: AppDelegate

    var body: some View {
        LibraryView()
            .background(LibraryWindowAccess(delegate: delegate))
            .task {
                await store.loadIfNeeded()
                await words.loadIfNeeded()
            }
            .onAppear {
                let action = openWindow
                delegate.openLibrary = { action(id: "library") }
                delegate.hasPendingWrites = { [store, words] in store.hasPendingWrites || words.hasPendingWrites }
                delegate.finishPendingWrites = { [store, words] in
                    await store.finishPendingWrites()
                    await words.finishPendingWrites()
                }
            }
    }
}

private struct LibraryWindowAccess: NSViewRepresentable {
    let delegate: AppDelegate

    func makeNSView(context: Context) -> WindowView {
        let view = WindowView()
        view.delegate = delegate
        return view
    }

    func updateNSView(_ view: WindowView, context: Context) {
        view.delegate = delegate
        if let window = view.window { delegate.libraryWindow = window }
    }

    final class WindowView: NSView {
        weak var delegate: AppDelegate?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { delegate?.libraryWindow = window }
        }
    }
}
