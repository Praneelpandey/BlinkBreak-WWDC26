import Foundation

enum TelemetryEvent: String, Codable, Equatable, Hashable {
    case blink
    case hit
    case powerup
}

struct SessionTelemetry: Codable, Equatable, Hashable {
    let timeOffset: TimeInterval
    let playerY: Double
    let event: TelemetryEvent?
}

struct FocusStar: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    let date: Date
    let focusScore: Double
    let duration: Double
    let telemetry: [SessionTelemetry]
}
