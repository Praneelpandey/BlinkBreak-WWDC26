import SwiftUI

// MARK: - Mission Model

enum MissionType: String, Codable {
    case distance
    case kills
    case survival
    case accuracy
}

struct Mission: Identifiable {
    let id: String
    let title: String
    let description: String
    let target: Int
    var progress: Int
    let xpReward: Int
    let type: MissionType
    let icon: String
    
    var isCompleted: Bool { progress >= target }
    var progressFraction: Double { min(Double(progress) / Double(target), 1.0) }
}

// MARK: - MissionManager

@MainActor
class MissionManager: ObservableObject {
    @Published var missions: [Mission] = []
    @Published var activeMission: Mission?
    
    // Persistence
    @AppStorage("mission_distance_500_progress") private var dist500: Int = 0
    @AppStorage("mission_kills_10_progress") private var kills10: Int = 0
    @AppStorage("mission_kills_50_progress") private var kills50: Int = 0
    @AppStorage("mission_survive_30_progress") private var survive30: Int = 0
    @AppStorage("mission_survive_60_progress") private var survive60: Int = 0
    @AppStorage("mission_distance_2000_progress") private var dist2000: Int = 0
    
    init() {
        loadMissions()
    }
    
    private func loadMissions() {
        missions = [
            Mission(
                id: "distance_500", title: "PATHFINDER",
                description: "Travel 500m in a single run",
                target: 500, progress: dist500, xpReward: 50,
                type: .distance, icon: "location.fill"
            ),
            Mission(
                id: "kills_10", title: "GLITCH HUNTER",
                description: "Destroy 10 glitches",
                target: 10, progress: kills10, xpReward: 40,
                type: .kills, icon: "bolt.fill"
            ),
            Mission(
                id: "survive_30", title: "SURVIVOR",
                description: "Survive for 30 seconds",
                target: 30, progress: survive30, xpReward: 30,
                type: .survival, icon: "clock.fill"
            ),
            Mission(
                id: "distance_2000", title: "DEEP SPACE",
                description: "Travel 2000m in a single run",
                target: 2000, progress: dist2000, xpReward: 100,
                type: .distance, icon: "globe.americas.fill"
            ),
            Mission(
                id: "kills_50", title: "PURGE MASTER",
                description: "Destroy 50 glitches total",
                target: 50, progress: kills50, xpReward: 80,
                type: .kills, icon: "flame.fill"
            ),
            Mission(
                id: "survive_60", title: "IRON PILOT",
                description: "Survive for 60 seconds",
                target: 60, progress: survive60, xpReward: 60,
                type: .survival, icon: "shield.fill"
            ),
        ]
        
        // Set first incomplete mission as active
        activeMission = missions.first(where: { !$0.isCompleted })
    }
    
    /// Called every frame from GameView with running totals for this session
    func reportProgress(distance: Int, kills: Int, survivalSeconds: Double) {
        for i in missions.indices {
            switch missions[i].type {
            case .distance:
                if missions[i].id == "distance_500" { missions[i].progress = max(dist500, distance) }
                if missions[i].id == "distance_2000" { missions[i].progress = max(dist2000, distance) }
            case .kills:
                if missions[i].id == "kills_10" { missions[i].progress = kills10 + kills }
                if missions[i].id == "kills_50" { missions[i].progress = kills50 + kills }
            case .survival:
                if missions[i].id == "survive_30" { missions[i].progress = max(survive30, Int(survivalSeconds)) }
                if missions[i].id == "survive_60" { missions[i].progress = max(survive60, Int(survivalSeconds)) }
            case .accuracy:
                break
            }
        }
        activeMission = missions.first(where: { !$0.isCompleted })
    }
    
    /// Called once when game ends — persists best values
    func reportGameEnd(score: Int, kills: Int, survivalSeconds: Double) {
        dist500 = max(dist500, score)
        dist2000 = max(dist2000, score)
        kills10 += kills
        kills50 += kills
        survive30 = max(survive30, Int(survivalSeconds))
        survive60 = max(survive60, Int(survivalSeconds))
        
        loadMissions()
    }
}
