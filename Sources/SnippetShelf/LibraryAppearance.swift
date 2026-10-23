import SwiftUI
import AppKit

// Shared surfaces for all three panels. Text and controls never inherit opacity.
enum LibraryAppearance {
    // A restrained variation of the icon's purple, lifted in dark appearance.
    static let accentColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.647, green: 0.541, blue: 0.922, alpha: 1)
            : NSColor(srgbRed: 0.478, green: 0.361, blue: 0.820, alpha: 1)
    }
    static var accent: Color { Color(nsColor: accentColor) }
    static var icon: Color { .secondary }
    static let panelColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.145, green: 0.157, blue: 0.165, alpha: 1)
            : NSColor(white: 0.98, alpha: 1)
    }
    static let containerColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.188, green: 0.204, blue: 0.212, alpha: 1)
            : NSColor(white: 0.90, alpha: 1)
    }
    static var panel: Color { Color(nsColor: panelColor) }
    static var container: Color { Color(nsColor: containerColor) }
    static func clampedTranslucency(_ value: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : 0
    }
}

struct LibraryBackground: View {
    let translucency: Double
    var body: some View {
        ZStack {
            if translucency > 0 { WindowMaterial() }
            LibraryAppearance.container.opacity(1 - translucency * 0.6)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// One native material for the entire library; no per-row blur or rendering loop.
private struct WindowMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = LibraryMaterialView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

// AppKit-backed backgrounds must also pass through native hit testing. SwiftUI's
// allowsHitTesting alone does not govern an embedded NSView's hit-test traversal.
final class LibraryMaterialView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct LibrarySettingsLink: View {
    var body: some View {
        if #available(macOS 14.0, *) {
            SettingsLink { Label("Settings…", systemImage: "gearshape") }
        } else {
            Button("Settings…") {
                if !NSApp.sendAction(NSSelectorFromString("showSettingsWindow:"), to: nil, from: nil) {
                    NSApp.sendAction(NSSelectorFromString("showPreferencesWindow:"), to: nil, from: nil)
                }
            }
        }
    }
}

private struct SidebarExpansionKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}
extension FocusedValues {
    var sidebarExpansion: Binding<Bool>? {
        get { self[SidebarExpansionKey.self] }
        set { self[SidebarExpansionKey.self] = newValue }
    }
}

// Inline labels avoid AppKit's opaque pinned-section header surface.
struct PanelSectionLabel: View {
    let title: String
    var body: some View {
        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.top, 8)
            .listRowBackground(Color.clear).listRowSeparator(.hidden)
            .accessibilityAddTraits(.isHeader)
    }
}

// Background only: native rows retain their complete click/selection bounds.
struct RowSelectionBackground: View {
    let isSelected: Bool
    var horizontalInset: CGFloat = 8
    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(LibraryAppearance.accent.opacity(isSelected ? 0.18 : 0))
            .padding(.horizontal, horizontalInset)
            .padding(.vertical, 2)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
