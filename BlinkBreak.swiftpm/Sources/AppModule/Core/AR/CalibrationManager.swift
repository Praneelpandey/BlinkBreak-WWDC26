import Foundation
import ARKit
import Combine

/// Manages the eye tracking calibration process and baseline data collection via ARKit
@MainActor
final class CalibrationManager: NSObject, ObservableObject, ARSessionDelegate {
    // MARK: - Published Properties
    @Published var calibrationState: CalibrationState = .notStarted
    @Published var currentProgress: Double = 0.0
    @Published var collectedSamples: [Double] = []
    @Published var errorMessage: String?
    @Published var isFaceDetected: Bool = false
    
    // MARK: - AR Session
    let arSession = ARSession()
    
    // MARK: - Constants
    private let calibrationDuration: TimeInterval = 2.0 // 2 seconds of stability required
    private let minimumSamplesRequired = 20
    
    // MARK: - Private Properties
    private var stabilityStartTime: Date?
    private var lastFaceAnchor: ARFaceAnchor?
    private var baselineData: CalibrationData?
    
    // MARK: - Configuration
    var isDebugMode: Bool = false
    
    // MARK: - Initialization
    override init() {
        super.init()
        arSession.delegate = self
    }
    
    // MARK: - Public Interface
    
    /// Start the AR session and calibration process
    func startCalibration() {
        guard ARFaceTrackingConfiguration.isSupported else {
            calibrationState = .failed
            errorMessage = "Face tracking is not supported on this device."
            return
        }
        
        resetCalibration()
        
        // Run AR Session
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        calibrationState = .collectingBaseline
    }
    
    /// Pause the AR session (e.g. when view disappears)
    func pauseSession() {
        arSession.pause()
    }
    
    /// Stop calibration and save results manually if needed
    func finishCalibration(lightingCondition: LightingCondition, positioningScore: Double) {
        pauseSession()
        
        // If we don't have enough samples from auto-calibration, we might need to rely on what we have
        // But typically this is called AFTER auto-completion in the new flow.
        
        
        
        let calibration = CalibrationData(
            baselineEyeOpenness: collectedSamples,
            lightingConditions: lightingCondition,
            positioningScore: positioningScore
        )
        
        baselineData = calibration
        calibrationState = .completed(calibration)
        saveCalibrationData(calibration)
    }
    
    /// Cancel current calibration
    func cancelCalibration() {
        pauseSession()
        resetCalibration()
    }
    
    /// Load last successful calibration
    func loadLastCalibration() -> CalibrationData? {
        guard let data = UserDefaults.standard.data(forKey: "LastCalibration"),
              let calibration = try? JSONDecoder().decode(CalibrationData.self, from: data) else {
            return nil
        }
        return calibration
    }
    
    /// Check if device has required hardware
    func isDeviceCompatible() -> Bool {
        return ARFaceTrackingConfiguration.isSupported
    }
    
    // MARK: - ARSessionDelegate
    
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Find the first face anchor
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            Task { @MainActor in
                self.isFaceDetected = false
                self.stabilityStartTime = nil
                self.currentProgress = 0.0
            }
            return
        }
        
        Task { @MainActor in
            self.processFaceAnchor(faceAnchor)
        }
    }
    
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = "AR Session Failed: \(error.localizedDescription)"
            self.calibrationState = .failed
        }
    }
    
    // MARK: - Private Methods
    
    private func processFaceAnchor(_ anchor: ARFaceAnchor) {
        isFaceDetected = true
        lastFaceAnchor = anchor
        
        // Check stability
        // We consider "stable" if the face is detected and roughly centered (we assume user looks at screen)
        // For this simplified version, continuous detection is our proxy for stability.
        
        if stabilityStartTime == nil {
            stabilityStartTime = Date()
        }
        
        guard let startTime = stabilityStartTime else { return }
        
        // Calculate progress
        let elapsed = Date().timeIntervalSince(startTime)
        currentProgress = min(elapsed / calibrationDuration, 1.0)
        
        // Collect eye openness data sample
        // Left and Right eye blink coefficients (0 = open, 1 = closed usually, but verify ARKit standard)
        // ARKit: eyeBlinkLeft -> 0.0 (open) to 1.0 (closed)
        // We want openness: 1.0 - blink
        let leftBlink = anchor.blendShapes[.eyeBlinkLeft]?.doubleValue ?? 0.0
        let rightBlink = anchor.blendShapes[.eyeBlinkRight]?.doubleValue ?? 0.0
        let openness = 1.0 - ((leftBlink + rightBlink) / 2.0)
        
        collectedSamples.append(openness)
        if collectedSamples.count > 100 { collectedSamples.removeFirst() } // Keep buffer size manageable
        
        // Transition to success if stable for duration
        // Bypass collision with debug mode
        if elapsed >= calibrationDuration && calibrationState == .collectingBaseline {
            if !isDebugMode {
                finishAutoCalibration()
            }
        }
    }
    
    private func finishAutoCalibration() {
        pauseSession()
        
        
        
        // Determine lighting from ARSession if possible, else default
        let lighting: LightingCondition = .normal // Could use lightEstimation?.ambientIntensity
        
        let calibration = CalibrationData(
            baselineEyeOpenness: collectedSamples,
            lightingConditions: lighting,
            positioningScore: 1.0 // High score for successful AR tracking
        )
        
        baselineData = calibration
        calibrationState = .completed(calibration)
        saveCalibrationData(calibration)
    }
    
    private func resetCalibration() {
        calibrationState = .notStarted
        currentProgress = 0.0
        collectedSamples.removeAll()
        errorMessage = nil
        stabilityStartTime = nil
        isFaceDetected = false
        lastFaceAnchor = nil
    }
    
    private func saveCalibrationData(_ calibration: CalibrationData) {
        do {
            let data = try JSONEncoder().encode(calibration)
            UserDefaults.standard.set(data, forKey: "LastCalibration")
        } catch {
            print("Failed to save calibration data: \(error)")
        }
    }
}

// MARK: - Calibration States

enum CalibrationState: Equatable {
    case notStarted
    case collectingBaseline
    case readyForReview
    case completed(CalibrationData)
    case failed
    
    var isCalibrating: Bool {
        switch self {
        case .collectingBaseline, .readyForReview:
            return true
        default:
            return false
        }
    }
    
    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
}