import UIKit

/// Centralized haptic feedback manager using Apple's Taptic Engine.
/// Provides game-specific feedback patterns for maximum polish.
@MainActor
final class HapticManager {
    static let shared = HapticManager()
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    
    private init() {
        // Pre-warm the generators for instant response
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notification.prepare()
    }
    
    /// Light tap — laser fire
    func fireLaser() {
        lightImpact.impactOccurred(intensity: 0.6)
        lightImpact.prepare()
    }
    
    /// Medium tap — enemy destroyed
    func enemyDestroyed() {
        mediumImpact.impactOccurred(intensity: 0.8)
        mediumImpact.prepare()
    }
    
    /// Heavy slam — player takes damage
    func playerHit() {
        heavyImpact.impactOccurred(intensity: 1.0)
        heavyImpact.prepare()
    }
    
    /// Success pattern — barrel roll activated / ghost mode
    func barrelRoll() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }
    
    /// Warning — shield at 1 HP
    func shieldWarning() {
        notification.notificationOccurred(.warning)
        notification.prepare()
    }
    
    /// Error — game over
    func gameOver() {
        heavyImpact.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.heavyImpact.impactOccurred(intensity: 0.7)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.heavyImpact.impactOccurred(intensity: 0.4)
                self.heavyImpact.prepare()
            }
        }
    }
    
    /// Unlocked an achievement
    func playSuccessHaptic() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }
    
    /// Hyperjump — rapid escalating taps
    func hyperJump() {
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) {
                self.mediumImpact.impactOccurred(intensity: 0.4 + CGFloat(i) * 0.15)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.notification.notificationOccurred(.success)
            self.mediumImpact.prepare()
        }
    }
    
    // MARK: - UI Interactions
    
    /// Generic soft tap for UI selection
    func playSelectionHaptic() {
        lightImpact.impactOccurred(intensity: 0.5)
        lightImpact.prepare()
    }
    
    /// Granular impact for buttons
    func playImpactHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            lightImpact.impactOccurred()
            lightImpact.prepare()
        case .medium:
            mediumImpact.impactOccurred()
            mediumImpact.prepare()
        case .heavy:
            heavyImpact.impactOccurred()
            heavyImpact.prepare()
        case .soft, .rigid: // Fallbacks for newer styles
            mediumImpact.impactOccurred()
            mediumImpact.prepare()
        @unknown default:
            mediumImpact.impactOccurred()
        }
    }
}
