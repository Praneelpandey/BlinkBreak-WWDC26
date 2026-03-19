import Foundation
import ARKit
import Combine

/// Dedicated AR Manager for the Game Loop.
/// Extracts blend shapes and head orientation from ARFaceAnchor.
@MainActor
final class ARManager: NSObject, ObservableObject, ARSessionDelegate {
    // MARK: - Published Properties
    /// Normalized Look Up value (0.0 ... 1.0)
    @Published var eyeLookUp: Float = 0.0
    
    /// Normalized Look Down value (0.0 ... 1.0)
    @Published var eyeLookDown: Float = 0.0
    
    /// True when both eyes are closed past the blink threshold
    @Published var isBlinking: Bool = false
    
    /// Head tilt angle in radians (positive = tilt right, negative = tilt left)
    @Published var headTilt: Float = 0.0
    
    /// True when head is tilted past threshold (triggers barrel roll)
    @Published var isHeadTilted: Bool = false
    
    // MARK: - Blink Analytics (for Mission Debrief / Eye Health Report)
    @Published var totalBlinks: Int = 0
    @Published var blinksPerMinute: Double = 0.0
    @Published var longestStare: Double = 0.0 // seconds without blinking
    private var lastBlinkTime: TimeInterval = 0
    private var sessionStartTime: TimeInterval = 0
    private var wasBlinking: Bool = false
    
    // MARK: - AR Session
    let session = ARSession()
    
    // MARK: - Constants
    private let smoothingFactor: Float = 0.5
    private let blinkThreshold: Float = 0.6
    private let tiltThreshold: Float = 0.35 // ~20 degrees
    private let tiltCooldown: TimeInterval = 3.0 // Prevent rapid re-trigger
    
    // MARK: - Private
    private var lastTiltTime: TimeInterval = 0
    
    // MARK: - Initialization
    override init() {
        super.init()
        session.delegate = self
    }
    
    // MARK: - Session Control
    
    func startSession() {
        guard ARFaceTrackingConfiguration.isSupported else {
            print("ARFaceTracking is not supported on this device.")
            return
        }
        
        eyeLookUp = 0.0
        eyeLookDown = 0.0
        isBlinking = false
        headTilt = 0.0
        isHeadTilted = false
        totalBlinks = 0
        blinksPerMinute = 0.0
        longestStare = 0.0
        lastBlinkTime = CACurrentMediaTime()
        sessionStartTime = CACurrentMediaTime()
        wasBlinking = false
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func pauseSession() {
        session.pause()
    }
    
    // MARK: - ARSessionDelegate
    
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
        
        let blendShapes = faceAnchor.blendShapes
        
        // Eye look values
        let lookUpLeft = blendShapes[.eyeLookUpLeft]?.floatValue ?? 0.0
        let lookDownLeft = blendShapes[.eyeLookDownLeft]?.floatValue ?? 0.0
        let lookUpRight = blendShapes[.eyeLookUpRight]?.floatValue ?? 0.0
        let lookDownRight = blendShapes[.eyeLookDownRight]?.floatValue ?? 0.0
        
        let rawLookUp = (lookUpLeft + lookUpRight) / 2.0
        let rawLookDown = (lookDownLeft + lookDownRight) / 2.0
        
        // Blink detection
        let blinkL = blendShapes[.eyeBlinkLeft]?.floatValue ?? 0.0
        let blinkR = blendShapes[.eyeBlinkRight]?.floatValue ?? 0.0
        let isBothEyesClosed = blinkL > 0.6 && blinkR > 0.6
        
        // Head tilt (roll) — extract Z rotation from the 4x4 transform matrix
        let m = faceAnchor.transform
        let rollAngle = atan2(m.columns.0.y, m.columns.0.x) // Roll around Z axis
        
        Task { @MainActor in
            self.updateValues(
                newUp: rawLookUp,
                newDown: rawLookDown,
                blinking: isBothEyesClosed,
                roll: rollAngle
            )
        }
    }
    
    private func updateValues(newUp: Float, newDown: Float, blinking: Bool, roll: Float) {
        eyeLookUp = eyeLookUp + (newUp - eyeLookUp) * smoothingFactor
        eyeLookDown = eyeLookDown + (newDown - eyeLookDown) * smoothingFactor
        
        // Blink edge detection (rising edge = new blink)
        let now = CACurrentMediaTime()
        if blinking && !wasBlinking {
            totalBlinks += 1
            
            // Update longest stare (time since last blink)
            let stareDuration = now - lastBlinkTime
            if stareDuration > longestStare {
                longestStare = stareDuration
            }
            lastBlinkTime = now
        }
        wasBlinking = blinking
        isBlinking = blinking
        
        // Update BPM
        let elapsed = now - sessionStartTime
        if elapsed > 1.0 {
            blinksPerMinute = Double(totalBlinks) / (elapsed / 60.0)
        }
        
        // Smooth head tilt
        headTilt = headTilt + (roll - headTilt) * 0.3
        
        // Check for tilt trigger with cooldown
        if abs(headTilt) > tiltThreshold && (now - lastTiltTime) > tiltCooldown {
            isHeadTilted = true
            lastTiltTime = now
        } else if abs(headTilt) < tiltThreshold * 0.5 {
            isHeadTilted = false
        }
    }
}
