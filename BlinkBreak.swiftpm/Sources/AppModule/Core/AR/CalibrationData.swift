import Foundation

/// Stores calibration baseline data for eye tracking sensitivity
struct CalibrationData: Codable, Equatable {
    /// Unique identifier for this calibration session
    let id: UUID
    
    /// Timestamp when calibration was completed
    let timestamp: Date
    
    /// Baseline eye openness values collected during neutral state
    let baselineEyeOpenness: [Double]
    
    /// Average eye openness during calibration period
    var averageEyeOpenness: Double {
        guard !baselineEyeOpenness.isEmpty else { return 0.0 }
        return baselineEyeOpenness.reduce(0, +) / Double(baselineEyeOpenness.count)
    }
    
    /// Standard deviation of eye openness measurements
    var opennessDeviation: Double {
        guard baselineEyeOpenness.count > 1 else { return 0.0 }
        let mean = averageEyeOpenness
        let squaredDifferences = baselineEyeOpenness.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(baselineEyeOpenness.count - 1)
        return sqrt(variance)
    }
    
    /// Sensitivity threshold multiplier (1.0 = default, <1.0 = more sensitive, >1.0 = less sensitive)
    let sensitivityMultiplier: Double
    
    /// Indicates if this calibration passed quality checks
    let isValid: Bool
    
    /// Environmental factors during calibration
    let lightingConditions: LightingCondition
    
    /// Face positioning quality score (0.0 - 1.0)
    let positioningScore: Double
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        baselineEyeOpenness: [Double],
        sensitivityMultiplier: Double = 1.0,
        isValid: Bool = true,
        lightingConditions: LightingCondition = .unknown,
        positioningScore: Double = 0.0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.baselineEyeOpenness = baselineEyeOpenness
        self.sensitivityMultiplier = sensitivityMultiplier
        self.isValid = isValid
        self.lightingConditions = lightingConditions
        self.positioningScore = positioningScore
    }
}

/// Environmental lighting conditions during calibration
enum LightingCondition: String, CaseIterable, Codable {
    case dark = "Dark"
    case dim = "Dim"
    case normal = "Normal"
    case bright = "Bright"
    case unknown = "Unknown"
    
    var displayName: String {
        rawValue
    }
    
    var description: String {
        switch self {
        case .dark: return "Low light conditions"
        case .dim: return "Moderately lit environment"
        case .normal: return "Standard indoor lighting"
        case .bright: return "Well-lit or outdoor conditions"
        case .unknown: return "Lighting conditions not detected"
        }
    }
}