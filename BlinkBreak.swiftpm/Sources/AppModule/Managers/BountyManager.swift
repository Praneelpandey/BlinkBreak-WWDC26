import SwiftUI
import Combine

struct Bounty: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String
    var target: Int
    var current: Int = 0
    var icon: String 
    
    var isComplete: Bool { current >= target }
}

@MainActor
class BountyManager: ObservableObject {
    @Published var activeBounties: [Bounty] = []
    
    // The master pool of all possible missions.
    private let bountyPool: [(title: String, target: Int, icon: String)] = [
        ("PURGE GLITCHES", 50, "xmark.bin.fill"),
        ("FLY WITHOUT BLINKING", 15, "eye.slash.fill"),
        ("COMPLETE SESSIONS", 3, "flag.checkered.2.crossed"),
        ("DODGE ASTEROIDS", 20, "shield.fill"),
        ("COLLECT SHIELDS", 3, "plus.circle.fill"),
        ("ACHIEVE PERFECT FOCUS", 1, "target"),
        ("LASER FIRE", 100, "bolt.horizontal.fill")
    ]
    
    init() {
        populateInitialBounties()
    }
    
    private func populateInitialBounties() {
        // We always want exactly 3 active bounties on launch.
        while activeBounties.count < 3 {
            activeBounties.append(generateRandomBounty())
        }
    }
    
    private func generateRandomBounty() -> Bounty {
        guard let randomTuple = bountyPool.randomElement() else {
            // Fallback in case pool is empty (impossible in this controlled system)
            return Bounty(title: "UNKNOWN", target: 1, icon: "questionmark")
        }
        
        // Prevent immediate duplicates from appearing in the active array.
        // If it's a duplicate, we recursively generate a new one. (We assume the pool is > 3)
        if activeBounties.contains(where: { $0.title == randomTuple.title }) {
             return generateRandomBounty()
        }
        
        return Bounty(title: randomTuple.title, target: randomTuple.target, icon: randomTuple.icon)
    }
    
    /// Global interface for gameplay systems to increment progress safely.
    func updateBounty(title: String, amount: Int) {
        // Find the index of the bounty that matches the title
        guard let index = activeBounties.firstIndex(where: { $0.title == title }) else { return }
        
        // If it's already complete, do nothing. 
        // Handles cases where rapid successive calls hit before the refresh timeout fires.
        guard !activeBounties[index].isComplete else { return }
        
        activeBounties[index].current += amount
        
        if activeBounties[index].isComplete {
            // Trigger visual completion haptics globally
            HapticManager.shared.playSuccessHaptic()
            AudioManager.shared.playLevelUp() // Re-used for bounty success
            
            // Wait 2 seconds for the user to see the satisfying "check", then organically cycle it out.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                withAnimation(.easeInOut) {
                    self.activeBounties[index] = self.generateRandomBounty()
                }
            }
        }
    }
}
