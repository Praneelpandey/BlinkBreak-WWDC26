import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Composite Ship View (Universal SwiftUI Renderer)
// ═══════════════════════════════════════════════════════

/// A reusable SwiftUI view that renders the player's equipped ship configuration.
/// Reads directly from UnlockManager for equipped parts. Suitable for HUD overlays,
/// loading screens, and any non-SpriteKit context.
///
/// For side-scrolling orientation (nose pointing right), set `sidescrollOrientation = true`.
struct CompositeShipView: View {
    var hull: ShipType = .dart
    var sidescrollOrientation: Bool = false
    var size: CGFloat = 80
    
    @StateObject private var unlocks = UnlockManager.shared
    
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    // MARK: - Computed Part State
    
    private var hasPlasmaEngine: Bool {
        unlocks.equippedParts[.engine] == "eng_plasma"
    }
    
    private var hasHoloWings: Bool {
        unlocks.equippedParts[.wings] == "wng_holo"
    }
    
    private var hasStardustTrail: Bool {
        unlocks.equippedParts[.trail] == "trl_stardust"
    }
    
    private var hasAegisShield: Bool {
        unlocks.equippedParts[.shield] == "shd_aegis"
    }
    
    private var hasQuantumCore: Bool {
        unlocks.equippedParts[.core] == "cor_quantum"
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // LAYER 1: Shield Aura (back)
            if hasAegisShield {
                Circle()
                    .stroke(neonCyan.opacity(0.5), lineWidth: 2)
                    .frame(width: size * 1.4, height: size * 1.4)
                    .shadow(color: neonCyan, radius: 10)
            }
            
            // LAYER 2: Holo Wings (behind hull)
            if hasHoloWings {
                Path { p in
                    let w = size
                    let h = size
                    p.move(to: CGPoint(x: w * 0.5, y: h * 0.15))
                    p.addLine(to: CGPoint(x: w * 0.05, y: h * 0.75))
                    p.addLine(to: CGPoint(x: w * 0.95, y: h * 0.75))
                    p.closeSubpath()
                }
                .fill(neonCyan.opacity(0.15))
                .frame(width: size, height: size)
                .shadow(color: neonCyan, radius: 8)
            }
            
            // LAYER 3: Hull
            ShipRenderView(shipType: hull, color: .white, size: size * 0.85)
                .shadow(color: neonCyan.opacity(0.4), radius: 8)
            
            // LAYER 4: Quantum Core glow
            if hasQuantumCore {
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.1, height: size * 0.1)
                    .shadow(color: .white, radius: 6)
                    .offset(y: size * 0.05)
            }
            
            // LAYER 5: Engine Flames
            VStack {
                Spacer()
                if hasPlasmaEngine {
                    HStack(spacing: size * 0.18) {
                        ThrusterFlameView(color: .purple, size: size * 0.12)
                        ThrusterFlameView(color: .purple, size: size * 0.12)
                    }
                    .offset(y: size * 0.35)
                } else {
                    ThrusterFlameView(color: neonCyan, size: size * 0.12)
                        .offset(y: size * 0.35)
                }
            }
            
            // LAYER 6: Stardust Trail
            if hasStardustTrail {
                VStack {
                    Spacer()
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(neonCyan.opacity(Double(5 - i) * 0.12))
                            .frame(width: CGFloat(5 - i) * 2, height: CGFloat(5 - i) * 2)
                    }
                }
                .offset(y: size * 0.5)
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(sidescrollOrientation ? .degrees(-90) : .zero)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 30) {
            CompositeShipView(hull: .dart, size: 80)
            CompositeShipView(hull: .rocket, sidescrollOrientation: true, size: 80)
            CompositeShipView(hull: .fighter, size: 80)
        }
    }
}
