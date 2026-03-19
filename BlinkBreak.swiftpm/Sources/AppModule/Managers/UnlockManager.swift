import Foundation
import Combine
import SwiftUI

// MARK: - Ship Customization Models

enum PartCategory: String, Codable, CaseIterable {
    case hull   = "HULL"
    case engine = "ENGINE"
    case wings  = "WINGS"
    case trail  = "TRAIL"
    case shield = "SHIELD"
    case core   = "CORE"
}

struct ShipPart: Codable, Identifiable, Hashable {
    let id: String
    let category: PartCategory
    let name: String
    let description: String
    let icon: String
}

// MARK: - Unlock Profile
struct ShipyardProfile: Codable {
    var unlockedParts: Set<String>
    var equippedParts: [PartCategory: String]
}

// MARK: - UnlockManager

@MainActor
class UnlockManager: ObservableObject {
    static let shared = UnlockManager()
    
    @Published var unlockedParts: Set<String> = []
    @Published var equippedParts: [PartCategory: String] = [:]
    
    private let profileURL: URL
    
    /// The master registry of all available parts in the game
    let registry: [ShipPart] = [
        // Engines
        ShipPart(id: "eng_standard", category: .engine, name: "Ion Thruster", description: "Default reliable propulsion.", icon: "flame.fill"),
        ShipPart(id: "eng_plasma", category: .engine, name: "Plasma Drive", description: "Burns hotter, requires a 7-day run streak.", icon: "bolt.fill"),
        
        // Wings
        ShipPart(id: "wng_standard", category: .wings, name: "Aero Fins", description: "Standard aerodynamic wings.", icon: "airplane"),
        ShipPart(id: "wng_holo", category: .wings, name: "Holo Emitters", description: "Energy wings. Earned by surviving 50 sessions.", icon: "wifi"),
        
        // Trails
        ShipPart(id: "trl_none", category: .trail, name: "Stealth", description: "No exhaust trail.", icon: "moon.fill"),
        ShipPart(id: "trl_stardust", category: .trail, name: "Stardust", description: "Leave a pixelated trail. Requires Pilot Level 10.", icon: "sparkles"),
        
        // Shields
        ShipPart(id: "shd_standard", category: .shield, name: "Basic Field", description: "Standard deflection.", icon: "shield.fill"),
        ShipPart(id: "shd_aegis", category: .shield, name: "Aegis Aura", description: "Circular energy ring. Acquired by completing a Perfect Week.", icon: "shield.checkered"),
        
        // Cores
        ShipPart(id: "cor_standard", category: .core, name: "Stock Reactor", description: "Stable output.", icon: "circle.fill"),
        ShipPart(id: "cor_quantum", category: .core, name: "Quantum Heart", description: "Pulsing internal light. Demands 100 total log sessions.", icon: "heart.fill")
    ]
    
    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.profileURL = documents.appendingPathComponent("ShipyardProfile.json")
        
        loadProfile()
    }
    
    // MARK: - Core Logic
    
    func isUnlocked(partID: String) -> Bool {
        return unlockedParts.contains(partID)
    }
    
    func isEquipped(partID: String) -> Bool {
        guard let part = registry.first(where: { $0.id == partID }) else { return false }
        return equippedParts[part.category] == partID
    }
    
    func equip(partID: String) {
        guard unlockedParts.contains(partID) else { return }
        guard let part = registry.first(where: { $0.id == partID }) else { return }
        
        // Rejection haptic / Sound is handled by UI View
        equippedParts[part.category] = partID
        saveProfile()
    }
    
    // MARK: - Rule Engine Integrations
    
    /// Triggered globally on week rollovers, game ends, or rank ups.
    /// Iterates the registry rules against the player's current telemetry payload.
    func checkForUnlocks() {
        var newlyUnlocked = false
        
        let streak = UserDefaults.standard.integer(forKey: "userStreak")
        let level = UserDefaults.standard.integer(forKey: "playerLevel")
        let healthData = HealthDataManager.shared
        
        // eng_plasma (7-day streak)
        if streak >= 7, !unlockedParts.contains("eng_plasma") {
            unlockedParts.insert("eng_plasma")
            newlyUnlocked = true
        }
        
        // wng_holo (50 sessions lifetime)
        let totalLifetimeSessions = UserDefaults.standard.integer(forKey: "totalSessions")
        if totalLifetimeSessions >= 50, !unlockedParts.contains("wng_holo") {
            unlockedParts.insert("wng_holo")
            newlyUnlocked = true
        }
        
        // trl_stardust (Level 10)
        if level >= 10, !unlockedParts.contains("trl_stardust") {
            unlockedParts.insert("trl_stardust")
            newlyUnlocked = true
        }
        
        // shd_aegis (Perfect Week - Focus Time >= 600s + Strain Reduction >= 50% across any archived week)
        for week in healthData.history {
            if week.totalFocusSeconds >= 600 && week.strainReductionPercent >= 50 {
                if !unlockedParts.contains("shd_aegis") {
                    unlockedParts.insert("shd_aegis")
                    newlyUnlocked = true
                }
            }
        }
        
        // cor_quantum (100 sessions lifetime)
        if totalLifetimeSessions >= 100, !unlockedParts.contains("cor_quantum") {
            unlockedParts.insert("cor_quantum")
            newlyUnlocked = true
        }
        
        if newlyUnlocked {
            saveProfile()
            // Can fire Haptic / SFX for background unlocks here
        }
    }
    
    // MARK: - Persistence IO
    
    private func saveProfile() {
        let profile = ShipyardProfile(unlockedParts: unlockedParts, equippedParts: equippedParts)
        do {
            let data = try JSONEncoder().encode(profile)
            try data.write(to: profileURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("❌ Failed to save ShipyardProfile: \(error)")
        }
    }
    
    private func loadProfile() {
        if FileManager.default.fileExists(atPath: profileURL.path) {
            do {
                let data = try Data(contentsOf: profileURL)
                let profile = try JSONDecoder().decode(ShipyardProfile.self, from: data)
                self.unlockedParts = profile.unlockedParts
                self.equippedParts = profile.equippedParts
            } catch {
                print("⚠️ Failed to load ShipyardProfile, reverting to default: \(error)")
                applyDefaults()
            }
        } else {
            applyDefaults()
        }
    }
    
    private func applyDefaults() {
        // Unlock base chassis
        unlockedParts = ["eng_standard", "wng_standard", "trl_none", "shd_standard", "cor_standard"]
        // Equip defaults
        equippedParts = [
            .engine: "eng_standard",
            .wings: "wng_standard",
            .trail: "trl_none",
            .shield: "shd_standard",
            .core: "cor_standard"
        ]
        saveProfile()
    }
}
