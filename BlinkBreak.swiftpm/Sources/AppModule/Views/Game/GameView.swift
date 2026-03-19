import SwiftUI
import SpriteKit

/// The main game screen container.
/// Integrates SpriteKit game, AR input, haptic/audio feedback, eye health tracking, and mission system.
struct GameView: View {
    @Binding var showGame: Bool
    @Binding var showHangar: Bool
    @StateObject private var arManager = ARManager()
    @StateObject private var missionManager = MissionManager()
    
    // Game State
    @State private var score: Int = 0
    @State private var shieldHP: Int = 3
    @State private var maxShieldHP: Int = 3
    @State private var isPaused: Bool = false
    @State private var isGameOver: Bool = false
    @State private var enemiesDestroyed: Int = 0
    @State private var survivalTime: Double = 0.0
    @State private var isGhostMode: Bool = false
    @State private var currentLevel: Int = 1
    @State private var scene: GameScene?
    
    // Combo & Power-Up State
    @State private var comboCount: Int = 0
    @State private var comboMultiplier: Int = 1
    @State private var activePowerUp: String = ""
    @State private var strainPulse: Bool = false
    
    // XP Persistence
    @AppStorage("playerXP") private var playerXP: Double = 0.0
    @AppStorage("playerLevel") private var playerLevel: Int = 1
    private let xpPerLevel: Double = 500.0
    
    // Lifetime Stats Persistence (read by PilotDossierView)
    @AppStorage("totalSessions") private var totalSessions: Int = 0
    @AppStorage("totalGlitchesPurged") private var totalGlitchesPurged: Int = 0
    @AppStorage("totalFocusSeconds") private var totalFocusSeconds: Double = 0.0
    @AppStorage("totalShots") private var totalShots: Int = 0
    @AppStorage("totalHits") private var totalHits: Int = 0
    
    // Hangar display stats (written after each session)
    @AppStorage("lastFocusScore") private var lastFocusScore: Int = 0
    @AppStorage("lastReactionTime") private var lastReactionTime: Double = 0.0
    @AppStorage("userStreak") private var userStreak: Int = 0
    @AppStorage("hasPlayedBefore") private var hasPlayedBefore: Bool = false
    
    // Per-session tracking
    @State private var sessionShots: Int = 0
    @State private var gameID = UUID()
    
    // Accessibility: Manual Override
    @AppStorage("manualOverride") private var manualOverride: Bool = false
    
    // Equipped Ship State (synced from Modular Shipyard)
    @AppStorage("equippedHull") private var equippedHullRaw: String = ShipType.dart.rawValue
    
    // Neural Link Sensitivity (synced from Settings slider)
    @AppStorage("neuralSensitivity") private var neuralSensitivity: Double = 1.0
    
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    /// Pre-computed shield percentage to avoid SwiftUI type-checker timeouts
    private var shieldPercent: Int {
        guard maxShieldHP > 0 else { return 0 }
        return Int(Double(shieldHP) / Double(maxShieldHP) * 100)
    }
    
    /// Pre-computed shield bar fraction
    private var shieldFraction: CGFloat {
        guard maxShieldHP > 0 else { return 0 }
        return CGFloat(shieldHP) / CGFloat(maxShieldHP)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. SpriteKit Game Layer
                SpriteView(scene: scene ?? createScene(size: geometry.size))
                    .ignoresSafeArea()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .id(gameID)
                
                // Manual Override: Touch Gesture Overlay
                if manualOverride {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Map screen Y to scene Y (screen top = scene top)
                                    let screenY = value.location.y
                                    let sceneY = geometry.size.height / 2 - screenY // Flip: screen 0=top, scene 0=center
                                    scene?.manualTargetY = sceneY
                                }
                        )
                        .onTapGesture {
                            scene?.fireLaser()
                            HapticManager.shared.fireLaser()
                            AudioManager.shared.playLaser()
                            sessionShots += 1
                        }
                        .allowsHitTesting(!isPaused && !isGameOver)
                }
                
                // 2. HUD Overlay
                VStack(spacing: 0) {
                    // Top Bar HUD
                    HStack(alignment: .top) {
                        // Distance Card
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DISTANCE:")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(neonCyan.opacity(0.7))
                            Text("\(score)M")
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(neonCyan.opacity(0.3), lineWidth: 1)
                        )
                        
                        // Combo Multiplier Badge
                        if comboMultiplier > 1 {
                            Text(comboCount >= 10 ? "OVERDRIVE" : "x\(comboMultiplier)")
                                .font(.system(size: comboCount >= 10 ? 12 : 16, weight: .black, design: .monospaced))
                                .foregroundColor(.yellow)
                                .shadow(color: .yellow.opacity(0.8), radius: 6)
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        Spacer()
                        
                        // Level + Title
                        VStack(spacing: 2) {
                            Text("BlinkBreak")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(neonCyan.opacity(0.5))
                                .tracking(1)
                            if currentLevel > 1 {
                                Text("LVL \(currentLevel)")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundColor(.yellow)
                            }
                        }
                        
                        Spacer()
                        
                        // Shield Card
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("SHIELDS: \(shieldPercent)%")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.gray.opacity(0.3))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(shieldHP > 1 ? Color.green : Color.red)
                                        .frame(width: geo.size.width * shieldFraction)
                                        .shadow(color: shieldHP > 1 ? .green.opacity(0.6) : .red.opacity(0.6), radius: 4)
                                }
                            }
                            .frame(width: 80, height: 8)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    
                    // Ghost Mode Indicator
                    if isGhostMode {
                        HStack(spacing: 6) {
                            Text("👻")
                                .font(.system(size: 14))
                            Text("GHOST MODE")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(neonCyan)
                            Text("INVINCIBLE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(neonCyan.opacity(0.15))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(neonCyan.opacity(0.4), lineWidth: 1))
                        .transition(.scale.combined(with: .opacity))
                        .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    // Bottom: Active Mission Tracker
                    if let active = missionManager.activeMission {
                        HStack(spacing: 8) {
                            Image(systemName: "target")
                                .foregroundColor(neonCyan)
                                .font(.system(size: 10))
                            
                            Text(active.title)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("\(active.progress)/\(active.target)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(neonCyan)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(neonCyan.opacity(0.2), lineWidth: 1))
                        .padding(.horizontal, 40)
                        .padding(.bottom, 16)
                    }
                    
                    // Active Power-Up Indicator
                    if !activePowerUp.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 10))
                            Text(activePowerUp)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.green.opacity(0.4), lineWidth: 1))
                        .transition(.scale.combined(with: .opacity))
                        .padding(.bottom, 8)
                    }
                    
                    // Pause Button (bottom-right)
                    HStack {
                        Spacer()
                        Button(action: togglePause) {
                            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 8)
                    }
                }
                
                // 3. Tactical Pause Menu
                if isPaused && !isGameOver {
                    TacticalPauseMenu(
                        onResume: togglePause,
                        onRecalibrate: recalibrate,
                        onAbort: exitGame
                    )
                }
                
                // 4. Mission Debrief (Game Over)
                if isGameOver {
                    MissionDebriefView(
                        score: score,
                        enemiesDestroyed: enemiesDestroyed,
                        xpEarned: calculateXP(),
                        currentLevel: currentLevel,
                        blinksPerMinute: arManager.blinksPerMinute,
                        longestStare: arManager.longestStare,
                        totalBlinks: arManager.totalBlinks,
                        survivalTime: survivalTime,
                        onRestart: restartGame,
                        onExit: exitGame
                    )
                }
                
                // 5. Strain Warning Vignette (shieldHP == 1)
                if shieldHP == 1 {
                    Rectangle()
                        .fill(
                            RadialGradient(
                                colors: [.clear, .clear, Color.red.opacity(0.25)],
                                center: .center,
                                startRadius: 120,
                                endRadius: 400
                            )
                        )
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .opacity(strainPulse ? 1 : 0.4)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: strainPulse)
                        .onAppear { strainPulse = true }
                        .onDisappear { strainPulse = false }
                }
            }
        }
        .onAppear {
            arManager.startSession()
            AudioManager.shared.startEngineHum()
            setupGameObservers()
            // Wire manual override setting to scene
            scene?.useManualOverride = manualOverride
        }
        .onDisappear {
            arManager.pauseSession()
            AudioManager.shared.stopEngineHum()
            NotificationCenter.default.removeObserver(self)
        }
        .onChange(of: arManager.eyeLookUp) { newValue in
            scene?.eyeLookUp = newValue
        }
        .onChange(of: arManager.eyeLookDown) { newValue in
            scene?.eyeLookDown = newValue
        }
        .onChange(of: arManager.isBlinking) { isBlinking in
            if isBlinking {
                scene?.fireLaser()
                HapticManager.shared.fireLaser()
                AudioManager.shared.playLaser()
                sessionShots += 1
            }
        }
        .onChange(of: arManager.isHeadTilted) { tilted in
            if tilted {
                scene?.performBarrelRoll()
                HapticManager.shared.barrelRoll()
                AudioManager.shared.playBarrelRoll()
            }
        }
    }
    
    @EnvironmentObject var bountyManager: BountyManager
    
    // MARK: - Logic
    
    private func createScene(size: CGSize) -> GameScene {
        let newScene = GameScene(size: size)
        newScene.scaleMode = .aspectFill
        newScene.useManualOverride = manualOverride
        
        // Inject equipped ship configuration
        newScene.equippedHull = ShipType(rawValue: equippedHullRaw) ?? .dart
        newScene.equippedParts = UnlockManager.shared.equippedParts
        
        // Inject Neural Link Sensitivity
        newScene.neuralSensitivity = CGFloat(neuralSensitivity)
        
        DispatchQueue.main.async { self.scene = newScene }
        return newScene
    }
    
    private func togglePause() {
        isPaused.toggle()
        scene?.isPaused = isPaused
    }
    
    private func recalibrate() {
        arManager.pauseSession()
        arManager.startSession()
        isPaused = false
        scene?.isPaused = false
    }
    
    private func exitGame() {
        awardXP()
        AudioManager.shared.stopEngineHum()
        showGame = false
        showHangar = true
    }
    
    private func restartGame() {
        isGameOver = false
        score = 0
        shieldHP = 3
        enemiesDestroyed = 0
        survivalTime = 0
        currentLevel = 1
        sessionShots = 0
        comboCount = 0
        comboMultiplier = 1
        activePowerUp = ""
        scene = nil
        gameID = UUID()
        arManager.pauseSession()
        arManager.startSession()
    }
    
    private func calculateXP() -> Int {
        return score + (enemiesDestroyed * 5) + (currentLevel * 20)
    }
    
    private func awardXP() {
        let earned = Double(calculateXP())
        playerXP += earned
        
        while playerXP >= xpPerLevel {
            playerXP -= xpPerLevel
            playerLevel += 1
        }
    }
    
    /// Persist per-session stats into the lifetime @AppStorage totals
    private func persistStats() {
        totalSessions += 1
        totalGlitchesPurged += enemiesDestroyed
        totalFocusSeconds += survivalTime
        totalShots += sessionShots
        totalHits += enemiesDestroyed // Each destroyed enemy = 1 hit
    }
    
    private func setupGameObservers() {
        NotificationCenter.default.addObserver(forName: .gameEnded, object: nil, queue: .main) { notif in
            let enemies = notif.userInfo?["enemiesDestroyed"] as? Int ?? 0
            let survival = notif.userInfo?["survivalTime"] as? Double ?? 0
            let telemetryData = notif.userInfo?["telemetry"] as? [SessionTelemetry] ?? []
            
            Task { @MainActor in
                self.enemiesDestroyed = enemies
                self.survivalTime = survival
                withAnimation { self.isGameOver = true }
                self.awardXP()
                self.persistStats()
                
                // Write real session data for Hangar display
                self.lastFocusScore = ProgressManager.shared.visionIndexScore
                self.lastReactionTime = self.survivalTime
                self.userStreak += 1
                self.hasPlayedBefore = true
                
                // NEW: Send raw health telemetry to the Weekly local archive
                HealthDataManager.shared.reportSession(
                    blinks: arManager.totalBlinks,
                    focusSeconds: self.survivalTime,
                    activeBreakSeconds: 0 
                )
                
                // Record per-day stats for Pilot Dossier bar charts
                HealthDataManager.shared.recordDailySession(
                    kills: enemies,
                    focusSeconds: self.survivalTime,
                    shots: self.sessionShots,
                    hits: enemies
                )
                
                // NEW: Gamification hooks
                let damageTaken = 3 - self.shieldHP
                ProgressManager.shared.reportSessionMetrics(blinks: arManager.totalBlinks, damageTaken: damageTaken)
                
                // NEW: Update Live Bounties
                bountyManager.updateBounty(title: "COMPLETE SESSIONS", amount: 1)
                
                if damageTaken == 0 {
                    bountyManager.updateBounty(title: "ACHIEVE PERFECT FOCUS", amount: 1)
                }
                
                let star = FocusStar(
                    date: Date(),
                    focusScore: Double(ProgressManager.shared.visionIndexScore),
                    duration: self.survivalTime,
                    telemetry: telemetryData
                )
                ProgressManager.shared.saveFocusStar(star)
                
                // NEW: Recheck Shipyard unlocks globally after payload is ingested
                UnlockManager.shared.checkForUnlocks()
                
                // Notify ProgressionManager that kills have been recorded (triggers UI update on HangarView card)
                ProgressionManager.shared.objectWillChange.send()
                
                self.missionManager.reportGameEnd(score: self.score, kills: self.enemiesDestroyed, survivalSeconds: self.survivalTime)
                HapticManager.shared.gameOver()
                AudioManager.shared.playGameOver()
            }
        }
        NotificationCenter.default.addObserver(forName: .gameScoreUpdated, object: nil, queue: .main) { notif in
            let s = notif.userInfo?["score"] as? Int ?? 0
            Task { @MainActor in
                self.score = s
                self.missionManager.reportProgress(distance: s, kills: self.enemiesDestroyed, survivalSeconds: self.survivalTime)
            }
        }
        NotificationCenter.default.addObserver(forName: .shieldUpdated, object: nil, queue: .main) { notif in
            let hp = notif.userInfo?["shieldHP"] as? Int ?? 3
            let maxHP = notif.userInfo?["maxShieldHP"] as? Int ?? 3
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.2)) {
                    self.shieldHP = hp
                    self.maxShieldHP = maxHP
                }
                if hp < maxHP && hp > 0 {
                    HapticManager.shared.playerHit()
                    AudioManager.shared.playDamage()
                }
                if hp == 1 {
                    HapticManager.shared.shieldWarning()
                    AudioManager.shared.playShieldWarning()
                }
            }
        }
        NotificationCenter.default.addObserver(forName: .enemyDestroyed, object: nil, queue: .main) { notif in
            let total = notif.userInfo?["total"] as? Int ?? 0
            Task { @MainActor in
                self.enemiesDestroyed = total
                bountyManager.updateBounty(title: "PURGE GLITCHES", amount: 1)
                HapticManager.shared.enemyDestroyed()
                AudioManager.shared.playExplosion()
            }
        }
        NotificationCenter.default.addObserver(forName: .ghostModeActivated, object: nil, queue: .main) { _ in
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.2)) { self.isGhostMode = true }
            }
        }
        NotificationCenter.default.addObserver(forName: .ghostModeEnded, object: nil, queue: .main) { _ in
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.2)) { self.isGhostMode = false }
            }
        }
        NotificationCenter.default.addObserver(forName: .levelUp, object: nil, queue: .main) { notif in
            let level = notif.userInfo?["level"] as? Int ?? 1
            Task { @MainActor in
                self.currentLevel = level
                HapticManager.shared.hyperJump()
                AudioManager.shared.playHyperJump()
            }
        }
        NotificationCenter.default.addObserver(forName: .comboUpdated, object: nil, queue: .main) { notif in
            let combo = notif.userInfo?["combo"] as? Int ?? 0
            let multiplier = notif.userInfo?["multiplier"] as? Int ?? 1
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.2)) {
                    self.comboCount = combo
                    self.comboMultiplier = multiplier
                }
            }
        }
        NotificationCenter.default.addObserver(forName: .powerUpCollected, object: nil, queue: .main) { notif in
            let type = notif.userInfo?["type"] as? String ?? ""
            Task { @MainActor in
                withAnimation { self.activePowerUp = type }
                if type.contains("SHIELD") {
                    bountyManager.updateBounty(title: "COLLECT SHIELDS", amount: 1)
                }
                HapticManager.shared.fireLaser()
            }
        }
        NotificationCenter.default.addObserver(forName: .powerUpExpired, object: nil, queue: .main) { _ in
            Task { @MainActor in
                withAnimation { self.activePowerUp = "" }
            }
        }
        NotificationCenter.default.addObserver(forName: .distanceFlew, object: nil, queue: .main) { notif in
            let dist = notif.userInfo?["distance"] as? Int ?? 0
            // Since distance is a rolling total per session, we find delta if needed.
            // For simple bounties, we can track total score accumulated.
            // But we'll just feed 1 every ~70 units of distance natively generated from GameScene.
            if dist % 5 == 0 { // Throttle slightly to prevent UI micro-stutters
                Task { @MainActor in
                    bountyManager.updateBounty(title: "FLY WITHOUT BLINKING", amount: 1)
                    bountyManager.updateBounty(title: "DODGE ASTEROIDS", amount: 1) // Rough proxy
                }
            }
        }
        NotificationCenter.default.addObserver(forName: .laserFired, object: nil, queue: .main) { _ in
             Task { @MainActor in
                 self.sessionShots += 1
                 bountyManager.updateBounty(title: "LASER FIRE", amount: 1)
             }
         }
    }
}

// MARK: - Tactical Pause Menu (Frosted Glass)

struct TacticalPauseMenu: View {
    var onResume: () -> Void
    var onRecalibrate: () -> Void
    var onAbort: () -> Void
    
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Title
                Text("⏸ TACTICAL PAUSE")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(2)
                    .shadow(color: neonCyan.opacity(0.5), radius: 10)
                
                Text("Take a moment. Stretch your neck.")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                
                VStack(spacing: 12) {
                    // Resume
                    Button(action: onResume) {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                            Text("RESUME MISSION")
                        }
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.vertical, 14)
                        .frame(maxWidth: 240)
                        .background(neonCyan)
                        .clipShape(Capsule())
                        .shadow(color: neonCyan.opacity(0.5), radius: 8)
                    }
                    
                    // Recalibrate
                    Button(action: onRecalibrate) {
                        HStack(spacing: 10) {
                            Image(systemName: "face.smiling")
                            Text("RECALIBRATE")
                        }
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: 240)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(neonCyan.opacity(0.4), lineWidth: 1))
                    }
                    
                    // Abort
                    Button(action: onAbort) {
                        HStack(spacing: 10) {
                            Image(systemName: "xmark.octagon")
                            Text("ABORT MISSION")
                        }
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.vertical, 14)
                        .frame(maxWidth: 240)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1))
                    }
                }
                .padding(.top, 8)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(neonCyan.opacity(0.15), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 30)
        }
    }
}

// MARK: - Mission Debrief (Eye Health Report Card)

struct MissionDebriefView: View {
    let score: Int
    let enemiesDestroyed: Int
    let xpEarned: Int
    let currentLevel: Int
    let blinksPerMinute: Double
    let longestStare: Double
    let totalBlinks: Int
    let survivalTime: Double
    var onRestart: () -> Void
    var onExit: () -> Void
    
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    private var blinkHealth: String {
        // Normal adult blink rate is 15-20 BPM
        if blinksPerMinute >= 15 { return "Excellent" }
        if blinksPerMinute >= 10 { return "Good" }
        if blinksPerMinute >= 5 { return "Low" }
        return "Very Low"
    }
    
    private var blinkHealthColor: Color {
        if blinksPerMinute >= 15 { return .green }
        if blinksPerMinute >= 10 { return .yellow }
        return .red
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Header
                    Text("MISSION DEBRIEF")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(3)
                        .shadow(color: neonCyan.opacity(0.5), radius: 10)
                    
                    Text("SYSTEM FAILURE • LEVEL \(currentLevel)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.red.opacity(0.8))
                    
                    // ── Flight Stats ──
                    VStack(spacing: 12) {
                        Text("FLIGHT DATA")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(neonCyan.opacity(0.6))
                            .tracking(2)
                        
                        HStack(spacing: 12) {
                            DebriefStat(icon: "location.fill", label: "DISTANCE", value: "\(score)M", color: neonCyan)
                            DebriefStat(icon: "flame.fill", label: "DESTROYED", value: "\(enemiesDestroyed)", color: .orange)
                            DebriefStat(icon: "clock.fill", label: "SURVIVED", value: String(format: "%.0fs", survivalTime), color: .purple)
                        }
                        
                        HStack(spacing: 12) {
                            DebriefStat(icon: "star.fill", label: "XP EARNED", value: "+\(xpEarned)", color: .green)
                            DebriefStat(icon: "bolt.fill", label: "LEVEL", value: "\(currentLevel)", color: .yellow)
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(neonCyan.opacity(0.15), lineWidth: 1))
                    
                    // ── Eye Health Report ──
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "eye.fill")
                                .foregroundColor(neonCyan)
                            Text("EYE HEALTH REPORT")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundColor(neonCyan.opacity(0.6))
                                .tracking(2)
                        }
                        
                        HStack(spacing: 12) {
                            DebriefStat(
                                icon: "eye.trianglebadge.exclamationmark",
                                label: "BLINKS/MIN",
                                value: String(format: "%.1f", blinksPerMinute),
                                color: blinkHealthColor
                            )
                            DebriefStat(
                                icon: "timer",
                                label: "MAX STARE",
                                value: String(format: "%.1fs", longestStare),
                                color: longestStare > 10 ? .red : .green
                            )
                            DebriefStat(
                                icon: "eye.slash.fill",
                                label: "TOTAL BLINKS",
                                value: "\(totalBlinks)",
                                color: .white
                            )
                        }
                        
                        // Health verdict
                        HStack(spacing: 6) {
                            Circle()
                                .fill(blinkHealthColor)
                                .frame(width: 8, height: 8)
                                .shadow(color: blinkHealthColor, radius: 4)
                            Text("Blink Health: \(blinkHealth)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(blinkHealthColor)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                        .background(blinkHealthColor.opacity(0.1))
                        .cornerRadius(8)
                        
                        if longestStare > 8 {
                            Text("⚠ You went \(String(format: "%.1f", longestStare))s without blinking. Remember to blink!")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.yellow.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(blinkHealthColor.opacity(0.2), lineWidth: 1))
                    
                    // ── Action Buttons ──
                    HStack(spacing: 20) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onRestart()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title2)
                                Text("RETRY")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(neonCyan)
                            .frame(width: 70, height: 70)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(neonCyan.opacity(0.5), lineWidth: 1.5))
                            .shadow(color: neonCyan.opacity(0.3), radius: 6)
                        }
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            onExit()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "house.fill")
                                    .font(.title2)
                                Text("HANGAR")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 70, height: 70)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1.5))
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 40)
            }
        }
    }
}

/// Individual stat cell for the Mission Debrief
struct DebriefStat: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.3), radius: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.06))
        .cornerRadius(8)
    }
}
