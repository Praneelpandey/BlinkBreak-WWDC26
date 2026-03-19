import SwiftUI
import Combine

/// Manages the main "Glitch Hunter" quest chain and career progression.
/// Reads `totalGlitchesPurged` from @AppStorage (already incremented by GameView.persistStats)
/// and `playerXP`/`playerLevel` from the shared AppStorage keys.
@MainActor
class ProgressionManager: ObservableObject {
    static let shared = ProgressionManager()
    
    // MARK: - Quest State (persisted)
    @AppStorage("questTier") var questTier: Int = 1
    @AppStorage("questTargetBase") var questTargetBase: Int = 10
    @AppStorage("questXPReward") var questXPReward: Int = 40
    @AppStorage("glitchesAtQuestStart") var glitchesAtQuestStart: Int = 0
    
    // MARK: - Player Stats (shared with rest of app)
    @AppStorage("totalGlitchesPurged") var totalGlitchesPurged: Int = 0
    @AppStorage("playerXP") var playerXP: Double = 0
    @AppStorage("playerLevel") var playerLevel: Int = 1
    
    // MARK: - UI State
    @Published var showClaimFlash: Bool = false
    
    private let xpPerLevel: Double = 500.0
    
    private init() {}
    
    // MARK: - Computed Properties
    
    /// How many glitches killed since the current quest started
    var questProgress: Int {
        max(0, totalGlitchesPurged - glitchesAtQuestStart)
    }
    
    /// Current quest target for this tier
    var currentQuestTarget: Int {
        questTargetBase
    }
    
    /// Progress fraction 0...1 for the bar
    var questFraction: Double {
        guard currentQuestTarget > 0 else { return 0 }
        return min(1.0, Double(questProgress) / Double(currentQuestTarget))
    }
    
    /// Is the current quest complete?
    var isQuestComplete: Bool {
        questProgress >= currentQuestTarget
    }
    
    /// Quest description text
    var questDescription: String {
        if isQuestComplete {
            return "TARGET ACQUIRED — TAP TO CLAIM"
        } else {
            return "DESTROY \(currentQuestTarget) GLITCHES"
        }
    }
    
    // MARK: - Actions
    
    /// Claim the completed quest reward, advance to next tier.
    func claimQuestReward() {
        guard isQuestComplete else { return }
        
        // Award XP
        playerXP += Double(questXPReward)
        
        // Level up if threshold crossed
        while playerXP >= xpPerLevel {
            playerXP -= xpPerLevel
            playerLevel += 1
        }
        
        // Flash feedback
        showClaimFlash = true
        HapticManager.shared.playSuccessHaptic()
        AudioManager.shared.playLevelUp()
        
        // Advance quest tier
        questTier += 1
        glitchesAtQuestStart = totalGlitchesPurged
        questTargetBase = min(questTargetBase * 2, 500)  // Cap at 500
        questXPReward = min(questXPReward + 20, 200)     // Cap at 200
        
        // Reset flash after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showClaimFlash = false
        }
        
        // Trigger unlock check (new level may unlock items)
        UnlockManager.shared.checkForUnlocks()
    }
}
