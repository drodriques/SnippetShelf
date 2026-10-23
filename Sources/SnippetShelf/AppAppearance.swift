import SwiftUI

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case auto, light, dark
    var id: String { rawValue }
    var title: String {
        switch self { case .auto: return "Auto"; case .light: return "Light"; case .dark: return "Dark" }
    }
    var colorScheme: ColorScheme? {
        switch self { case .auto: return nil; case .light: return .light; case .dark: return .dark }
    }
}

private struct AppAppearance: ViewModifier {
    @AppStorage("appearanceMode") private var mode = AppAppearanceMode.auto.rawValue
    func body(content: Content) -> some View {
        content
            .tint(LibraryAppearance.accent)
            .accentColor(LibraryAppearance.accent)
            .preferredColorScheme((AppAppearanceMode(rawValue: mode) ?? .auto).colorScheme)
    }
}

extension View {
    func appAppearance() -> some View { modifier(AppAppearance()) }
}
