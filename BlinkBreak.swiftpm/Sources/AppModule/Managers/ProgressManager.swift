import Foundation
import SwiftUI
import Combine

@MainActor
class ProgressManager: ObservableObject {
    static let shared = ProgressManager()
    
    @Published var achievements: [Achievement] = []
    @Published var visionIndexScore: Int = 100
    @Published var newlyUnlocked: Achievement?
    @Published var memoryGalaxy: [FocusStar] = []
    
    @AppStorage("pm_totalBlinks") var totalBlinks: Int = 0
    @AppStorage("pm_perfectSessions") var perfectSessions: Int = 0
    @AppStorage("pm_uniqueDaysPlayed") var uniqueDaysPlayed: Int = 0
    @AppStorage("pm_lastPlayedDay") var lastPlayedDay: String = ""
    
    private let achievementsKey = "pilot_achievements"
    private let galaxyKey = "focus_galaxy"
    
    private init() {
        loadAchievements()
        loadGalaxy()
        updateVisionIndex()
        checkDailyLogin()
    }
    
    private func checkDailyLogin() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        
        if lastPlayedDay != todayStr {
            uniqueDaysPlayed += 1
            lastPlayedDay = todayStr
        }
    }
    
    private func loadAchievements() {
        if let data = UserDefaults.standard.data(forKey: achievementsKey),
           let saved = try? JSONDecoder().decode([Achievement].self, from: data) {
            self.achievements = saved
        } else {
            self.achievements = [
                Achievement(id: "iron_eyes", name: "Iron Eyes", description: "Blink 1000 times overall", isUnlocked: false, unlockDate: nil),
                Achievement(id: "focus_master", name: "Focus Master", description: "Complete 10 perfect sessions", isUnlocked: false, unlockDate: nil),
                Achievement(id: "no_strain", name: "No-Strain Run", description: "Complete a mission with 0 damage", isUnlocked: false, unlockDate: nil),
                Achievement(id: "veteran", name: "Veteran", description: "Play consistently for 30 days", isUnlocked: false, unlockDate: nil)
            ]
            saveAchievements()
        }
    }
    
    private func saveAchievements() {
        if let data = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(data, forKey: achievementsKey)
        }
    }
    
    // MARK: - Memory Galaxy (Telemetry)
    private func loadGalaxy() {
        if let data = UserDefaults.standard.data(forKey: galaxyKey),
           let saved = try? JSONDecoder().decode([FocusStar].self, from: data) {
            self.memoryGalaxy = saved
        }
    }
    
    func saveFocusStar(_ star: FocusStar) {
        memoryGalaxy.append(star)
        if let data = try? JSONEncoder().encode(memoryGalaxy) {
            UserDefaults.standard.set(data, forKey: galaxyKey)
        }
    }
    
    // MARK: - Mission Logic
    
    func reportSessionMetrics(blinks: Int, damageTaken: Int) {
        totalBlinks += blinks
        let isPerfect = damageTaken == 0
        if isPerfect {
            perfectSessions += 1
        }
        
        var didUnlock = false
        
        for i in achievements.indices {
            guard !achievements[i].isUnlocked else { continue }
            
            var unlockedNow = false
            switch achievements[i].id {
            case "iron_eyes":
                if totalBlinks >= 1000 { unlockedNow = true }
            case "focus_master":
                if perfectSessions >= 10 { unlockedNow = true }
            case "no_strain":
                if isPerfect { unlockedNow = true }
            case "veteran":
                if uniqueDaysPlayed >= 30 { unlockedNow = true }
            default: break
            }
            
            if unlockedNow {
                achievements[i].isUnlocked = true
                achievements[i].unlockDate = Date()
                didUnlock = true
                
                self.newlyUnlocked = achievements[i]
                AudioManager.shared.playLevelUp() // Generic positive sound
            }
        }
        
        if didUnlock {
            saveAchievements()
            HapticManager.shared.playSuccessHaptic()
        }
        
        updateVisionIndex()
    }
    
    func updateVisionIndex() {
        let hd = HealthDataManager.shared.currentWeek
        let bpm = hd.blinksPerMinute
        
        var blinkScore = 0.0
        if bpm >= 15 { blinkScore = 30.0 }
        else if bpm > 0 { blinkScore = min((bpm / 15.0) * 30.0, 30.0) }
        
        let breakScore = min((hd.totalBreakSeconds / 20.0) * 30.0, 30.0)
        let focusScore = (Double(hd.strainReductionPercent) / 100.0) * 20.0
        let consistencyScore = min((Double(hd.totalSessions) / 5.0) * 20.0, 20.0)
        
        var rawScore = Int(blinkScore + breakScore + focusScore + consistencyScore)
        
        if hd.totalSessions == 0 && HealthDataManager.shared.history.isEmpty {
            rawScore = 100
        }
        
        self.visionIndexScore = max(0, min(100, rawScore))
    }
    
    func dismissBanner() {
        self.newlyUnlocked = nil
    }
}
