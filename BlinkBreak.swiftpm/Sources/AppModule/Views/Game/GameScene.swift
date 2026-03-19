import SpriteKit
import GameplayKit

/// The SpriteKit scene — cyberpunk infinite runner with a holographic paper airplane.
/// Matches the reference design: translucent paper plane, tall city skyline, pink neon grid.
class GameScene: SKScene, @preconcurrency SKPhysicsContactDelegate {
    
    // MARK: - Game Entities
    private var player: SKSpriteNode!
    private var shieldRing: SKShapeNode?
    
    // MARK: - Game State
    var isGameRunning: Bool = false
    var score: Int = 0
    var distanceTraveled: Double = 0.0
    var shieldHP: Int = 3 { didSet { postShieldUpdate() } }
    var enemiesDestroyed: Int = 0
    var survivalTime: Double = 0.0
    
    // MARK: - Combo System
    var comboCount: Int = 0
    var comboMultiplier: Int = 1
    
    // MARK: - Power-Up State
    var isDoubleLaser: Bool = false
    var isSlowMo: Bool = false
    private var lastPowerUpSpawnTime: TimeInterval = 0
    private var powerUpSpawnInterval: TimeInterval = 18.0
    
    // MARK: - Telemetry Engine
    var sessionTelemetry: [SessionTelemetry] = []
    private var lastTelemetryTime: TimeInterval = 0
    
    // MARK: - Input (from SwiftUI)
    var eyeLookUp: Float = 0.0
    var eyeLookDown: Float = 0.0
    
    // MARK: - Manual Override (Accessibility)
    var useManualOverride: Bool = false
    var manualTargetY: CGFloat = 0.0
    
    // MARK: - Neural Link Sensitivity (from Settings slider, 0.5–2.0)
    var neuralSensitivity: CGFloat = 1.0
    
    // MARK: - Barrel Roll / Ghost Mode
    private var isGhostMode: Bool = false
    private var isBarrelRolling: Bool = false
    private var ghostModeTimer: TimeInterval = 0
    
    // MARK: - Shooting
    private var lastFireTime: TimeInterval = 0
    private var fireCooldown: TimeInterval = 0.28
    
    // MARK: - Configuration
    private var scrollSpeed: CGFloat = 220.0
    private var obstacleSpawnRate: TimeInterval = 2.2
    private var lastSpawnTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    
    // MARK: - Equipped Ship Configuration (set by GameView before didMove)
    var equippedHull: ShipType = .dart
    var equippedParts: [PartCategory: String] = [:]
    
    // MARK: - Equipment-Derived Stats (computed in applyEquipmentStats)
    private var maxShieldHP: Int = 3
    private var equipLerpFactor: CGFloat = 0.12
    private var ghostDuration: TimeInterval = 2.0
    private var powerUpDuration: TimeInterval = 5.0
    private var baseScrollSpeed: CGFloat = 220.0
    private var speedCap1: CGFloat = 400.0  // Phase 1 difficulty cap
    private var speedCap2: CGFloat = 520.0  // Phase 2 difficulty cap
    
    // MARK: - Level Progression
    var currentLevel: Int = 1
    private let distancePerLevel: Double = 35000 // ~500 score = 500 * 70
    private var nextLevelThreshold: Double = 35000
    private var isHyperJumping: Bool = false
    
    // Layout (set in didMove)
    private var playerXPos: CGFloat = 0
    private var halfW: CGFloat = 0
    private var halfH: CGFloat = 0
    
    // MARK: - Physics Categories
    private struct Cat {
        static let none: UInt32 = 0
        static let player: UInt32 = 0x1 << 0
        static let obstacle: UInt32 = 0x1 << 1
        static let laser: UInt32 = 0x1 << 2
        static let powerup: UInt32 = 0x1 << 3
    }
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        backgroundColor = .black // AMOLED pure black
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        halfW = size.width / 2
        halfH = size.height / 2
        playerXPos = -halfW + size.width * 0.22
        
        setupStarfield()
        setupCitySkyline()
        setupNeonGrid()
        setupPlayer()
        applyEquipmentStats()
        startGame()
    }
    
    // MARK: - Equipment Stats Engine
    
    /// Reads equippedHull + equippedParts and computes all gameplay stat bonuses.
    /// Called once after setupPlayer(), before startGame().
    private func applyEquipmentStats() {
        // ── 1. Hull Base Stats ──
        var speedMult: CGFloat   = 1.0
        var agilityMult: CGFloat = 1.0
        var hullShieldHP: Int    = 3
        var fireRateMult: CGFloat = 1.0
        
        switch equippedHull {
        case .dart:
            break // Balanced — all 1.0x
        case .rocket:   // VANGUARD — fastest hull
            speedMult   = 1.12
            agilityMult = 0.9
        case .fighter:  // RAPTOR — glass cannon
            fireRateMult = 1.25
            agilityMult  = 1.1
            hullShieldHP = 2
        case .ufo:      // PHANTOM — best agility
            speedMult   = 0.9
            agilityMult = 1.3
        case .satellite: // ORBITAL — tankiest
            speedMult   = 0.85
            agilityMult = 0.85
            hullShieldHP = 4
            fireRateMult = 0.9
        }
        
        // ── 2. Part Bonuses ──
        
        // Engine
        let hasPlasma = equippedParts[.engine] == "eng_plasma"
        if hasPlasma {
            speedMult *= 1.20   // +20% speed
        }
        
        // Wings
        let hasHoloWings = equippedParts[.wings] == "wng_holo"
        if hasHoloWings {
            agilityMult *= 1.50 // +50% agility
            ghostDuration = 3.0 // 3s ghost mode (vs 2s)
        } else {
            ghostDuration = 2.0
        }
        
        // Trail
        let hasStardust = equippedParts[.trail] == "trl_stardust"
        if hasStardust {
            powerUpSpawnInterval = 12.5 // 30% faster power-ups
        } else {
            powerUpSpawnInterval = 18.0
        }
        
        // Shield
        let hasAegis = equippedParts[.shield] == "shd_aegis"
        if hasAegis {
            hullShieldHP += 1   // +1 shield HP
        }
        
        // Core
        let hasQuantum = equippedParts[.core] == "cor_quantum"
        if hasQuantum {
            fireRateMult *= 1.25  // 25% faster fire rate
            powerUpDuration = 7.0 // Power-ups last 7s (vs 5s)
        } else {
            powerUpDuration = 5.0
        }
        
        // ── 3. Apply Computed Values ──
        baseScrollSpeed = 220.0 * speedMult
        equipLerpFactor = 0.12 * agilityMult
        maxShieldHP     = hullShieldHP
        fireCooldown    = 0.28 / fireRateMult
        speedCap1       = 400.0 * speedMult
        speedCap2       = 520.0 * speedMult
    }
    
    // MARK: - Dynamic Player Ship (reads equippedHull)
    
    private func setupPlayer() {
        let u = max(size.width * 0.023, 8.0)
        
        player = SKSpriteNode(color: .clear, size: CGSize(width: u * 8, height: u * 5))
        player.position = CGPoint(x: playerXPos, y: 0)
        player.zPosition = 10
        
        // Build hull geometry based on equipped ship type
        switch equippedHull {
        case .dart:      buildDartHull(u: u)
        case .rocket:    buildRocketHull(u: u)
        case .fighter:   buildFighterHull(u: u)
        case .ufo:       buildUFOHull(u: u)
        case .satellite: buildSatelliteHull(u: u)
        }
        
        // ── Shared: Engine Trail ──
        let isPlasma = equippedParts[.engine] == "eng_plasma"
        let trailColor = isPlasma
            ? UIColor(red: 0.5, green: 0.0, blue: 0.9, alpha: 0.5)
            : UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.5)
        let trailLen = u * 4.0
        
        let trail = SKShapeNode(rectOf: CGSize(width: trailLen, height: u * 0.2), cornerRadius: u * 0.1)
        trail.fillColor = trailColor
        trail.strokeColor = .clear
        trail.blendMode = .add
        trail.position = CGPoint(x: -u * 3.5 - trailLen / 2, y: 0)
        trail.zPosition = 0
        player.addChild(trail)
        
        let trailFade = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.25, duration: 0.3),
            SKAction.fadeAlpha(to: 0.6, duration: 0.3)
        ])
        trail.run(SKAction.repeatForever(trailFade))
        
        // Wider, fainter outer trail
        let outerTrailColor = isPlasma
            ? UIColor(red: 0.3, green: 0.0, blue: 0.6, alpha: 0.15)
            : UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.15)
        let outerTrail = SKShapeNode(rectOf: CGSize(width: trailLen * 1.3, height: u * 0.5), cornerRadius: u * 0.25)
        outerTrail.fillColor = outerTrailColor
        outerTrail.strokeColor = .clear
        outerTrail.blendMode = .add
        outerTrail.position = CGPoint(x: -u * 3.5 - trailLen * 0.65, y: 0)
        outerTrail.zPosition = -1
        player.addChild(outerTrail)
        
        // Plasma dual exhaust dots
        if isPlasma {
            let dot1 = SKShapeNode(circleOfRadius: u * 0.3)
            dot1.fillColor = UIColor(red: 0.6, green: 0.0, blue: 1.0, alpha: 0.8)
            dot1.strokeColor = .clear
            dot1.glowWidth = 4
            dot1.blendMode = .add
            dot1.position = CGPoint(x: -u * 3.5, y: u * 0.6)
            dot1.zPosition = 0
            player.addChild(dot1)
            
            let dot2 = SKShapeNode(circleOfRadius: u * 0.3)
            dot2.fillColor = UIColor(red: 0.6, green: 0.0, blue: 1.0, alpha: 0.8)
            dot2.strokeColor = .clear
            dot2.glowWidth = 4
            dot2.blendMode = .add
            dot2.position = CGPoint(x: -u * 3.5, y: -u * 0.6)
            dot2.zPosition = 0
            player.addChild(dot2)
            
            let pulseDot = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.25),
                SKAction.fadeAlpha(to: 0.9, duration: 0.25)
            ])
            dot1.run(SKAction.repeatForever(pulseDot))
            dot2.run(SKAction.repeatForever(pulseDot))
        }
        
        // ── Shared: Ambient Glow ──
        let glowColor = isPlasma
            ? UIColor(red: 0.4, green: 0.0, blue: 0.8, alpha: 1.0)
            : UIColor(red: 0.0, green: 0.7, blue: 1.0, alpha: 1.0)
        let glow = SKShapeNode(circleOfRadius: u * 2.5)
        glow.fillColor = glowColor
        glow.strokeColor = .clear
        glow.alpha = 0.08
        glow.blendMode = .add
        glow.zPosition = -2
        player.addChild(glow)
        
        let glowPulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.15, duration: 1.2),
            SKAction.fadeAlpha(to: 0.05, duration: 1.2)
        ])
        glow.run(SKAction.repeatForever(glowPulse))
        
        // ── Shared: Shield Ring ──
        let ring = SKShapeNode(circleOfRadius: u * 3.0)
        ring.strokeColor = UIColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.35)
        ring.lineWidth = 1.5
        ring.fillColor = .clear
        ring.glowWidth = 4
        ring.zPosition = 5
        player.addChild(ring)
        shieldRing = ring
        
        // ── Shared: Physics ──
        player.physicsBody = SKPhysicsBody(circleOfRadius: u * 1.5)
        player.physicsBody?.categoryBitMask = Cat.player
        player.physicsBody?.contactTestBitMask = Cat.obstacle
        player.physicsBody?.collisionBitMask = Cat.none
        player.physicsBody?.isDynamic = true
        
        addChild(player)
    }
    
    // MARK: - Ship Hull Builders
    
    /// DART — the original holographic paper airplane
    private func buildDartHull(u: CGFloat) {
        // Bottom wing (darker — shadow side)
        let bottomWing = CGMutablePath()
        bottomWing.move(to: CGPoint(x: u * 4.0, y: 0))
        bottomWing.addLine(to: CGPoint(x: -u * 3.0, y: -u * 2.2))
        bottomWing.addLine(to: CGPoint(x: -u * 2.5, y: -u * 0.8))
        bottomWing.addLine(to: CGPoint(x: -u * 3.5, y: -u * 0.3))
        bottomWing.addLine(to: CGPoint(x: -u * 3.5, y: 0))
        bottomWing.closeSubpath()
        
        let bottomShape = SKShapeNode(path: bottomWing)
        bottomShape.fillColor = UIColor(red: 0.0, green: 0.45, blue: 0.55, alpha: 0.45)
        bottomShape.strokeColor = UIColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.7)
        bottomShape.lineWidth = 1.5
        bottomShape.glowWidth = 2
        bottomShape.zPosition = 1
        player.addChild(bottomShape)
        
        // Top wing (lighter — lit side)
        let topWing = CGMutablePath()
        topWing.move(to: CGPoint(x: u * 4.0, y: 0))
        topWing.addLine(to: CGPoint(x: -u * 3.5, y: 0))
        topWing.addLine(to: CGPoint(x: -u * 3.5, y: u * 0.3))
        topWing.addLine(to: CGPoint(x: -u * 2.5, y: u * 0.8))
        topWing.addLine(to: CGPoint(x: -u * 3.0, y: u * 2.2))
        topWing.closeSubpath()
        
        let topShape = SKShapeNode(path: topWing)
        topShape.fillColor = UIColor(red: 0.0, green: 0.6, blue: 0.7, alpha: 0.55)
        topShape.strokeColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.85)
        topShape.lineWidth = 1.5
        topShape.glowWidth = 2
        topShape.zPosition = 2
        player.addChild(topShape)
        
        // Center fold line
        let foldLine = SKShapeNode()
        let foldPath = CGMutablePath()
        foldPath.move(to: CGPoint(x: u * 4.0, y: 0))
        foldPath.addLine(to: CGPoint(x: -u * 3.5, y: 0))
        foldLine.path = foldPath
        foldLine.strokeColor = UIColor(red: 0.5, green: 1.0, blue: 1.0, alpha: 0.9)
        foldLine.lineWidth = 1.5
        foldLine.glowWidth = 3
        foldLine.zPosition = 3
        player.addChild(foldLine)
        
        // Nose dot
        addNoseDot(u: u, position: CGPoint(x: u * 4.0, y: 0))
    }
    
    /// ROCKET — vertical capsule body rotated for side-scrolling, with triangular fins
    private func buildRocketHull(u: CGFloat) {
        // Main fuselage — horizontal capsule (rotated for side-scroll: nose = right)
        let bodyLen = u * 5.5
        let bodyW = u * 2.2
        let body = SKShapeNode(rectOf: CGSize(width: bodyLen, height: bodyW), cornerRadius: bodyW * 0.45)
        body.fillColor = UIColor(red: 0.0, green: 0.6, blue: 0.75, alpha: 0.5)
        body.strokeColor = UIColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.8)
        body.lineWidth = 1.5
        body.glowWidth = 2
        body.position = CGPoint(x: u * 0.5, y: 0)
        body.zPosition = 1
        player.addChild(body)
        
        // Nose cone (right-pointing triangle)
        let nose = CGMutablePath()
        nose.move(to: CGPoint(x: u * 4.5, y: 0))              // tip
        nose.addLine(to: CGPoint(x: u * 3.0, y: u * 1.1))     // top base
        nose.addLine(to: CGPoint(x: u * 3.0, y: -u * 1.1))    // bottom base
        nose.closeSubpath()
        let noseShape = SKShapeNode(path: nose)
        noseShape.fillColor = UIColor(red: 0.0, green: 0.7, blue: 0.8, alpha: 0.6)
        noseShape.strokeColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.9)
        noseShape.lineWidth = 1.5
        noseShape.glowWidth = 2
        noseShape.zPosition = 2
        player.addChild(noseShape)
        
        // Top fin
        let topFin = CGMutablePath()
        topFin.move(to: CGPoint(x: -u * 2.0, y: u * 1.0))
        topFin.addLine(to: CGPoint(x: -u * 3.5, y: u * 2.8))
        topFin.addLine(to: CGPoint(x: -u * 2.8, y: u * 1.0))
        topFin.closeSubpath()
        let topFinShape = SKShapeNode(path: topFin)
        topFinShape.fillColor = UIColor(red: 0.0, green: 0.5, blue: 0.65, alpha: 0.4)
        topFinShape.strokeColor = UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.7)
        topFinShape.lineWidth = 1
        topFinShape.glowWidth = 2
        topFinShape.zPosition = 1
        player.addChild(topFinShape)
        
        // Bottom fin
        let botFin = CGMutablePath()
        botFin.move(to: CGPoint(x: -u * 2.0, y: -u * 1.0))
        botFin.addLine(to: CGPoint(x: -u * 3.5, y: -u * 2.8))
        botFin.addLine(to: CGPoint(x: -u * 2.8, y: -u * 1.0))
        botFin.closeSubpath()
        let botFinShape = SKShapeNode(path: botFin)
        botFinShape.fillColor = UIColor(red: 0.0, green: 0.5, blue: 0.65, alpha: 0.4)
        botFinShape.strokeColor = UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.7)
        botFinShape.lineWidth = 1
        botFinShape.glowWidth = 2
        botFinShape.zPosition = 1
        player.addChild(botFinShape)
        
        // Viewport window
        let viewport = SKShapeNode(circleOfRadius: u * 0.5)
        viewport.fillColor = UIColor(red: 0.0, green: 0.3, blue: 0.4, alpha: 0.6)
        viewport.strokeColor = UIColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.5)
        viewport.lineWidth = 1
        viewport.position = CGPoint(x: u * 1.5, y: 0)
        viewport.zPosition = 3
        player.addChild(viewport)
        
        addNoseDot(u: u, position: CGPoint(x: u * 4.5, y: 0))
    }
    
    /// FIGHTER — aggressive delta wing shape
    private func buildFighterHull(u: CGFloat) {
        // Main delta body
        let delta = CGMutablePath()
        delta.move(to: CGPoint(x: u * 4.0, y: 0))              // sharp nose
        delta.addLine(to: CGPoint(x: -u * 2.5, y: u * 2.5))    // top wing tip
        delta.addLine(to: CGPoint(x: -u * 1.0, y: u * 0.8))    // top wing inner
        delta.addLine(to: CGPoint(x: -u * 2.0, y: u * 1.5))    // top tail
        delta.addLine(to: CGPoint(x: -u * 1.5, y: 0))           // center tail notch
        delta.addLine(to: CGPoint(x: -u * 2.0, y: -u * 1.5))   // bottom tail
        delta.addLine(to: CGPoint(x: -u * 1.0, y: -u * 0.8))   // bottom wing inner
        delta.addLine(to: CGPoint(x: -u * 2.5, y: -u * 2.5))   // bottom wing tip
        delta.closeSubpath()
        
        let deltaShape = SKShapeNode(path: delta)
        deltaShape.fillColor = UIColor(red: 0.0, green: 0.55, blue: 0.65, alpha: 0.5)
        deltaShape.strokeColor = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.85)
        deltaShape.lineWidth = 1.5
        deltaShape.glowWidth = 2
        deltaShape.zPosition = 1
        player.addChild(deltaShape)
        
        // Cockpit canopy stripe
        let canopy = CGMutablePath()
        canopy.move(to: CGPoint(x: u * 3.0, y: 0))
        canopy.addLine(to: CGPoint(x: u * 1.0, y: u * 0.5))
        canopy.addLine(to: CGPoint(x: u * 1.0, y: -u * 0.5))
        canopy.closeSubpath()
        let canopyShape = SKShapeNode(path: canopy)
        canopyShape.fillColor = UIColor(red: 0.0, green: 0.3, blue: 0.45, alpha: 0.4)
        canopyShape.strokeColor = UIColor(red: 0.3, green: 0.9, blue: 1.0, alpha: 0.6)
        canopyShape.lineWidth = 1
        canopyShape.zPosition = 2
        player.addChild(canopyShape)
        
        // Center spine line
        let spine = SKShapeNode()
        let spinePath = CGMutablePath()
        spinePath.move(to: CGPoint(x: u * 4.0, y: 0))
        spinePath.addLine(to: CGPoint(x: -u * 1.5, y: 0))
        spine.path = spinePath
        spine.strokeColor = UIColor(red: 0.4, green: 1.0, blue: 1.0, alpha: 0.7)
        spine.lineWidth = 1
        spine.glowWidth = 2
        spine.zPosition = 3
        player.addChild(spine)
        
        addNoseDot(u: u, position: CGPoint(x: u * 4.0, y: 0))
    }
    
    /// UFO — flying saucer oriented sideways for side-scrolling
    private func buildUFOHull(u: CGFloat) {
        // Main saucer disc (horizontal ellipse)
        let saucer = SKShapeNode(ellipseOf: CGSize(width: u * 7.0, height: u * 2.5))
        saucer.fillColor = UIColor(red: 0.0, green: 0.5, blue: 0.6, alpha: 0.45)
        saucer.strokeColor = UIColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.75)
        saucer.lineWidth = 1.5
        saucer.glowWidth = 2
        saucer.zPosition = 1
        player.addChild(saucer)
        
        // Saucer rim ring
        let rim = SKShapeNode(ellipseOf: CGSize(width: u * 7.5, height: u * 2.8))
        rim.fillColor = .clear
        rim.strokeColor = UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.3)
        rim.lineWidth = 0.8
        rim.zPosition = 1
        player.addChild(rim)
        
        // Top dome (smaller ellipse on top)
        let dome = SKShapeNode(ellipseOf: CGSize(width: u * 2.8, height: u * 1.8))
        dome.fillColor = UIColor(red: 0.0, green: 0.7, blue: 0.8, alpha: 0.35)
        dome.strokeColor = UIColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.5)
        dome.lineWidth = 1
        dome.position = CGPoint(x: 0, y: u * 0.6)
        dome.zPosition = 2
        player.addChild(dome)
        
        // Underside lights
        for offset in [-u * 1.5, CGFloat(0), u * 1.5] {
            let light = SKShapeNode(circleOfRadius: u * 0.25)
            light.fillColor = UIColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.6)
            light.strokeColor = .clear
            light.glowWidth = 3
            light.blendMode = .add
            light.position = CGPoint(x: offset, y: -u * 0.8)
            light.zPosition = 2
            player.addChild(light)
            
            let blink = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.2, duration: 0.4),
                SKAction.fadeAlpha(to: 0.8, duration: 0.4)
            ])
            light.run(SKAction.repeatForever(blink))
        }
        
        // Leading edge dot
        addNoseDot(u: u, position: CGPoint(x: u * 3.5, y: 0))
    }
    
    /// SATELLITE — central body with solar panel arrays
    private func buildSatelliteHull(u: CGFloat) {
        // Central body (rounded rectangle)
        let bodyNode = SKShapeNode(rectOf: CGSize(width: u * 2.0, height: u * 2.5), cornerRadius: u * 0.3)
        bodyNode.fillColor = UIColor(red: 0.0, green: 0.55, blue: 0.65, alpha: 0.5)
        bodyNode.strokeColor = UIColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.8)
        bodyNode.lineWidth = 1.5
        bodyNode.glowWidth = 2
        bodyNode.zPosition = 2
        player.addChild(bodyNode)
        
        // Solar panel arms
        let topArm = SKShapeNode(rectOf: CGSize(width: u * 0.3, height: u * 2.0))
        topArm.fillColor = UIColor(red: 0.0, green: 0.7, blue: 0.8, alpha: 0.5)
        topArm.strokeColor = .clear
        topArm.position = CGPoint(x: 0, y: u * 2.2)
        topArm.zPosition = 1
        player.addChild(topArm)
        
        let botArm = SKShapeNode(rectOf: CGSize(width: u * 0.3, height: u * 2.0))
        botArm.fillColor = UIColor(red: 0.0, green: 0.7, blue: 0.8, alpha: 0.5)
        botArm.strokeColor = .clear
        botArm.position = CGPoint(x: 0, y: -u * 2.2)
        botArm.zPosition = 1
        player.addChild(botArm)
        
        // Top solar panel
        let topPanel = SKShapeNode(rectOf: CGSize(width: u * 2.5, height: u * 1.8), cornerRadius: u * 0.1)
        topPanel.fillColor = UIColor(red: 0.0, green: 0.5, blue: 0.6, alpha: 0.45)
        topPanel.strokeColor = UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.65)
        topPanel.lineWidth = 1
        topPanel.glowWidth = 1
        topPanel.position = CGPoint(x: 0, y: u * 3.2)
        topPanel.zPosition = 1
        player.addChild(topPanel)
        
        // Panel grid lines (top)
        for gridY in stride(from: -u * 0.6, through: u * 0.6, by: u * 0.4) {
            let gridLine = SKShapeNode(rectOf: CGSize(width: u * 2.3, height: 0.5))
            gridLine.fillColor = UIColor(red: 0.0, green: 0.7, blue: 0.8, alpha: 0.3)
            gridLine.strokeColor = .clear
            gridLine.position = CGPoint(x: 0, y: u * 3.2 + gridY)
            gridLine.zPosition = 1
            player.addChild(gridLine)
        }
        
        // Bottom solar panel
        let botPanel = SKShapeNode(rectOf: CGSize(width: u * 2.5, height: u * 1.8), cornerRadius: u * 0.1)
        botPanel.fillColor = UIColor(red: 0.0, green: 0.5, blue: 0.6, alpha: 0.45)
        botPanel.strokeColor = UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.65)
        botPanel.lineWidth = 1
        botPanel.glowWidth = 1
        botPanel.position = CGPoint(x: 0, y: -u * 3.2)
        botPanel.zPosition = 1
        player.addChild(botPanel)
        
        // Panel grid lines (bottom)
        for gridY in stride(from: -u * 0.6, through: u * 0.6, by: u * 0.4) {
            let gridLine = SKShapeNode(rectOf: CGSize(width: u * 2.3, height: 0.5))
            gridLine.fillColor = UIColor(red: 0.0, green: 0.7, blue: 0.8, alpha: 0.3)
            gridLine.strokeColor = .clear
            gridLine.position = CGPoint(x: 0, y: -u * 3.2 + gridY)
            gridLine.zPosition = 1
            player.addChild(gridLine)
        }
        
        // Antenna dish on front
        let antenna = SKShapeNode(circleOfRadius: u * 0.4)
        antenna.fillColor = UIColor(red: 0.0, green: 0.8, blue: 0.9, alpha: 0.5)
        antenna.strokeColor = UIColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.6)
        antenna.lineWidth = 1
        antenna.position = CGPoint(x: u * 1.5, y: 0)
        antenna.zPosition = 3
        player.addChild(antenna)
        
        addNoseDot(u: u, position: CGPoint(x: u * 1.5, y: 0))
    }
    
    // MARK: - Shared Nose Dot
    
    private func addNoseDot(u: CGFloat, position: CGPoint) {
        let noseDot = SKShapeNode(circleOfRadius: u * 0.3)
        noseDot.fillColor = .white
        noseDot.strokeColor = .clear
        noseDot.alpha = 0.8
        noseDot.blendMode = .add
        noseDot.position = position
        noseDot.zPosition = 4
        player.addChild(noseDot)
        
        let nosePulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 0.6),
            SKAction.fadeAlpha(to: 0.9, duration: 0.6)
        ])
        noseDot.run(SKAction.repeatForever(nosePulse))
    }
    
    // MARK: - Starfield
    
    private func setupStarfield() {
        // Layer 1: Far stars — tiny, slow, creates depth
        let createFarStar = SKAction.run { [weak self] in
            guard let self = self else { return }
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.3...0.8))
            star.fillColor = .white
            star.strokeColor = .clear
            star.alpha = CGFloat.random(in: 0.1...0.3)
            star.position = CGPoint(x: self.halfW + 10, y: CGFloat.random(in: -self.halfH...self.halfH))
            star.zPosition = -12
            self.addChild(star)
            let speed = TimeInterval.random(in: 4.0...8.0)
            star.run(SKAction.sequence([SKAction.moveBy(x: -self.size.width - 20, y: 0, duration: speed), .removeFromParent()]))
        }
        run(SKAction.repeatForever(SKAction.sequence([createFarStar, SKAction.wait(forDuration: 0.12)])))
        
        // Layer 2: Mid stars — moderate speed
        let createMidStar = SKAction.run { [weak self] in
            guard let self = self else { return }
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...1.2))
            star.fillColor = .white
            star.strokeColor = .clear
            star.alpha = CGFloat.random(in: 0.2...0.45)
            star.position = CGPoint(x: self.halfW + 10, y: CGFloat.random(in: -self.halfH...self.halfH))
            star.zPosition = -11
            self.addChild(star)
            let speed = TimeInterval.random(in: 2.5...5.0)
            star.run(SKAction.sequence([SKAction.moveBy(x: -self.size.width - 20, y: 0, duration: speed), .removeFromParent()]))
        }
        run(SKAction.repeatForever(SKAction.sequence([createMidStar, SKAction.wait(forDuration: 0.1)])))
        
        // Layer 3: Near stars — larger, fast, foreground streaks
        let createNearStar = SKAction.run { [weak self] in
            guard let self = self else { return }
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.0...2.0))
            star.fillColor = .white
            star.strokeColor = .clear
            star.alpha = CGFloat.random(in: 0.3...0.6)
            star.position = CGPoint(x: self.halfW + 10, y: CGFloat.random(in: -self.halfH...self.halfH))
            star.zPosition = -9
            self.addChild(star)
            let speed = TimeInterval.random(in: 1.5...3.0)
            star.run(SKAction.sequence([SKAction.moveBy(x: -self.size.width - 20, y: 0, duration: speed), .removeFromParent()]))
        }
        run(SKAction.repeatForever(SKAction.sequence([createNearStar, SKAction.wait(forDuration: 0.15)])))
    }
    
    // MARK: - City Skyline (tall, detailed, matching reference)
    
    private func setupCitySkyline() {
        let skylineNode = SKNode()
        skylineNode.zPosition = -5
        
        let groundY = -halfH
        // The skyline covers the bottom ~45% of screen like the reference
        let maxBuildingH = halfH * 0.9
        var xPos: CGFloat = -halfW - 10
        
        while xPos < halfW + 60 {
            let bWidth = CGFloat.random(in: 20...55)
            // Mix of short and tall buildings
            let heightRoll = CGFloat.random(in: 0...1)
            let bHeight: CGFloat
            if heightRoll > 0.7 {
                bHeight = CGFloat.random(in: maxBuildingH * 0.6...maxBuildingH) // Tall towers
            } else if heightRoll > 0.3 {
                bHeight = CGFloat.random(in: maxBuildingH * 0.3...maxBuildingH * 0.6) // Medium
            } else {
                bHeight = CGFloat.random(in: maxBuildingH * 0.15...maxBuildingH * 0.35) // Short
            }
            
            let building = SKShapeNode(rectOf: CGSize(width: bWidth, height: bHeight))
            // Dark silhouette with very subtle blue tint
            building.fillColor = UIColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1.0) // AMOLED near-black
            building.strokeColor = UIColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 0.25)
            building.lineWidth = 0.5
            building.position = CGPoint(x: xPos + bWidth / 2, y: groundY + bHeight / 2)
            skylineNode.addChild(building)
            
            // Windows — more for tall buildings
            let windowCols = max(1, Int(bWidth / 10))
            let windowRows = max(1, Int(bHeight / 18))
            for col in 0..<windowCols {
                for row in 0..<windowRows {
                    if CGFloat.random(in: 0...1) > 0.45 { continue } // Random lit/unlit
                    let wx = -bWidth / 2 + 6 + CGFloat(col) * (bWidth / CGFloat(windowCols))
                    let wy = -bHeight / 2 + 8 + CGFloat(row) * 16
                    let window = SKShapeNode(rectOf: CGSize(width: 3, height: 4))
                    
                    // Mix of cyan and warm yellow windows
                    if CGFloat.random(in: 0...1) > 0.3 {
                        window.fillColor = UIColor(red: 0.0, green: 0.7, blue: 1.0, alpha: CGFloat.random(in: 0.15...0.4))
                    } else {
                        window.fillColor = UIColor(red: 1.0, green: 0.9, blue: 0.5, alpha: CGFloat.random(in: 0.1...0.3))
                    }
                    window.strokeColor = .clear
                    window.position = CGPoint(x: wx, y: wy)
                    building.addChild(window)
                }
            }
            
            // Occasional antenna/spire on tall buildings
            if bHeight > maxBuildingH * 0.5 && CGFloat.random(in: 0...1) > 0.5 {
                let spire = SKShapeNode(rectOf: CGSize(width: 1.5, height: bHeight * 0.15))
                spire.fillColor = UIColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1.0)
                spire.strokeColor = .clear
                spire.position = CGPoint(x: 0, y: bHeight / 2 + bHeight * 0.075)
                building.addChild(spire)
                
                // Red blinking light on top
                let light = SKShapeNode(circleOfRadius: 1.5)
                light.fillColor = .red
                light.strokeColor = .clear
                light.glowWidth = 3
                light.position = CGPoint(x: 0, y: bHeight / 2 + bHeight * 0.15)
                building.addChild(light)
                let blink = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.2, duration: 0.8),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.8)
                ])
                light.run(SKAction.repeatForever(blink))
            }
            
            xPos += bWidth + CGFloat.random(in: 1...6)
        }
        
        addChild(skylineNode)
    }
    
    // MARK: - Neon Grid (vibrant pink/magenta perspective grid)
    
    private func setupNeonGrid() {
        let gridNode = SKNode()
        gridNode.zPosition = -4
        
        let groundY = -halfH
        let gridHeight: CGFloat = halfH * 0.5 // Bottom 25% of screen
        
        // Horizontal lines with perspective (closer together at horizon)
        let lineCount = 14
        for i in 0..<lineCount {
            let fraction = CGFloat(i) / CGFloat(lineCount - 1)
            // Non-linear spacing — lines bunch up toward horizon
            let y = groundY + gridHeight * pow(fraction, 0.6)
            
            let line = SKShapeNode(rectOf: CGSize(width: size.width + 20, height: 0.8))
            // Gradient from pink/magenta at bottom to cyan at horizon
            let pinkAmount = 1.0 - fraction
            let cyanAmount = fraction
            line.fillColor = UIColor(
                red: 0.8 * pinkAmount,
                green: 0.0 + 0.5 * cyanAmount,
                blue: 0.9 * pinkAmount + 1.0 * cyanAmount,
                alpha: 0.25 * (1.0 - fraction * 0.5)
            )
            line.strokeColor = .clear
            line.position = CGPoint(x: 0, y: y)
            line.blendMode = .add
            gridNode.addChild(line)
        }
        
        // Vertical lines (converge toward horizon — fake perspective)
        let vertCount = 18
        let horizonY = groundY + gridHeight
        for i in 0..<vertCount {
            let fraction = CGFloat(i) / CGFloat(vertCount - 1)
            let bottomX = -halfW * 1.5 + fraction * (size.width * 1.5)
            let topX = -halfW * 0.6 + fraction * (size.width * 0.6) // Converge toward center
            
            let path = CGMutablePath()
            path.move(to: CGPoint(x: bottomX, y: groundY))
            path.addLine(to: CGPoint(x: topX, y: horizonY))
            
            let vLine = SKShapeNode(path: path)
            vLine.strokeColor = UIColor(red: 0.7, green: 0.0, blue: 0.9, alpha: 0.15)
            vLine.lineWidth = 0.6
            vLine.blendMode = .add
            gridNode.addChild(vLine)
        }
        
        // Horizon glow line
        let horizonGlow = SKShapeNode(rectOf: CGSize(width: size.width, height: 2))
        horizonGlow.fillColor = UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.3)
        horizonGlow.strokeColor = .clear
        horizonGlow.blendMode = .add
        horizonGlow.position = CGPoint(x: 0, y: horizonY)
        gridNode.addChild(horizonGlow)
        
        addChild(gridNode)
    }
    
    // MARK: - Game Loop
    
    override func update(_ currentTime: TimeInterval) {
        guard isGameRunning else { return }
        
        let dt: TimeInterval
        if lastUpdateTime == 0 { dt = 0.016 }
        else { dt = min(currentTime - lastUpdateTime, 0.05) }
        lastUpdateTime = currentTime
        
        updatePlayerMovement(dt: dt)
        updateScrolling(dt: dt)
        
        if currentTime - lastSpawnTime > obstacleSpawnRate {
            spawnObstacle()
            lastSpawnTime = currentTime
        }
        
        distanceTraveled += Double(scrollSpeed) * dt
        score = Int(distanceTraveled / 70)
        survivalTime += dt
        
        // Post regular distance updates for live Bounties
        NotificationCenter.default.post(name: .distanceFlew, object: nil, userInfo: ["distance": score])
        
        // Telemetry Sampling (~2Hz)
        if currentTime - lastTelemetryTime > 0.5 {
            lastTelemetryTime = currentTime
            let normalizedY = (Double(player.position.y) + Double(halfH)) / Double(size.height)
            sessionTelemetry.append(SessionTelemetry(timeOffset: survivalTime, playerY: normalizedY, event: nil))
        }
        
        NotificationCenter.default.post(name: .gameScoreUpdated, object: nil, userInfo: ["score": score])
        
        // Ghost mode countdown
        if isGhostMode {
            ghostModeTimer -= dt
            if ghostModeTimer <= 0 {
                endGhostMode()
            }
        }
        
        // Difficulty ramp (caps scale with equipment)
        if distanceTraveled > 4000 {
            scrollSpeed = min(scrollSpeed + CGFloat(dt) * 2.5, speedCap1)
            obstacleSpawnRate = max(obstacleSpawnRate - dt * 0.012, 1.3)
        }
        if distanceTraveled > 12000 {
            scrollSpeed = min(scrollSpeed + CGFloat(dt) * 3, speedCap2)
            obstacleSpawnRate = max(obstacleSpawnRate - dt * 0.02, 0.8)
        }
        
        // Level progression — hyperjump trigger
        if distanceTraveled >= nextLevelThreshold && !isHyperJumping {
            triggerHyperJump()
        }
        
        // Power-up spawning
        if currentTime - lastPowerUpSpawnTime > powerUpSpawnInterval {
            spawnPowerUp()
            lastPowerUpSpawnTime = currentTime
        }
    }
    
    private func updatePlayerMovement(dt: TimeInterval) {
        // ── Micro-Glance Eye Tracking System ──
        //
        // 1. SENSITIVITY MULTIPLIER — amplify raw ARKit values so a 15-20%
        //    glance moves the plane across the entire screen.
        // 2. DEADZONE — ignore microsaccades (tiny eye twitches) below threshold
        //    to keep the plane rock-stable when staring straight.
        // 3. CLAMP — cap the target Y within screen bounds so amplification
        //    can never push the plane off-screen.
        // 4. LERP — smoothly glide the plane to the target position instead
        //    of teleporting, giving a floaty, responsive feel.
        
        let baseSensitivity: CGFloat = 4.5   // Base multiplier — small glance → big movement
        let sensitivity = baseSensitivity * neuralSensitivity  // Scaled by Neural Link slider
        let deadzone: Float     = 0.05      // Ignore eye values below this
        
        // Net eye direction: positive = up, negative = down
        let rawUp   = eyeLookUp  > deadzone ? eyeLookUp  : 0.0
        let rawDown = eyeLookDown > deadzone ? eyeLookDown : 0.0
        let netGaze = CGFloat(rawUp - rawDown)                    // Ranges roughly -0.5...0.5
        
        let maxY = halfH - 50
        let minY = -halfH + 50
        
        // Manual Override: touch control takes priority when active
        let clampedTarget: CGFloat
        if useManualOverride && manualTargetY != 0.0 {
            clampedTarget = max(min(manualTargetY, maxY), minY)
        } else {
            let targetY = netGaze * sensitivity * halfH
            clampedTarget = max(min(targetY, maxY), minY)
        }
        
        // Lerp — smooth glide to target (equipLerpFactor boosted by wing upgrades)
        let previousY = player.position.y
        player.position.y = previousY + (clampedTarget - previousY) * equipLerpFactor
        
        // Subtle nose pitch based on movement delta (skip if barrel rolling)
        guard !isBarrelRolling else { return }
        let moveDelta = player.position.y - previousY
        let targetTilt = max(min(moveDelta * 0.008, 0.12), -0.12) // ±7° max
        player.zRotation += (targetTilt - player.zRotation) * 0.1
    }
    
    private func updateScrolling(dt: TimeInterval) {
        enumerateChildNodes(withName: "obstacle") { node, _ in
            node.position.x -= self.scrollSpeed * CGFloat(dt)
            if node.position.x < -self.halfW - 80 {
                node.removeFromParent()
            }
        }
        enumerateChildNodes(withName: "powerup") { node, _ in
            node.position.x -= self.scrollSpeed * CGFloat(dt)
            if node.position.x < -self.halfW - 80 {
                node.removeFromParent()
            }
        }
    }
    
    // MARK: - Shooting (long cyan laser beam)
    
    func fireLaser() {
        guard isGameRunning else { return }
        let now = CACurrentMediaTime()
        guard now - lastFireTime > fireCooldown else { return }
        lastFireTime = now
        
        let u = max(size.width * 0.023, 8.0)
        
        // Long laser beam like the reference image
        let beamLength = size.width * 0.35
        let beam = SKShapeNode(rectOf: CGSize(width: beamLength, height: 3), cornerRadius: 1.5)
        beam.name = "laser"
        beam.fillColor = UIColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.9)
        beam.strokeColor = .clear
        beam.glowWidth = 6
        beam.blendMode = .add
        beam.position = CGPoint(x: player.position.x + u * 4 + beamLength / 2, y: player.position.y)
        beam.zPosition = 8
        
        beam.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: beamLength, height: 3))
        beam.physicsBody?.categoryBitMask = Cat.laser
        beam.physicsBody?.contactTestBitMask = Cat.obstacle
        beam.physicsBody?.collisionBitMask = Cat.none
        beam.physicsBody?.isDynamic = true
        
        addChild(beam)
        
        // Inner bright core
        let core = SKShapeNode(rectOf: CGSize(width: beamLength, height: 1), cornerRadius: 0.5)
        core.fillColor = .white
        core.strokeColor = .clear
        core.alpha = 0.7
        core.blendMode = .add
        beam.addChild(core)
        
        NotificationCenter.default.post(name: .laserFired, object: nil)
        
        let normalizedY = (Double(player.position.y) + Double(halfH)) / Double(size.height)
        sessionTelemetry.append(SessionTelemetry(timeOffset: survivalTime, playerY: normalizedY, event: .blink))
        
        let shoot = SKAction.moveBy(x: size.width, y: 0, duration: 0.45)
        beam.run(SKAction.sequence([shoot, .removeFromParent()]))
        
        // Double Laser power-up: fire a second purple beam offset upward
        if isDoubleLaser {
            let beam2 = SKShapeNode(rectOf: CGSize(width: beamLength, height: 3), cornerRadius: 1.5)
            beam2.name = "laser"
            beam2.fillColor = UIColor(red: 0.6, green: 0.0, blue: 1.0, alpha: 0.9)
            beam2.strokeColor = .clear
            beam2.glowWidth = 6
            beam2.blendMode = .add
            beam2.position = CGPoint(x: player.position.x + u * 4 + beamLength / 2, y: player.position.y + 20)
            beam2.zPosition = 8
            beam2.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: beamLength, height: 3))
            beam2.physicsBody?.categoryBitMask = Cat.laser
            beam2.physicsBody?.contactTestBitMask = Cat.obstacle
            beam2.physicsBody?.collisionBitMask = Cat.none
            beam2.physicsBody?.isDynamic = true
            addChild(beam2)
            let shoot2 = SKAction.moveBy(x: size.width, y: 0, duration: 0.45)
            beam2.run(SKAction.sequence([shoot2, .removeFromParent()]))
        }
    }
    
    // MARK: - Barrel Roll & Ghost Mode
    
    /// Called when the user tilts their head — triggers a 360° barrel roll and 2s ghost mode
    func performBarrelRoll() {
        guard isGameRunning && !isBarrelRolling && !isGhostMode else { return }
        
        isBarrelRolling = true
        
        // 360° spin animation
        let fullSpin = SKAction.rotate(byAngle: CGFloat.pi * 2, duration: 0.5)
        fullSpin.timingMode = .easeInEaseOut
        
        player.run(fullSpin) {
            self.isBarrelRolling = false
        }
        
        // Activate ghost mode
        startGhostMode()
        
        // VFX: cyan flash ring expanding from player
        let ring = SKShapeNode(circleOfRadius: 15)
        ring.strokeColor = UIColor(red: 0, green: 0.94, blue: 1, alpha: 0.8)
        ring.fillColor = .clear
        ring.glowWidth = 8
        ring.lineWidth = 2
        ring.position = player.position
        ring.zPosition = 20
        addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 8.0, duration: 0.4),
                SKAction.fadeOut(withDuration: 0.4)
            ]),
            .removeFromParent()
        ]))
        
        // "GHOST MODE" text banner
        let label = SKLabelNode(text: "👻 GHOST MODE")
        label.fontName = "Menlo-Bold"
        label.fontSize = 16
        label.fontColor = UIColor(red: 0, green: 0.94, blue: 1, alpha: 1)
        label.position = CGPoint(x: 0, y: halfH * 0.4)
        label.zPosition = 50
        label.alpha = 0
        addChild(label)
        label.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.15),
            SKAction.wait(forDuration: 1.0),
            SKAction.fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }
    
    private func startGhostMode() {
        isGhostMode = true
        ghostModeTimer = ghostDuration  // Boosted by Holo Wings
        
        // Make player semi-transparent and shimmer
        let shimmer = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.15),
            SKAction.fadeAlpha(to: 0.7, duration: 0.15)
        ])
        player.run(SKAction.repeatForever(shimmer), withKey: "ghostShimmer")
        
        // Disable player-obstacle collision detection
        player.physicsBody?.contactTestBitMask = Cat.none
        
        // Cyan aura around ship during ghost mode
        let aura = SKShapeNode(circleOfRadius: 40)
        aura.name = "ghostAura"
        aura.fillColor = UIColor(red: 0, green: 0.8, blue: 1, alpha: 0.1)
        aura.strokeColor = UIColor(red: 0, green: 0.94, blue: 1, alpha: 0.3)
        aura.glowWidth = 8
        aura.blendMode = .add
        aura.zPosition = -1
        player.addChild(aura)
        
        let auraPulse = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ])
        aura.run(SKAction.repeatForever(auraPulse))
        
        NotificationCenter.default.post(name: .ghostModeActivated, object: nil)
    }
    
    private func endGhostMode() {
        isGhostMode = false
        
        player.removeAction(forKey: "ghostShimmer")
        player.alpha = 1.0
        
        // Restore collision detection
        player.physicsBody?.contactTestBitMask = Cat.obstacle
        
        // Remove ghost aura
        player.childNode(withName: "ghostAura")?.removeFromParent()
        
        NotificationCenter.default.post(name: .ghostModeEnded, object: nil)
    }
    
    // MARK: - Obstacles (glowing red cubes like reference)
    
    private func spawnObstacle() {
        // Select enemy type based on level and survival time
        let roll = Int.random(in: 0...100)
        
        if survivalTime > 60 && roll > 92 {
            spawnBossNode()
        } else if currentLevel >= 2 && roll > 70 {
            spawnChaosBlock()
        } else if currentLevel >= 2 && roll > 50 {
            spawnShieldDrone()
        } else {
            spawnBasicGlitch()
        }
    }
    
    /// Original red cube enemy — slow, fragile, 1 HP
    private func spawnBasicGlitch() {
        let obsSize = max(size.width * 0.1, 35)
        
        let obstacle = SKShapeNode(rectOf: CGSize(width: obsSize, height: obsSize), cornerRadius: 3)
        obstacle.name = "obstacle"
        obstacle.fillColor = UIColor.red.withAlphaComponent(0.06)
        obstacle.strokeColor = UIColor.red
        obstacle.lineWidth = 2.5
        obstacle.glowWidth = 8
        obstacle.zPosition = 5
        
        let innerSize = obsSize * 0.5
        let inner = SKShapeNode(rectOf: CGSize(width: innerSize, height: innerSize), cornerRadius: 2)
        inner.fillColor = UIColor.red.withAlphaComponent(0.15)
        inner.strokeColor = UIColor.red.withAlphaComponent(0.7)
        inner.lineWidth = 1.5
        inner.glowWidth = 3
        obstacle.addChild(inner)
        
        let crossH = SKShapeNode(rectOf: CGSize(width: innerSize * 0.7, height: 2))
        crossH.fillColor = .red
        crossH.strokeColor = .clear
        crossH.alpha = 0.5
        inner.addChild(crossH)
        
        let crossV = SKShapeNode(rectOf: CGSize(width: 2, height: innerSize * 0.7))
        crossV.fillColor = .red
        crossV.strokeColor = .clear
        crossV.alpha = 0.5
        inner.addChild(crossV)
        
        let spin = SKAction.rotate(byAngle: .pi * 2, duration: Double.random(in: 4...8))
        obstacle.run(SKAction.repeatForever(spin))
        
        let pulse = SKAction.sequence([
            SKAction.run { obstacle.glowWidth = 12 },
            SKAction.wait(forDuration: 0.3),
            SKAction.run { obstacle.glowWidth = 6 },
            SKAction.wait(forDuration: 0.3)
        ])
        obstacle.run(SKAction.repeatForever(pulse))
        
        obstacle.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: obsSize * 0.8, height: obsSize * 0.8))
        obstacle.physicsBody?.categoryBitMask = Cat.obstacle
        obstacle.physicsBody?.contactTestBitMask = Cat.player | Cat.laser
        obstacle.physicsBody?.collisionBitMask = Cat.none
        obstacle.physicsBody?.isDynamic = false
        
        let maxY = halfH - 70
        let minY = -halfH + 70
        obstacle.position = CGPoint(x: halfW + obsSize, y: CGFloat.random(in: minY...maxY))
        
        addChild(obstacle)
    }
    
    /// Blue Shield Drone — requires 2 hits to destroy
    private func spawnShieldDrone() {
        let obsSize = max(size.width * 0.09, 30)
        let drone = SKShapeNode(rectOf: CGSize(width: obsSize, height: obsSize * 0.6), cornerRadius: 6)
        drone.name = "obstacle"
        drone.fillColor = UIColor(red: 0.0, green: 0.3, blue: 0.8, alpha: 0.15)
        drone.strokeColor = UIColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 1.0)
        drone.lineWidth = 2
        drone.glowWidth = 6
        drone.zPosition = 5
        drone.userData = NSMutableDictionary(dictionary: ["hitCount": 0, "maxHP": 2])
        
        let shieldIcon = SKLabelNode(text: "🛡")
        shieldIcon.fontSize = 14
        shieldIcon.verticalAlignmentMode = .center
        drone.addChild(shieldIcon)
        
        drone.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: obsSize * 0.8, height: obsSize * 0.5))
        drone.physicsBody?.categoryBitMask = Cat.obstacle
        drone.physicsBody?.contactTestBitMask = Cat.player | Cat.laser
        drone.physicsBody?.collisionBitMask = Cat.none
        drone.physicsBody?.isDynamic = false
        
        let maxY = halfH - 70
        let minY = -halfH + 70
        drone.position = CGPoint(x: halfW + obsSize, y: CGFloat.random(in: minY...maxY))
        addChild(drone)
    }
    
    /// Yellow Chaos Block — zig-zag movement pattern
    private func spawnChaosBlock() {
        let obsSize = max(size.width * 0.08, 28)
        let block = SKShapeNode(rectOf: CGSize(width: obsSize, height: obsSize), cornerRadius: 2)
        block.name = "obstacle"
        block.fillColor = UIColor.yellow.withAlphaComponent(0.1)
        block.strokeColor = .yellow
        block.lineWidth = 2
        block.glowWidth = 5
        block.zPosition = 5
        
        block.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: obsSize * 0.8, height: obsSize * 0.8))
        block.physicsBody?.categoryBitMask = Cat.obstacle
        block.physicsBody?.contactTestBitMask = Cat.player | Cat.laser
        block.physicsBody?.collisionBitMask = Cat.none
        block.physicsBody?.isDynamic = false
        
        let maxY = halfH - 100
        let minY = -halfH + 100
        block.position = CGPoint(x: halfW + obsSize, y: CGFloat.random(in: minY...maxY))
        
        // Zig-zag sine wave movement
        let zigzag = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 60, duration: 0.4),
            SKAction.moveBy(x: 0, y: -120, duration: 0.8),
            SKAction.moveBy(x: 0, y: 60, duration: 0.4)
        ])
        block.run(SKAction.repeatForever(zigzag))
        
        let spin = SKAction.rotate(byAngle: .pi * 2, duration: 2)
        block.run(SKAction.repeatForever(spin))
        
        addChild(block)
    }
    
    /// Large purple Boss Node — 4 HP, appears after 60s survival
    private func spawnBossNode() {
        let obsSize = max(size.width * 0.15, 55)
        let boss = SKShapeNode(rectOf: CGSize(width: obsSize, height: obsSize), cornerRadius: 8)
        boss.name = "obstacle"
        boss.fillColor = UIColor.purple.withAlphaComponent(0.12)
        boss.strokeColor = UIColor.purple
        boss.lineWidth = 3
        boss.glowWidth = 10
        boss.zPosition = 5
        boss.userData = NSMutableDictionary(dictionary: ["hitCount": 0, "maxHP": 4])
        
        let core = SKShapeNode(circleOfRadius: obsSize * 0.2)
        core.fillColor = UIColor.purple.withAlphaComponent(0.4)
        core.strokeColor = .clear
        core.glowWidth = 8
        core.blendMode = .add
        boss.addChild(core)
        
        let label = SKLabelNode(text: "⚠️")
        label.fontSize = 18
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -obsSize * 0.35)
        boss.addChild(label)
        
        boss.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: obsSize * 0.8, height: obsSize * 0.8))
        boss.physicsBody?.categoryBitMask = Cat.obstacle
        boss.physicsBody?.contactTestBitMask = Cat.player | Cat.laser
        boss.physicsBody?.collisionBitMask = Cat.none
        boss.physicsBody?.isDynamic = false
        
        let maxY = halfH - 100
        let minY = -halfH + 100
        boss.position = CGPoint(x: halfW + obsSize, y: CGFloat.random(in: minY...maxY))
        
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.8),
            SKAction.scale(to: 1.0, duration: 0.8)
        ])
        boss.run(SKAction.repeatForever(pulse))
        
        addChild(boss)
    }
    
    // MARK: - Destruction VFX ("Juice")
    
    private func spawnDestroyEffect(at position: CGPoint) {
        // ── SCREEN SHAKE (violent 0.2s vibration) ──
        let shakeR = SKAction.moveBy(x: 12, y: 3, duration: 0.025)
        let shakeL = SKAction.moveBy(x: -24, y: -6, duration: 0.025)
        let shakeC = SKAction.moveBy(x: 12, y: 3, duration: 0.025)
        let oneShake = SKAction.sequence([shakeR, shakeL, shakeC])
        self.run(SKAction.repeat(oneShake, count: 4))
        
        // ── BRIGHT WHITE FLASH (momentary full-screen) ──
        let screenFlash = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: size.height * 2))
        screenFlash.fillColor = .white
        screenFlash.strokeColor = .clear
        screenFlash.alpha = 0.15
        screenFlash.blendMode = .add
        screenFlash.zPosition = 50
        addChild(screenFlash)
        screenFlash.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.1), .removeFromParent()]))
        
        // ── CORE EXPLOSION FLASH ──
        let flash = SKShapeNode(circleOfRadius: 30)
        flash.fillColor = UIColor(red: 1.0, green: 0.3, blue: 0.1, alpha: 1.0)
        flash.strokeColor = .clear
        flash.alpha = 1.0
        flash.blendMode = .add
        flash.position = position
        flash.zPosition = 16
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 5.0, duration: 0.12),
                SKAction.fadeOut(withDuration: 0.18)
            ]),
            .removeFromParent()
        ]))
        
        // Secondary cyan flash
        let flashCyan = SKShapeNode(circleOfRadius: 20)
        flashCyan.fillColor = .cyan
        flashCyan.strokeColor = .clear
        flashCyan.alpha = 0.8
        flashCyan.blendMode = .add
        flashCyan.position = position
        flashCyan.zPosition = 15
        addChild(flashCyan)
        flashCyan.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 3.5, duration: 0.15),
                SKAction.fadeOut(withDuration: 0.2)
            ]),
            .removeFromParent()
        ]))
        
        // ── PARTICLE BURST (14 particles with varying colors) ──
        for _ in 0..<14 {
            let size = CGFloat.random(in: 1.5...4)
            let spark = SKShapeNode(circleOfRadius: size)
            let colorRoll = CGFloat.random(in: 0...1)
            if colorRoll < 0.4 {
                spark.fillColor = .red
            } else if colorRoll < 0.7 {
                spark.fillColor = .cyan
            } else if colorRoll < 0.9 {
                spark.fillColor = .yellow
            } else {
                spark.fillColor = .white
            }
            spark.strokeColor = .clear
            spark.blendMode = .add
            spark.position = position
            spark.zPosition = 14
            addChild(spark)
            
            let angle = CGFloat.random(in: 0...CGFloat.pi * 2)
            let dist = CGFloat.random(in: 60...180)
            let dx = cos(angle) * dist
            let dy = sin(angle) * dist
            let duration = Double.random(in: 0.3...0.6)
            
            spark.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: duration),
                    SKAction.fadeOut(withDuration: duration),
                    SKAction.scale(to: 0.05, duration: duration)
                ]),
                .removeFromParent()
            ]))
        }
        
        // ── DEBRIS TRAILS (3 longer streaks) ──
        for _ in 0..<3 {
            let debris = SKShapeNode(rectOf: CGSize(width: 12, height: 2), cornerRadius: 1)
            debris.fillColor = .orange
            debris.strokeColor = .clear
            debris.blendMode = .add
            debris.alpha = 0.8
            debris.position = position
            debris.zPosition = 13
            addChild(debris)
            
            let angle = CGFloat.random(in: 0...CGFloat.pi * 2)
            debris.zRotation = angle
            let dx = cos(angle) * CGFloat.random(in: 100...200)
            let dy = sin(angle) * CGFloat.random(in: 100...200)
            
            debris.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5)
                ]),
                .removeFromParent()
            ]))
        }
        
        // ── DOUBLE SHOCKWAVE RING ──
        for i in 0..<2 {
            let ring = SKShapeNode(circleOfRadius: 8)
            ring.strokeColor = i == 0 ? .red : .cyan
            ring.fillColor = .clear
            ring.glowWidth = i == 0 ? 6 : 4
            ring.alpha = 0.7
            ring.position = position
            ring.zPosition = 12
            addChild(ring)
            
            let delay = Double(i) * 0.08
            ring.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.group([
                    SKAction.scale(to: 6.0, duration: 0.35),
                    SKAction.fadeOut(withDuration: 0.35)
                ]),
                .removeFromParent()
            ]))
        }
    }
    
    // MARK: - Game State
    
    func startGame() {
        isGameRunning = true
        score = 0
        distanceTraveled = 0
        survivalTime = 0
        enemiesDestroyed = 0
        shieldHP = maxShieldHP  // Equipment-derived shield HP
        currentLevel = 1
        nextLevelThreshold = distancePerLevel
        isHyperJumping = false
        scrollSpeed = baseScrollSpeed  // Equipment-derived base speed
        obstacleSpawnRate = 2.2
        lastUpdateTime = 0
        comboCount = 0
        comboMultiplier = 1
        isDoubleLaser = false
        isSlowMo = false
        lastPowerUpSpawnTime = 0
        sessionTelemetry.removeAll(keepingCapacity: true)
        lastTelemetryTime = 0
    }
    
    // MARK: - Hyperjump (Level Transition)
    
    private func triggerHyperJump() {
        isHyperJumping = true
        
        // Clear all obstacles
        enumerateChildNodes(withName: "obstacle") { node, _ in
            node.removeFromParent()
        }
        
        // Star stretch effect — elongated stars rushing past
        for _ in 0..<30 {
            let starY = CGFloat.random(in: -halfH...halfH)
            let star = SKShapeNode(rectOf: CGSize(width: 2, height: 1), cornerRadius: 0.5)
            star.fillColor = .white
            star.strokeColor = .clear
            star.alpha = CGFloat.random(in: 0.5...1.0)
            star.blendMode = .add
            star.position = CGPoint(x: CGFloat.random(in: -halfW...halfW), y: starY)
            star.zPosition = 20
            addChild(star)
            
            // Stretch into long lines
            let stretch = SKAction.scaleX(to: 80, duration: 0.3)
            let moveLeft = SKAction.moveBy(x: -size.width * 2, y: 0, duration: 0.5)
            star.run(SKAction.sequence([
                stretch,
                moveLeft,
                .removeFromParent()
            ]))
        }
        
        // Screen flash
        let flash = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: size.height * 2))
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.alpha = 0
        flash.zPosition = 50
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.6, duration: 0.3),
            SKAction.fadeAlpha(to: 0.0, duration: 0.5),
            .removeFromParent()
        ]))
        
        // Level up after animation
        let levelUp = SKAction.sequence([
            SKAction.wait(forDuration: 0.8),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.currentLevel += 1
                self.nextLevelThreshold += self.distancePerLevel
                
                // Increase base difficulty
                self.scrollSpeed += 30
                self.obstacleSpawnRate = max(self.obstacleSpawnRate - 0.15, 0.6)
                
                // Subtle background color shift per level
                let blueShift = min(CGFloat(self.currentLevel) * 0.01, 0.08)
                self.backgroundColor = UIColor(red: 0.02, green: 0.02 + blueShift, blue: 0.07 + blueShift, alpha: 1.0)
                
                // Level banner
                let label = SKLabelNode(text: "⚡ LEVEL \(self.currentLevel) ⚡")
                label.fontName = "Menlo-Bold"
                label.fontSize = 22
                label.fontColor = UIColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0)
                label.position = CGPoint(x: 0, y: self.halfH * 0.2)
                label.zPosition = 55
                label.alpha = 0
                label.setScale(0.5)
                self.addChild(label)
                
                label.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.fadeIn(withDuration: 0.2),
                        SKAction.scale(to: 1.2, duration: 0.2)
                    ]),
                    SKAction.scale(to: 1.0, duration: 0.1),
                    SKAction.wait(forDuration: 1.5),
                    SKAction.fadeOut(withDuration: 0.4),
                    .removeFromParent()
                ]))
                
                self.isHyperJumping = false
                
                NotificationCenter.default.post(name: .levelUp, object: nil, userInfo: ["level": self.currentLevel])
            }
        ])
        run(levelUp)
    }
    
    func gameOver() {
        isGameRunning = false
        
        // Slow-motion effect on remaining obstacles
        enumerateChildNodes(withName: "obstacle") { node, _ in
            node.speed = 0.3
        }
        
        // Screen shake
        let shake = SKAction.sequence([
            SKAction.moveBy(x: 10, y: 0, duration: 0.04),
            SKAction.moveBy(x: -20, y: 0, duration: 0.04),
            SKAction.moveBy(x: 10, y: 0, duration: 0.04)
        ])
        self.run(SKAction.repeat(shake, count: 4))
        
        // Flash screen red
        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = .red
        overlay.strokeColor = .clear
        overlay.alpha = 0.3
        overlay.zPosition = 100
        addChild(overlay)
        overlay.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.4), .removeFromParent()]))
        
        // "SYSTEM FAILURE" glitch text
        let failLabel = SKLabelNode(text: "SYSTEM FAILURE")
        failLabel.fontName = "Menlo-Bold"
        failLabel.fontSize = 26
        failLabel.fontColor = .red
        failLabel.position = .zero
        failLabel.zPosition = 110
        failLabel.alpha = 0
        addChild(failLabel)
        failLabel.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.1),
            SKAction.fadeAlpha(to: 0.3, duration: 0.05),
            SKAction.fadeAlpha(to: 1.0, duration: 0.05),
            SKAction.moveBy(x: 5, y: 0, duration: 0.03),
            SKAction.moveBy(x: -10, y: 0, duration: 0.03),
            SKAction.moveBy(x: 5, y: 0, duration: 0.03),
            SKAction.wait(forDuration: 0.6),
            SKAction.fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
        
        NotificationCenter.default.post(name: .gameEnded, object: nil, userInfo: [
            "score": score,
            "enemiesDestroyed": enemiesDestroyed,
            "survivalTime": survivalTime,
            "telemetry": sessionTelemetry
        ])
    }
    
    private func postShieldUpdate() {
        NotificationCenter.default.post(name: .shieldUpdated, object: nil, userInfo: ["shieldHP": shieldHP, "maxShieldHP": maxShieldHP])
        
        if shieldHP <= 0 {
            shieldRing?.removeFromParent()
        } else {
            // Dynamic alpha based on shield percentage
            let shieldFraction = CGFloat(shieldHP) / CGFloat(maxShieldHP)
            shieldRing?.alpha = 0.10 + shieldFraction * 0.25
            
            if shieldHP == 1 {
                let pulse = SKAction.sequence([
                    SKAction.run { self.shieldRing?.strokeColor = .red },
                    SKAction.wait(forDuration: 0.25),
                    SKAction.run { self.shieldRing?.strokeColor = UIColor(red: 0, green: 0.94, blue: 1, alpha: 0.15) },
                    SKAction.wait(forDuration: 0.25)
                ])
                shieldRing?.run(SKAction.repeatForever(pulse), withKey: "shieldPulse")
            }
        }
    }
    
    // MARK: - Physics Contact
    
    func didBegin(_ contact: SKPhysicsContact) {
        let maskA = contact.bodyA.categoryBitMask
        let maskB = contact.bodyB.categoryBitMask
        let collision = maskA | maskB
        
        // Laser hits obstacle
        if collision == Cat.laser | Cat.obstacle {
            let obs = (maskA == Cat.obstacle) ? contact.bodyA.node : contact.bodyB.node
            let las = (maskA == Cat.laser) ? contact.bodyA.node : contact.bodyB.node
            
            las?.removeFromParent()
            
            // Multi-hit enemies (ShieldDrone, BossNode)
            if let maxHP = obs?.userData?["maxHP"] as? Int {
                var hitCount = (obs?.userData?["hitCount"] as? Int) ?? 0
                hitCount += 1
                obs?.userData?["hitCount"] = hitCount
                
                if hitCount < maxHP {
                    // Flash but don't destroy
                    let flash = SKAction.sequence([
                        SKAction.fadeAlpha(to: 0.2, duration: 0.05),
                        SKAction.fadeAlpha(to: 1.0, duration: 0.1)
                    ])
                    obs?.run(flash)
                    return
                }
            }
            
            if let pos = obs?.position { spawnDestroyEffect(at: pos) }
            obs?.removeFromParent()
            
            // Combo system
            comboCount += 1
            if comboCount >= 10 { comboMultiplier = 5 }
            else if comboCount >= 5 { comboMultiplier = 3 }
            else if comboCount >= 3 { comboMultiplier = 2 }
            else { comboMultiplier = 1 }
            
            enemiesDestroyed += 1
            score += 10 * comboMultiplier
            
            NotificationCenter.default.post(name: .enemyDestroyed, object: nil, userInfo: ["total": enemiesDestroyed])
            NotificationCenter.default.post(name: .comboUpdated, object: nil, userInfo: ["combo": comboCount, "multiplier": comboMultiplier])
        }
        
        // Player hits obstacle
        if collision == Cat.player | Cat.obstacle {
            if isGhostMode { return }
            
            let obs = (maskA == Cat.obstacle) ? contact.bodyA.node : contact.bodyB.node
            
            if let pos = obs?.position { spawnDestroyEffect(at: pos) }
            obs?.removeFromParent()
            
            // Reset combo on damage
            comboCount = 0
            comboMultiplier = 1
            NotificationCenter.default.post(name: .comboUpdated, object: nil, userInfo: ["combo": 0, "multiplier": 1])
            
            let normalizedY = (Double(player.position.y) + Double(halfH)) / Double(size.height)
            sessionTelemetry.append(SessionTelemetry(timeOffset: survivalTime, playerY: normalizedY, event: .hit))
            
            shieldHP -= 1
            if shieldHP <= 0 {
                gameOver()
            } else {
                let flash = SKAction.sequence([
                    SKAction.run { [weak self] in
                        self?.player.children.compactMap { $0 as? SKShapeNode }
                            .forEach { $0.alpha = 0.3 }
                    },
                    SKAction.wait(forDuration: 0.12),
                    SKAction.run { [weak self] in
                        self?.player.children.compactMap { $0 as? SKShapeNode }
                            .forEach { $0.alpha = 1.0 }
                    }
                ])
                player.run(flash)
            }
        }
        
        // Player collects power-up
        if collision == Cat.player | Cat.powerup {
            let pu = (maskA == Cat.powerup) ? contact.bodyA.node : contact.bodyB.node
            if let typeStr = pu?.userData?["type"] as? String {
                collectPowerUp(type: typeStr, at: pu?.position ?? .zero)
            }
            pu?.removeFromParent()
        }
    }
    
    // MARK: - Power-Up System
    
    private func spawnPowerUp() {
        let types = ["shield", "slowmo", "doublelaser"]
        let type = types.randomElement() ?? "shield"
        
        let nodeSize: CGFloat = 28
        let node = SKShapeNode(circleOfRadius: nodeSize / 2)
        node.name = "powerup"
        node.zPosition = 6
        node.userData = NSMutableDictionary(dictionary: ["type": type])
        
        switch type {
        case "shield":
            node.fillColor = UIColor.green.withAlphaComponent(0.2)
            node.strokeColor = .green
            node.glowWidth = 5
        case "slowmo":
            node.fillColor = UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.2)
            node.strokeColor = UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
            node.glowWidth = 5
        case "doublelaser":
            node.fillColor = UIColor.purple.withAlphaComponent(0.2)
            node.strokeColor = .purple
            node.glowWidth = 5
        default: break
        }
        
        let icon: String
        switch type {
        case "shield": icon = "🟢"
        case "slowmo": icon = "🟥"
        case "doublelaser": icon = "🟣"
        default: icon = "⭐"
        }
        let label = SKLabelNode(text: icon)
        label.fontSize = 14
        label.verticalAlignmentMode = .center
        node.addChild(label)
        
        node.physicsBody = SKPhysicsBody(circleOfRadius: nodeSize / 2)
        node.physicsBody?.categoryBitMask = Cat.powerup
        node.physicsBody?.contactTestBitMask = Cat.player
        node.physicsBody?.collisionBitMask = Cat.none
        node.physicsBody?.isDynamic = false
        
        let maxY = halfH - 70
        let minY = -halfH + 70
        node.position = CGPoint(x: halfW + nodeSize, y: CGFloat.random(in: minY...maxY))
        
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ])
        node.run(SKAction.repeatForever(pulse))
        
        addChild(node)
    }
    
    private func collectPowerUp(type: String, at position: CGPoint) {
        // Collection VFX flash
        let flash = SKShapeNode(circleOfRadius: 20)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.alpha = 0.8
        flash.blendMode = .add
        flash.position = position
        flash.zPosition = 20
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 3.0, duration: 0.2), SKAction.fadeOut(withDuration: 0.2)]),
            .removeFromParent()
        ]))
        
        
        let normalizedY = (Double(player.position.y) + Double(halfH)) / Double(size.height)
        sessionTelemetry.append(SessionTelemetry(timeOffset: survivalTime, playerY: normalizedY, event: .powerup))
        
        switch type {
        case "shield":
            shieldHP = min(shieldHP + 1, maxShieldHP)  // Respects equipment max
            NotificationCenter.default.post(name: .powerUpCollected, object: nil, userInfo: ["type": "SHIELD +1"])
            
        case "slowmo":
            isSlowMo = true
            let prevSpeed = scrollSpeed
            scrollSpeed *= 0.5
            NotificationCenter.default.post(name: .powerUpCollected, object: nil, userInfo: ["type": "SLOW-MO"])
            run(SKAction.sequence([
                SKAction.wait(forDuration: powerUpDuration),  // Equipment-boosted duration
                SKAction.run { [weak self] in
                    self?.isSlowMo = false
                    self?.scrollSpeed = prevSpeed
                    NotificationCenter.default.post(name: .powerUpExpired, object: nil)
                }
            ]))
            
        case "doublelaser":
            isDoubleLaser = true
            NotificationCenter.default.post(name: .powerUpCollected, object: nil, userInfo: ["type": "DOUBLE LASER"])
            run(SKAction.sequence([
                SKAction.wait(forDuration: powerUpDuration),  // Equipment-boosted duration
                SKAction.run { [weak self] in
                    self?.isDoubleLaser = false
                    NotificationCenter.default.post(name: .powerUpExpired, object: nil)
                }
            ]))
            
        default: break
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let gameEnded = Notification.Name("GameEnded")
    static let gameScoreUpdated = Notification.Name("GameScoreUpdated")
    static let shieldUpdated = Notification.Name("ShieldUpdated")
    static let enemyDestroyed = Notification.Name("EnemyDestroyed")
    static let ghostModeActivated = Notification.Name("GhostModeActivated")
    static let ghostModeEnded = Notification.Name("GhostModeEnded")
    static let levelUp = Notification.Name("LevelUp")
    static let comboUpdated = Notification.Name("ComboUpdated")
    static let powerUpCollected = Notification.Name("PowerUpCollected")
    static let powerUpExpired = Notification.Name("PowerUpExpired")
    static let distanceFlew = Notification.Name("DistanceFlew")
    static let laserFired = Notification.Name("LaserFired")
}

// MARK: - Texture Extensions
extension SKTexture {
    convenience init(systemName: String) {
        let image = UIImage(systemName: systemName)?.withTintColor(.white, renderingMode: .alwaysOriginal)
        if let data = image?.pngData(), let newImage = UIImage(data: data) {
            self.init(image: newImage)
        } else {
            self.init()
        }
    }
}
