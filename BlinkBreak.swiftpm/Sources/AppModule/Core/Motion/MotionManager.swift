import SwiftUI
@preconcurrency import CoreMotion

/// Lightweight gyroscope-driven motion provider for parallax effects.
/// Publishes clamped pitch/roll values at 60 Hz for smooth UI response.
/// Falls back gracefully on Simulator (values stay at 0).
final class MotionManager: ObservableObject {
    
    // Published values clamped to [-1, 1] for safe UI consumption
    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0
    
    private let manager = CMMotionManager()
    
    init() {
        guard manager.isDeviceMotionAvailable else { return }
        
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let data = motion else { return }
            
            // Clamp to prevent wild values
            let rawPitch = min(max(data.attitude.pitch, -1.0), 1.0)
            let rawRoll  = min(max(data.attitude.roll, -1.0), 1.0)
            
            // Smooth lerp (0.15 = responsiveness, higher = snappier)
            self.pitch += (rawPitch - self.pitch) * 0.15
            self.roll  += (rawRoll  - self.roll)  * 0.15
        }
    }
    
    deinit {
        manager.stopDeviceMotionUpdates()
    }
}
