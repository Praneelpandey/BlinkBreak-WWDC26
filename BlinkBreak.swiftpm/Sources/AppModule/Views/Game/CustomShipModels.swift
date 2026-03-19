import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Ship Type Enum
// ═══════════════════════════════════════════════════════

/// All available ship types with display metadata
enum ShipType: String, CaseIterable, Identifiable {
    case dart
    case rocket
    case fighter
    case ufo
    case satellite
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .dart:      return "DART"
        case .rocket:    return "VANGUARD"
        case .fighter:   return "RAPTOR"
        case .ufo:       return "PHANTOM"
        case .satellite: return "ORBITAL"
        }
    }
    
    var tier: String {
        switch self {
        case .dart:      return "STANDARD"
        case .rocket:    return "ADVANCED"
        case .fighter:   return "ELITE"
        case .ufo:       return "PROTOTYPE"
        case .satellite: return "LEGENDARY"
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Thruster Effect
// ═══════════════════════════════════════════════════════

/// A reusable animated thruster flame that pulses and adapts to the ship's color.
struct ThrusterFlameView: View {
    var color: Color
    var size: CGFloat
    var isPoweredOn: Bool = true
    
    @State private var isPulsing = false
    
    // Map ship colors to distinct flame colors
    private var flameColor: Color {
        // Cyan -> Blue
        if color == Color(red: 0.0, green: 0.94, blue: 1.0) { return .blue }
        // Gold -> Orange
        if color == .yellow { return .orange }
        // Magenta -> Purple
        if color == .pink || color == .red { return .purple }
        
        return color
    }
    
    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        flameColor,
                        flameColor.opacity(0.6),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size, height: size * 3)
            .blur(radius: isPulsing ? 3 : 1)
            .opacity(isPoweredOn ? (isPulsing ? 1.0 : 0.6) : 0.0)
            .shadow(color: flameColor, radius: 8)
            .scaleEffect(y: isPulsing ? 1.2 : 0.8, anchor: .top)
            .animation(
                isPoweredOn ? .easeInOut(duration: 0.4).repeatForever(autoreverses: true) : .default,
                value: isPulsing
            )
            .onAppear {
                if isPoweredOn {
                    isPulsing = true
                }
            }
            .onChange(of: isPoweredOn) { newValue in
                isPulsing = newValue
            }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Universal Render Wrapper
// ═══════════════════════════════════════════════════════

/// Renders the correct vector ship for a given ShipType.
/// Applies tint color and optional neon glow.
struct ShipRenderView: View {
    let shipType: ShipType
    var color: Color = .white
    var size: CGFloat = 100
    
    var body: some View {
        Group {
            switch shipType {
            case .dart:      DartModelView(color: color)
            case .rocket:    RocketModelView(color: color)
            case .fighter:   FighterJetModelView(color: color)
            case .ufo:       UFOModelView(color: color)
            case .satellite: SatelliteModelView(color: color)
            }
        }
        .frame(width: size, height: size)
        .foregroundColor(color)
        .shadow(color: color.opacity(0.5), radius: 5)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Live Modular Ship Composite
// ═══════════════════════════════════════════════════════

/// A 3D/2D layered visualization of the ship reading directly from UnlockManager's equipped parts or Live Previews.
struct LiveShipPreviewComposite: View {
    var bounce: Bool = false
    var previewOverrides: [PartCategory: String] = [:]
    var previewHull: ShipType? = nil
    
    @StateObject private var unlocks = UnlockManager.shared
    @AppStorage("equippedHull") private var equippedHullRaw: String = ShipType.dart.rawValue
    
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    private let lockedRed = Color(red: 1.0, green: 0.2, blue: 0.2)
    
    // MARK: - Override Resolvers
    
    private func isPartActive(_ partID: String, category: PartCategory) -> Bool {
        if let previewID = previewOverrides[category] {
            return previewID == partID
        }
        return unlocks.isEquipped(partID: partID)
    }
    
    private func isPartPreviewLocked(_ partID: String, category: PartCategory) -> Bool {
        if previewOverrides[category] == partID {
            return !unlocks.isUnlocked(partID: partID)
        }
        return false
    }
    
    // MARK: - Render Loop
    
    var body: some View {
        ZStack {
            // LAYER 1: BACK (Trails & Shields)
            if isPartActive("shd_aegis", category: .shield) {
                let locked = isPartPreviewLocked("shd_aegis", category: .shield)
                let renderColor = locked ? lockedRed : neonCyan
                
                Circle()
                    .stroke(renderColor.opacity(locked ? 0.3 : 0.6), lineWidth: 4)
                    .frame(width: 220, height: 220)
                    .shadow(color: renderColor, radius: 20)
                    .scaleEffect(bounce ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: bounce)
                    .overlay(
                        Circle()
                            .stroke(renderColor.opacity(locked ? 0.5 : 0.0), style: StrokeStyle(lineWidth: 1, dash: [4, 8]))
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(bounce ? 180 : 0))
                            .animation(.linear(duration: 10).repeatForever(autoreverses: false), value: bounce)
                    )
            }
            
            // LAYER 2: CHASSIS & WINGS
            ZStack {
                if isPartActive("wng_holo", category: .wings) {
                    let locked = isPartPreviewLocked("wng_holo", category: .wings)
                    let renderColor = locked ? lockedRed : neonCyan
                    
                    // Holographic Wings Underlay
                    Path { p in
                        p.move(to: CGPoint(x: 100, y: 30))
                        p.addLine(to: CGPoint(x: 10, y: 150))
                        p.addLine(to: CGPoint(x: 190, y: 150))
                        p.closeSubpath()
                    }
                    .fill(renderColor.opacity(locked ? 0.1 : 0.2))
                    .frame(width: 200, height: 200)
                    .shadow(color: renderColor, radius: 10)
                }
                
                // Base Ship
                let ship = previewHull ?? ShipType(rawValue: equippedHullRaw) ?? .dart
                let lockedHull = previewHull != nil && !UnlockManager.shared.unlockedParts.contains(previewHull!.rawValue) && previewHull != .dart
                let hullRenderColor = lockedHull ? lockedRed : Color.white
                
                ShipRenderView(shipType: ship, color: hullRenderColor, size: 140)
                    .shadow(color: bounce ? hullRenderColor : .clear, radius: bounce ? 20 : 0)
                    .scaleEffect(bounce ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: bounce)
            }
            
            // LAYER 3: FOREGROUND EFFECTS (Core & Engines)
            if isPartActive("cor_quantum", category: .core) {
                let locked = isPartPreviewLocked("cor_quantum", category: .core)
                let renderColor = locked ? lockedRed : Color.white
                
                Circle()
                    .fill(renderColor.opacity(locked ? 0.6 : 1.0))
                    .frame(width: 16, height: 16)
                    .shadow(color: renderColor, radius: 10)
                    .scaleEffect(bounce ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: bounce)
                    .offset(y: 10) // Centered over fuselage
            }
            
            // Engines usually mount below the render bounds
            VStack {
                Spacer()
                if isPartActive("eng_plasma", category: .engine) {
                    let locked = isPartPreviewLocked("eng_plasma", category: .engine)
                    let renderColor = locked ? lockedRed : Color.purple
                    
                    HStack(spacing: 30) {
                        ThrusterFlameView(color: renderColor, size: 20)
                        ThrusterFlameView(color: renderColor, size: 20)
                    }
                    .offset(y: 60)
                } else {
                    ThrusterFlameView(color: neonCyan, size: 20)
                        .offset(y: 60)
                }
            }
            
            // Top Right Indicator for Locked Previews
            let hasLockedPrevewOverride = previewOverrides.contains(where: { (cat, id) in !unlocks.isUnlocked(partID: id) })
            let isHullPreviewLocked = previewHull != nil && !UnlockManager.shared.unlockedParts.contains(previewHull!.rawValue) && previewHull != .dart
            
            if hasLockedPrevewOverride || isHullPreviewLocked {
                VStack {
                    HStack {
                        Spacer()
                        Text("PREVIEW MODE — LOCKED")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(lockedRed)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(lockedRed.opacity(0.15))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(lockedRed.opacity(0.5), lineWidth: 1))
                            .shadow(color: lockedRed.opacity(0.5), radius: 4)
                            .opacity(bounce ? 1.0 : 0.6)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: bounce)
                            .offset(y: -20)
                    }
                    Spacer()
                }
                .padding(10)
            }
        }
        .frame(width: 250, height: 250)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - DART (Default Paper-Plane Style)
// ═══════════════════════════════════════════════════════

/// A sleek paper-dart / arrowhead ship — the starter vessel.
struct DartModelView: View {
    var color: Color = .white
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Main fuselage — pointed dart shape
                Path { p in
                    p.move(to: CGPoint(x: w * 0.5, y: h * 0.08))   // Nose
                    p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.85)) // Bottom-left
                    p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.68))  // Center notch
                    p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.85)) // Bottom-right
                    p.closeSubpath()
                }
                .fill(Color.white)
                
                // Engine core — small glow near tail
                Ellipse()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: w * 0.12, height: w * 0.06)
                    .position(x: w * 0.5, y: h * 0.72)
                
                // Single trailing flame
                ThrusterFlameView(color: color, size: w * 0.08)
                    .position(x: w * 0.5, y: h * 0.75)
                    .zIndex(-1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - ROCKET (Vertical Capsule + Fins)
// ═══════════════════════════════════════════════════════

/// Classic vertical rocket with triangular fins and viewport window.
struct RocketModelView: View {
    var color: Color = .white
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Main fuselage — vertical capsule
                Capsule()
                    .fill(Color.white)
                    .frame(width: w * 0.28, height: h * 0.65)
                    .position(x: w * 0.5, y: h * 0.42)
                
                // Nose cone
                Path { p in
                    p.move(to: CGPoint(x: w * 0.5, y: h * 0.05))   // Tip
                    p.addLine(to: CGPoint(x: w * 0.36, y: h * 0.22))
                    p.addLine(to: CGPoint(x: w * 0.64, y: h * 0.22))
                    p.closeSubpath()
                }
                .fill(Color.white)
                
                // Left fin
                Path { p in
                    p.move(to: CGPoint(x: w * 0.36, y: h * 0.62))
                    p.addLine(to: CGPoint(x: w * 0.14, y: h * 0.88))
                    p.addLine(to: CGPoint(x: w * 0.36, y: h * 0.78))
                    p.closeSubpath()
                }
                .fill(Color.white.opacity(0.8))
                
                // Right fin
                Path { p in
                    p.move(to: CGPoint(x: w * 0.64, y: h * 0.62))
                    p.addLine(to: CGPoint(x: w * 0.86, y: h * 0.88))
                    p.addLine(to: CGPoint(x: w * 0.64, y: h * 0.78))
                    p.closeSubpath()
                }
                .fill(Color.white.opacity(0.8))
                
                // Viewport window
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: w * 0.12, height: w * 0.12)
                    .position(x: w * 0.5, y: h * 0.32)
                
                // Engine exhaust glow
                Ellipse()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: w * 0.16, height: w * 0.08)
                    .position(x: w * 0.5, y: h * 0.77)
                
                // Massive central rocket thruster
                ThrusterFlameView(color: color, size: w * 0.18)
                    .position(x: w * 0.5, y: h * 0.77)
                    .zIndex(-1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - FIGHTER JET (Delta Wing)
// ═══════════════════════════════════════════════════════

/// Aggressive delta-wing fighter with sharp geometry.
struct FighterJetModelView: View {
    var color: Color = .white
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Main delta body
                Path { p in
                    p.move(to: CGPoint(x: w * 0.5, y: h * 0.06))   // Sharp nose
                    p.addLine(to: CGPoint(x: w * 0.08, y: h * 0.72)) // Left wing tip
                    p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.65)) // Left wing inner
                    p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.82)) // Left tail
                    p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.72))  // Center tail notch
                    p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.82)) // Right tail
                    p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.65)) // Right wing inner
                    p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.72)) // Right wing tip
                    p.closeSubpath()
                }
                .fill(Color.white)
                
                // Cockpit canopy — darker inset
                Path { p in
                    p.move(to: CGPoint(x: w * 0.5, y: h * 0.18))
                    p.addLine(to: CGPoint(x: w * 0.43, y: h * 0.38))
                    p.addLine(to: CGPoint(x: w * 0.57, y: h * 0.38))
                    p.closeSubpath()
                }
                .fill(Color.black.opacity(0.3))
                
                // Engine nacelle — center stripe
                Capsule()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: w * 0.06, height: h * 0.20)
                    .position(x: w * 0.5, y: h * 0.55)
                
                // Left Wing Thruster
                ThrusterFlameView(color: color, size: w * 0.08)
                    .position(x: w * 0.38, y: h * 0.82)
                    .zIndex(-1)
                
                // Right Wing Thruster
                ThrusterFlameView(color: color, size: w * 0.08)
                    .position(x: w * 0.62, y: h * 0.82)
                    .zIndex(-1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - UFO (Saucer + Dome + Lights)
// ═══════════════════════════════════════════════════════

/// Classic flying saucer with translucent dome and underside lights.
struct UFOModelView: View {
    var color: Color = .white
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Main saucer disc
                Ellipse()
                    .fill(Color.white)
                    .frame(width: w * 0.88, height: h * 0.28)
                    .position(x: w * 0.5, y: h * 0.52)
                
                // Saucer rim ring
                Ellipse()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    .frame(width: w * 0.92, height: h * 0.32)
                    .position(x: w * 0.5, y: h * 0.52)
                
                // Top dome — translucent bubble
                Ellipse()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: w * 0.34, height: h * 0.26)
                    .position(x: w * 0.5, y: h * 0.38)
                
                // Dome highlight
                Ellipse()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: w * 0.18, height: h * 0.10)
                    .position(x: w * 0.46, y: h * 0.33)
                
                // Underside lights — 3 glowing circles
                HStack(spacing: w * 0.10) {
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: w * 0.07, height: w * 0.07)
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: w * 0.09, height: w * 0.09)
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: w * 0.07, height: w * 0.07)
                }
                .position(x: w * 0.5, y: h * 0.64)
                
                // Underside Thrusters
                ThrusterFlameView(color: color, size: w * 0.06)
                    .position(x: w * 0.33, y: h * 0.65)
                    .zIndex(-1)
                ThrusterFlameView(color: color, size: w * 0.08)
                    .position(x: w * 0.5, y: h * 0.67)
                    .zIndex(-1)
                ThrusterFlameView(color: color, size: w * 0.06)
                    .position(x: w * 0.67, y: h * 0.65)
                    .zIndex(-1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - SATELLITE (Body + Solar Panels)
// ═══════════════════════════════════════════════════════

/// Orbital satellite with central body and twin solar panel arrays.
struct SatelliteModelView: View {
    var color: Color = .white
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Central body — rounded cube
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white)
                    .frame(width: w * 0.20, height: h * 0.26)
                    .position(x: w * 0.5, y: h * 0.48)
                
                // Left solar panel arm
                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: w * 0.22, height: h * 0.03)
                    .position(x: w * 0.28, y: h * 0.48)
                
                // Left solar panel
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.75))
                    
                    // Panel grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.black.opacity(0.15))
                                .frame(height: 1)
                            Spacer()
                        }
                    }
                    .padding(1)
                    
                    HStack(spacing: 0) {
                        ForEach(0..<2, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.black.opacity(0.15))
                                .frame(width: 1)
                            Spacer()
                        }
                    }
                    .padding(1)
                }
                .frame(width: w * 0.24, height: h * 0.32)
                .position(x: w * 0.14, y: h * 0.48)
                
                // Right solar panel arm
                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: w * 0.22, height: h * 0.03)
                    .position(x: w * 0.72, y: h * 0.48)
                
                // Right solar panel
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.75))
                    
                    VStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.black.opacity(0.15))
                                .frame(height: 1)
                            Spacer()
                        }
                    }
                    .padding(1)
                    
                    HStack(spacing: 0) {
                        ForEach(0..<2, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.black.opacity(0.15))
                                .frame(width: 1)
                            Spacer()
                        }
                    }
                    .padding(1)
                }
                .frame(width: w * 0.24, height: h * 0.32)
                .position(x: w * 0.86, y: h * 0.48)
                
                // Antenna dish — small circle on top
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: w * 0.08, height: w * 0.08)
                    .position(x: w * 0.5, y: h * 0.30)
                
                // Antenna arm
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: w * 0.02, height: h * 0.08)
                    .position(x: w * 0.5, y: h * 0.34)
                
                // Subtle Flank Jets
                ThrusterFlameView(color: color, size: w * 0.04)
                    .position(x: w * 0.42, y: h * 0.58)
                    .zIndex(-1)
                ThrusterFlameView(color: color, size: w * 0.04)
                    .position(x: w * 0.58, y: h * 0.58)
                    .zIndex(-1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 20) {
            ForEach(ShipType.allCases) { type in
                ShipRenderView(shipType: type, color: Color(red: 0.0, green: 0.94, blue: 1.0), size: 80)
            }
        }
    }
}
