import SwiftUI
import AVFoundation

/// The main Home / Hangar screen where the user prepares for their mission.
/// Features a cyberpunk/sci-fi cockpit aesthetic with animated background and hero elements.
struct HangarView: View {
    // MARK: - Bindings
    @Binding var showHangar: Bool
    @Binding var showCalibration: Bool
    
    // MARK: - Motion
    @StateObject private var motion = MotionManager()
    @ObservedObject private var progressionManager = ProgressionManager.shared
    
    // MARK: - State
    @State private var animateBackground = false
    @State private var heroFloating = false
    @State private var showPermissionAlert = false
    @State private var launchButtonPulse = false
    @State private var isSystemReady = false
    @State private var showSuccessState = false
    // MARK: - Gamification Persistence
    @AppStorage("userStreak") private var userStreak: Int = 0
    @AppStorage("lastFocusScore") private var lastFocusScore: Int = 0
    @AppStorage("lastReactionTime") private var lastReactionTime: Double = 0.0
    @AppStorage("hasPlayedBefore") private var hasPlayedBefore: Bool = false
    @AppStorage("pilotNickname") private var pilotNickname: String = ""
    
    @AppStorage("playerLevel") private var playerLevel: Int = 1
    @AppStorage("playerXP") private var playerXP: Double = 0.0
    private let xpRequiredForNextLevel: Double = 500.0
    
    @State private var showPilotDossier: Bool = false
    @State private var showDailyMissions: Bool = false
    @State private var showMedBay: Bool = false
    @State private var showSettings: Bool = false
    @State private var showGalaxy: Bool = false
    @State private var showShipyard: Bool = false
    @State private var showWeeklyReport: Bool = false
    @State private var showAchievements: Bool = false
    
    // MARK: - Ship Customization
    @AppStorage("selectedShipType") private var selectedShipType: String = ShipType.dart.rawValue
    
    /// Resolves the persisted rawValue to a ShipType (falls back to .dart)
    private var currentShipType: ShipType {
        ShipType(rawValue: selectedShipType) ?? .dart
    }
    
    // MARK: - Eye Health Tracking
    @AppStorage("totalSessionsToday") private var sessionsToday: Int = 1
    private let dailySessionGoal: Int = 3
    @State private var ringAnimating: Bool = false
    
    @State private var isLaunching = false
    @State private var isHovering = false
    
    // MARK: - Skin Selector State
    @State private var previewColor: Color = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    // MARK: - System Log State
    @State private var currentLogIndex: Int = 0
    @State private var logTimer: Timer?
    private let systemLogMessages = [
        "Checking Biometrics...",
        "Calibrating ARKit...",
        "System Optimized",
        "Ready for Launch"
    ]
    
    // MARK: - Constants
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0) // #00F0FF
    private let deepSpaceBlack = Color(red: 0.05, green: 0.05, blue: 0.1)
    private let electricBlue = Color(red: 0.0, green: 0.4, blue: 1.0)
    private let warningOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    
    // MARK: - Computed Properties
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "GOOD MORNING"
        case 12..<17: return "GOOD AFTERNOON"
        case 17..<22: return "GOOD EVENING"
        default: return "LATE NIGHT OPS"
        }
    }
    
    var body: some View {
        ZStack {
            // 1. Content Layer
            SafeAreaView {
            VStack(spacing: 0) {
                
                // ═══════════════════════════════════════════
                // ZONE 1 — TOP HEADER
                // ═══════════════════════════════════════════
                HStack(alignment: .top) {
                    Button(action: { showPilotDossier = true }) {
                        PilotProfileCard(level: playerLevel, xp: playerXP, requiredXP: xpRequiredForNextLevel)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    
                    Spacer()
                    
                    // Utility & Health Actions
                    HStack(spacing: 12) {
                        Button(action: { showAchievements = true }) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.yellow.opacity(0.4), lineWidth: 1))
                                .shadow(color: Color.yellow.opacity(0.3), radius: 4)
                        }
                        
                        Button(action: { showWeeklyReport = true }) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 14))
                                .foregroundColor(neonCyan)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(neonCyan.opacity(0.4), lineWidth: 1))
                                .shadow(color: neonCyan.opacity(0.3), radius: 4)
                        }
                        
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 15)
                
                // ═══════════════════════════════════════════
                // ZONE 2 — GREETING + EYE HEALTH RING
                // ═══════════════════════════════════════════
                HStack(spacing: 20) {
                    // Greeting
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greetingText)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(neonCyan.opacity(0.7))
                            .tracking(2)
                        
                        Text(pilotNickname.isEmpty ? "PILOT" : pilotNickname.uppercased())
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    
                    Spacer()
                    
                    // Eye Health Ring
                    VisionIndexMeter()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // ═══════════════════════════════════════════
                // ZONE 3 — CENTER HERO (THE SHIP)
                // ═══════════════════════════════════════════
                
                ZStack {
                    Circle()
                        .fill(previewColor.opacity(isLaunching ? 0.8 : 0.2))
                        .frame(width: 300, height: 300)
                        .blur(radius: isLaunching ? 80 : 50)
                        .scaleEffect(isLaunching ? 1.5 : 1.0)
                        .animation(.easeOut(duration: 0.8), value: isLaunching)
                        .animation(.easeInOut(duration: 0.4), value: previewColor)
                    
                    ShipRenderView(
                        shipType: currentShipType,
                        color: .white,
                        size: 120
                    )
                        .shadow(color: isLaunching ? .white : previewColor, radius: isLaunching ? 60 : (isHovering ? 25 : 10), x: 0, y: 0)
                        .offset(y: isLaunching ? -1000 : (heroFloating ? -20 : 20))
                        .offset(y: isLaunching ? 0 : (isHovering ? -10 : 10))
                        .scaleEffect(isLaunching ? 0.5 : 1.0)
                        .opacity(isLaunching ? 0.0 : 1.0)
                        .animation(
                            isLaunching ? .easeIn(duration: 0.8) : .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                            value: isLaunching
                        )
                        .animation(
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                            value: isHovering
                        )
                }
                // PARALLAX LAYER 2 — Ship tilts in 3D with device gyroscope
                .rotation3DEffect(
                    .degrees(motion.pitch * 15),
                    axis: (x: 1, y: 0, z: 0)
                )
                .rotation3DEffect(
                    .degrees(motion.roll * 15),
                    axis: (x: 0, y: 1, z: 0)
                )
                
                Spacer()
                
                // ═══════════════════════════════════════════
                // ZONE 4 — MAIN QUEST TRACKER
                // ═══════════════════════════════════════════
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if progressionManager.isQuestComplete {
                        // Claim quest reward (XP + tier advance)
                        progressionManager.claimQuestReward()
                    } else {
                        // Open Pilot Dossier
                        showPilotDossier = true
                    }
                }) {
                    ActiveMissionCard(progression: progressionManager, accentColor: neonCyan)
                }
                .buttonStyle(PressScaleButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                // ═══════════════════════════════════════════
                // ZONE 5 — QUICK ACTION CARDS
                // ═══════════════════════════════════════════
                HStack(spacing: 12) {
                    QuickActionCard(icon: "cross.case.fill", label: "MED-BAY", color: .green) {
                        showMedBay = true
                    }
                    QuickActionCard(icon: "sparkles", label: "GALAXY", color: .purple) {
                        showGalaxy = true
                    }
                    QuickActionCard(icon: "wrench.and.screwdriver.fill", label: "SHIPYARD", color: .yellow) {
                        showShipyard = true
                    }
                    QuickActionCard(icon: "list.bullet.rectangle.portrait.fill", label: "BOUNTIES", color: neonCyan) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            showDailyMissions = true
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // ═══════════════════════════════════════════
                // ZONE 6 — BOTTOM COMMAND CONSOLE
                // ═══════════════════════════════════════════
                VStack(spacing: 16) {
                    // System Log
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .shadow(color: .green.opacity(0.8), radius: 4)
                        
                        Text(systemLogMessages[currentLogIndex])
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.green.opacity(0.8))
                            .shadow(color: .green.opacity(0.4), radius: 4)
                            .id(currentLogIndex)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.5), value: currentLogIndex)
                    }
                    
                    // Hull Skin Selector
                    VStack(spacing: 8) {
                        Text("HULL SKIN")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                            .tracking(2)
                        
                        HStack(spacing: 16) {
                            ForEach(planeSkins) { skin in
                                SkinSwatch(
                                    skin: skin,
                                    isSelected: previewColor == skin.color,
                                    onSelect: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            previewColor = skin.color
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Launch Button
                    Button(action: {
                        if !isLaunching {
                            isLaunching = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                launchMission()
                            }
                        }
                    }) {
                        HStack {
                            if showSuccessState {
                                ProgressView()
                                    .tint(.black)
                                    .padding(.trailing, 5)
                            }
                            
                            Text(showSuccessState ? "INITIATING..." : "LAUNCH MISSION")
                                .font(.headline)
                                .fontWeight(.bold)
                                .tracking(1)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            LinearGradient(
                                colors: [neonCyan, electricBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: neonCyan.opacity(0.6), radius: launchButtonPulse ? 20 : 10, x: 0, y: 0)
                        .scaleEffect(launchButtonPulse ? 1.05 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: launchButtonPulse
                        )
                    }
                    .disabled(showSuccessState || isLaunching)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            } // End SafeAreaView
            // PARALLAX LAYER 3 — HUD floats opposite to tilt for depth
            .offset(
                x: CGFloat(-motion.roll * 10),
                y: CGFloat(-motion.pitch * 10)
            )
            // Holographic depth effect — Hangar recedes when overlay is active
            .scaleEffect(showDailyMissions ? 0.9 : 1.0)
            .blur(radius: showDailyMissions ? 10 : 0)
            .opacity(showDailyMissions ? 0.5 : 1.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showDailyMissions)
            
            // 3. Daily Missions Holographic Overlay
            if showDailyMissions {
                DailyMissionsView(isPresented: $showDailyMissions)
                    .opacity(showDailyMissions ? 1.0 : 0.0)
                    .scaleEffect(showDailyMissions ? 1.0 : 0.5)
                    .rotation3DEffect(
                        .degrees(showDailyMissions ? 0 : 45),
                        axis: (x: 1, y: 0, z: 0)
                    )
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(10)
            }
        }
        .background(
            // 0. Background Layer Isolated
            CyberpunkBackground(animate: $animateBackground)
                .ignoresSafeArea()
                // 20% overscale creates bleed zone so edges never reveal black
                .scaleEffect(1.2)
                // PARALLAX LAYER 1 — Background drifts gently with device tilt
                .offset(
                    x: CGFloat(motion.roll * 20),
                    y: CGFloat(motion.pitch * 20)
                )
        )
        .sheet(isPresented: $showPilotDossier) {
            PilotDossierView()
        }
        .sheet(isPresented: $showMedBay) {
            MedBayView(isPresented: $showMedBay)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isPresented: $showSettings)
        }
        .fullScreenCover(isPresented: $showGalaxy) {
            FocusGalaxyView()
        }
        .sheet(isPresented: $showShipyard) {
            ShipyardModulesView()
        }
        .sheet(isPresented: $showWeeklyReport) {
            WeeklyReportView()
        }
        .sheet(isPresented: $showAchievements) {
            AchievementsView()
        }
        .onAppear {
            animateBackground = true
            heroFloating = true
            isHovering = true
            launchButtonPulse = true
            isLaunching = false
            
            checkCameraPermissionStatus()
            startSystemLogCycle()
            
            // Animate the health ring on appear
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                ringAnimating = true
            }
        }
        .onDisappear {
            // Clean up log timer
            logTimer?.invalidate()
            logTimer = nil
        }
        .alert("Camera Access Required", isPresented: $showPermissionAlert) {
             Button("Open Settings", role: .none) {
                 if let url = URL(string: UIApplication.openSettingsURLString) {
                     UIApplication.shared.open(url)
                 }
             }
             Button("Cancel", role: .cancel) {}
         } message: {
             Text("BlinkBreak needs camera access to track your eye movements for the game controls.")
         }
    }
    
    // MARK: - Logic
    
    func launchMission() {
         requestCameraPermission()
    }
    
    func checkCameraPermissionStatus() {
         #if targetEnvironment(simulator)
         isSystemReady = true
         #else
         switch AVCaptureDevice.authorizationStatus(for: .video) {
         case .authorized:
             isSystemReady = true
         default:
             isSystemReady = false
         }
         #endif
     }

    func requestCameraPermission() {
        #if targetEnvironment(simulator)
        // Always allow in simulator for testing
        proceedToCalibration()
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            proceedToCalibration()
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.proceedToCalibration()
                    } else {
                        self.showPermissionAlert = true
                    }
                }
            }
            
        case .denied, .restricted:
            showPermissionAlert = true
            
        @unknown default:
            break
        }
        #endif
    }
    
    func proceedToCalibration() {
        withAnimation {
            isSystemReady = true
            showSuccessState = true
        }
        
        // Simulate system initialization delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
               showHangar = false
               showCalibration = true // Transition to Calibration
            }
        }
    }
    
    // MARK: - System Log Timer
    
    private func startSystemLogCycle() {
        logTimer?.invalidate()
        logTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                withAnimation {
                    currentLogIndex = (currentLogIndex + 1) % systemLogMessages.count
                }
            }
        }
    }
    
    // MARK: - Skin Data
    
    private var planeSkins: [PlaneSkin] {
        [
            PlaneSkin(color: Color(red: 0.0, green: 0.94, blue: 1.0), name: "CYAN",    isLocked: false),
            PlaneSkin(color: Color.pink,                               name: "MAGENTA", isLocked: true),
            PlaneSkin(color: Color.yellow,                             name: "GOLD",    isLocked: true)
        ]
    }
}

// MARK: - Skin Selector Models & Views

struct PlaneSkin: Identifiable {
    let id = UUID()
    let color: Color
    let name: String
    let isLocked: Bool
}

/// Individual colour swatch in the skin selector
struct SkinSwatch: View {
    let skin: PlaneSkin
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            ZStack {
                // Glow behind selected
                if isSelected {
                    Circle()
                        .fill(skin.color.opacity(0.3))
                        .frame(width: 56, height: 56)
                        .blur(radius: 8)
                }
                
                // Colour circle
                Circle()
                    .fill(skin.color.opacity(skin.isLocked ? 0.35 : 1.0))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                            .animation(.easeInOut(duration: 0.25), value: isSelected)
                    )
                    .shadow(color: skin.color.opacity(0.6), radius: 6)
                
                // Lock icon overlay for locked skins
                if skin.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .disabled(false) // All skins allow preview, even locked ones
    }
}

// MARK: - Subcomponents

struct PilotProfileCard: View {
    let level: Int
    let xp: Double
    let requiredXP: Double
    
    @AppStorage("pilotNickname") private var pilotNickname: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank Badge
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(pilotNickname.isEmpty ? "UNKNOWN PILOT" : pilotNickname.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundColor(.white)
                    .tracking(1)
                    .monospaced()
                    .shadow(color: Color(red: 0.0, green: 0.94, blue: 1.0).opacity(0.8), radius: 5)
                
                Text("LVL \(level) PILOT")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                // Tiny XP Bar
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 80, height: 4)
                    Capsule()
                        .fill(Color.cyan)
                        .frame(width: 80 * CGFloat(max(0, min(xp / requiredXP, 1.0))), height: 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DailyGoalWidget: View {
    let goal: Int
    
    private var sessionsToday: Int {
        let today = HealthDataManager.shared.last7Days().last
        return today?.sessions ?? 0
    }
    
    private var isComplete: Bool { sessionsToday >= goal }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("MISSION GOAL")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            Text("\(sessionsToday)/\(goal) SESSIONS")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isComplete ? .green : .white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isComplete ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isComplete ? Color.green.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct CyberpunkBackground: View {
    @Binding var animate: Bool
    
    var body: some View {
        ZStack {
            // Base Color
            Color(red: 0.05, green: 0.05, blue: 0.1)
            
            // Grid Effect (Simplified for now)
            GeometryReader { geometry in
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let spacing: CGFloat = 40
                    
                    // Vertical lines
                    for i in 0...Int(width/spacing) {
                        path.move(to: CGPoint(x: CGFloat(i) * spacing, y: 0))
                        path.addLine(to: CGPoint(x: CGFloat(i) * spacing, y: height))
                    }
                    
                    // Horizontal lines
                    for i in 0...Int(height/spacing) {
                        path.move(to: CGPoint(x: 0, y: CGFloat(i) * spacing))
                        path.addLine(to: CGPoint(x: width, y: CGFloat(i) * spacing))
                    }
                }
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
            }
            .mask(LinearGradient(colors: [.clear, .black, .clear], startPoint: .top, endPoint: .bottom))

            // Star Field
            ForEach(0..<20) { _ in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.1...0.6)))
                    .frame(width: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
            }
        }
    }
}

// MARK: - Gamification Subcomponents

/// Animated circular arc showing daily session progress
struct EyeHealthRingView: View {
    let sessionsCompleted: Int
    let goal: Int
    let isAnimating: Bool
    let accentColor: Color
    
    private var progress: Double {
        min(Double(sessionsCompleted) / Double(goal), 1.0)
    }
    
    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 5)
                .frame(width: 56, height: 56)
            
            // Fill arc
            Circle()
                .trim(from: 0, to: isAnimating ? progress : 0)
                .stroke(
                    AngularGradient(
                        colors: [accentColor, accentColor.opacity(0.4)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(-90))
                .shadow(color: accentColor.opacity(0.6), radius: 4)
            
            // Center label
            VStack(spacing: 0) {
                Text("\(sessionsCompleted)/\(goal)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text("EYES")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
    }
}

/// Dynamic Main Quest card — reads live state from ProgressionManager
struct ActiveMissionCard: View {
    @ObservedObject var progression: ProgressionManager
    let accentColor: Color
    
    private let goldColor = Color(red: 1.0, green: 0.84, blue: 0.0)
    
    var body: some View {
        let isComplete = progression.isQuestComplete
        let iconColor: Color = isComplete ? goldColor : .orange
        let barFraction = CGFloat(progression.questFraction)
        
        HStack(spacing: 12) {
            // Icon
            Image(systemName: isComplete ? "checkmark.seal.fill" : "bolt.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(iconColor)
                .shadow(color: iconColor.opacity(0.8), radius: isComplete ? 8 : 4)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Text + Progress
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("GLITCH HUNTER")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(isComplete ? goldColor : .white)
                        .shadow(color: isComplete ? goldColor.opacity(0.6) : .clear, radius: 6)
                    
                    Spacer()
                    
                    Text("+\(progression.questXPReward) XP")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(isComplete ? goldColor : accentColor)
                }
                
                Text(progression.questDescription)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(isComplete ? goldColor.opacity(0.8) : .gray)
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: isComplete ? [goldColor, .yellow] : [accentColor, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * barFraction, height: 4)
                            .shadow(color: (isComplete ? goldColor : accentColor).opacity(0.5), radius: 3)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: isComplete
                            ? [goldColor.opacity(0.7), goldColor.opacity(0.3)]
                            : [accentColor.opacity(0.5), .clear, .orange.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isComplete ? 1.5 : 1
                )
        )
        .shadow(color: (isComplete ? goldColor : accentColor).opacity(0.2), radius: 6)
    }
}

/// Individual quick action tile for the horizontal scroll row
struct QuickActionCard: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.6), radius: 4)
                
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 75)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.2), radius: 4)
        }
    }
}

/// Tactical "Daily Bounties" HUD module — replaces the old streak capsule
struct MissionModuleBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            // Mission icon with glow
            Image(systemName: "list.bullet.rectangle.portrait.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.cyan)
                .shadow(color: .cyan.opacity(0.8), radius: 6)
            
            // Dual-line tactical text
            VStack(alignment: .leading, spacing: 2) {
                Text("ACTIVE PROTOCOLS")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(.cyan)
                
                Text("DAILY BOUNTIES")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.cyan.opacity(0.8), .clear, .orange.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .cyan.opacity(0.4), radius: 8)
    }
}

struct LastMissionReportView: View {
    let focusScore: Int
    let reactionTime: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Text("LAST MISSION REPORT")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .tracking(2)
            
            HStack(spacing: 20) {
                // Focus Stat
                VStack(spacing: 2) {
                    Text("AVG FOCUS")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("\(focusScore)%")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .shadow(color: .cyan.opacity(0.5), radius: 5)
                }
                
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 24)
                
                // Reaction Stat
                VStack(spacing: 2) {
                    Text("REACTION")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(String(format: "%.2fs", reactionTime))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .shadow(color: .green.opacity(0.5), radius: 5)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Daily Missions Holographic Overlay

struct DailyMissionsView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var bountyManager: BountyManager
    
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("DAILY BOUNTIES")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(neonCyan)
                .tracking(4)
                .shadow(color: neonCyan.opacity(0.8), radius: 10)
            
            // Divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, neonCyan.opacity(0.6), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
            
            // Missions List
            VStack(spacing: 16) {
                ForEach(Array(bountyManager.activeBounties.enumerated()), id: \.element.id) { index, bounty in
                    HStack(spacing: 12) {
                        // Status icon
                        Image(systemName: bounty.isComplete ? "checkmark.circle.fill" : bounty.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(bounty.isComplete ? .green : neonCyan.opacity(0.5))
                            .shadow(color: (bounty.isComplete ? Color.green : neonCyan).opacity(0.6), radius: 4)
                        
                        // Mission title
                        Text(bounty.title)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(bounty.isComplete ? .gray : .white)
                            .strikethrough(bounty.isComplete, color: .gray)
                        
                        Spacer()
                        
                        // Progress
                        Text("\(min(bounty.current, bounty.target))/\(bounty.target)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(bounty.isComplete ? .green : neonCyan.opacity(0.8))
                    }
                    .padding(.horizontal, 8)
                    
                    // Row divider (except last)
                    if index < bountyManager.activeBounties.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                    }
                }
            }
            
            // Close Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    isPresented = false
                }
            }) {
                Text("CLOSE")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [neonCyan, Color(red: 0.0, green: 0.4, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: neonCyan.opacity(0.5), radius: 8)
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(neonCyan.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: neonCyan.opacity(0.3), radius: 20)
        )
        .padding(.horizontal, 30)
    }
}
// MARK: - SafeAreaView Helper
/// A structural wrapper requested to represent safe-area-bound content explicitly, 
/// without impacting any of the native underlying iOS SwiftUI feature boundaries.
struct SafeAreaView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
    }
}

#Preview {
    HangarView(showHangar: .constant(true), showCalibration: .constant(false))
}
