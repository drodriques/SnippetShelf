import SwiftUI

struct HeaderActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 36, height: 36)
            .background(Color.primary.opacity(configuration.isPressed ? 0.16 : 0.08), in: Circle())
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.12)))
    }
}
