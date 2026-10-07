import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct SnippetShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = SnippetStore()

    var body: some Scene {
        Window("SnippetShelf", id: "library") {
            LibraryView().environmentObject(store)
        }
        .defaultSize(width: 1140, height: 650)
        .commands {
            SidebarCommands()
        }
        MenuBarExtra {
            QuickMenuView().environmentObject(store)
        } label: {
            Image(nsImage: MenuBarIcon.image)
                .accessibilityLabel("SnippetShelf")
        }
    }
}
