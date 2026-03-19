import SwiftUI

struct NeuralPressStyle: ButtonStyle {
    var glowColor: Color = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .shadow(color: configuration.isPressed ? glowColor.opacity(0.8) : .clear, radius: configuration.isPressed ? 20 : 0)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    HapticManager.shared.playImpactHaptic(style: .light)
                }
            }
    }
}

extension View {
    func neuralInteract(glowColor: Color = Color(red: 0.0, green: 0.94, blue: 1.0)) -> some View {
        self.buttonStyle(NeuralPressStyle(glowColor: glowColor))
    }
}
