import SwiftUI
import LocalAuthentication

// MARK: - PilotDossierView (Main Dashboard)

struct PilotDossierView: View {
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Persisted Data (read directly from @AppStorage — always up to date)
    @AppStorage("playerLevel") private var playerLevel: Int = 1
    @AppStorage("playerXP") private var playerXP: Double = 0.0
    @AppStorage("totalSessions") private var totalSessions: Int = 0
    @AppStorage("totalGlitchesPurged") private var totalGlitchesPurged: Int = 0
    @AppStorage("totalFocusSeconds") private var totalFocusSeconds: Double = 0.0
    @AppStorage("totalShots") private var totalShots: Int = 0
    @AppStorage("totalHits") private var totalHits: Int = 0
    @AppStorage("pilotNickname") private var pilotName: String = "PILOT"
    @AppStorage("pilotAvatar") private var pilotAvatarId: String = "vanguard"
    
    private var currentAvatar: PilotAvatar {
        PilotAvatar.allAvatars.first { $0.id == pilotAvatarId } ?? PilotAvatar.allAvatars[0]
    }
    
    private let xpRequiredForNextLevel: Double = 500.0
    
    // MARK: - State
    @State private var selectedStatTitle: String?
    @State private var isSyncing = false
    @State private var syncComplete = false
    
    // MARK: - Constants
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    private let electricBlue = Color(red: 0.0, green: 0.4, blue: 1.0)
    private let neonGreen = Color(red: 0.0, green: 1.0, blue: 0.6)
    
    // MARK: - Computed Properties
    private var rankTitle: String {
        switch playerLevel {
        case 0...3: return "CADET TRAINEE"
        case 4...7: return "FLIGHT OFFICER"
        case 8...11: return "SQUADRON LEADER"
        case 12...15: return "ELITE NAVIGATOR"
        case 16...20: return "ACE COMMANDER"
        case 21...30: return "GHOST PILOT"
        default: return "LEGENDARY AVIATOR"
        }
    }
    
    private var focusTimeFormatted: String {
        let h = Int(totalFocusSeconds) / 3600
        let m = (Int(totalFocusSeconds) % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m)m"
        }
    }
    
    private var accuracy: String {
        guard totalShots > 0 else { return "—" }
        let pct = Int(round(Double(totalHits) / Double(totalShots) * 100))
        return "\(pct)%"
    }
    
    var body: some View {
        ZStack {
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // MARK: - Top Bar
                    HStack {
                        Text("PILOT DOSSIER")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(neonCyan.opacity(0.6))
                            .tracking(3)
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // MARK: - Animated Insignia
                    AnimatedInsigniaView(
                        iconName: currentAvatar.icon,
                        themeColor: currentAvatar.primaryColor,
                        accentColor: currentAvatar.secondaryColor
                    )
                        .frame(height: 160)
                    
                    // MARK: - Pilot Identity
                    VStack(spacing: 8) {
                        Text("CPT. \(pilotName.uppercased())")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(.white)
                            .tracking(3)
                            .shadow(color: currentAvatar.primaryColor.opacity(0.5), radius: 8)
                        
                        Text("\(rankTitle)  ·  RANK \(playerLevel)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(currentAvatar.primaryColor)
                            .tracking(1)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(currentAvatar.primaryColor.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(currentAvatar.primaryColor.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // MARK: - XP Progress Section
                    VStack(spacing: 10) {
                        HStack {
                            Text("LEVEL \(playerLevel)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(playerXP)) / \(Int(xpRequiredForNextLevel)) XP")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                        
                        // XP Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 14)
                                
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [electricBlue, neonCyan],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: max(0, min(1, playerXP / xpRequiredForNextLevel)) * (geometry.size.width - 8),
                                        height: 8
                                    )
                                    .shadow(color: neonCyan.opacity(0.6), radius: 8)
                            }
                        }
                        .frame(height: 14)
                        
                        Text("\(Int(xpRequiredForNextLevel - playerXP)) XP TO NEXT RANK")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // MARK: - Career Track (Battle Pass)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CAREER TRACK")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                            .tracking(2)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                CareerMilestoneCard(
                                    level: 5,
                                    rewardName: "VANGUARD",
                                    icon: "bolt.shield",
                                    playerLevel: playerLevel,
                                    accentColor: neonCyan
                                )
                                CareerMilestoneCard(
                                    level: 10,
                                    rewardName: "RAPTOR",
                                    icon: "airplane",
                                    playerLevel: playerLevel,
                                    accentColor: neonCyan
                                )
                                CareerMilestoneCard(
                                    level: 15,
                                    rewardName: "PHANTOM",
                                    icon: "circle.grid.cross",
                                    playerLevel: playerLevel,
                                    accentColor: neonCyan
                                )
                                CareerMilestoneCard(
                                    level: 20,
                                    rewardName: "ORBITAL",
                                    icon: "globe",
                                    playerLevel: playerLevel,
                                    accentColor: neonCyan
                                )
                                CareerMilestoneCard(
                                    level: 25,
                                    rewardName: "PLASMA DRV",
                                    icon: "flame",
                                    playerLevel: playerLevel,
                                    accentColor: Color(red: 1.0, green: 0.4, blue: 0.0)
                                )
                                CareerMilestoneCard(
                                    level: 30,
                                    rewardName: "LEGENDARY",
                                    icon: "star.fill",
                                    playerLevel: playerLevel,
                                    accentColor: Color(red: 1.0, green: 0.84, blue: 0.0)
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // MARK: - Lifetime Stats Grid
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LIFETIME STATS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                            .tracking(2)
                            .padding(.horizontal)
                        
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                            spacing: 12
                        ) {
                            InteractiveStatCard(
                                title: "TOTAL SESSIONS",
                                value: "\(totalSessions)",
                                icon: "play.circle.fill"
                            ) {
                                selectedStatTitle = "TOTAL SESSIONS"
                            }
                            InteractiveStatCard(
                                title: "GLITCHES PURGED",
                                value: formatNumber(totalGlitchesPurged),
                                icon: "bolt.shield.fill"
                            ) {
                                selectedStatTitle = "GLITCHES PURGED"
                            }
                            InteractiveStatCard(
                                title: "FOCUS TIME",
                                value: focusTimeFormatted,
                                icon: "clock.fill"
                            ) {
                                selectedStatTitle = "FOCUS TIME"
                            }
                            InteractiveStatCard(
                                title: "ACCURACY",
                                value: accuracy,
                                icon: "target"
                            ) {
                                selectedStatTitle = "ACCURACY"
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // MARK: - Sync Neural Data Button
                    Button(action: {
                        guard !isSyncing else { return }
                        
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isSyncing = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            isSyncing = false
                            syncComplete = true
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation {
                                    syncComplete = false
                                }
                            }
                        }
                    }) {
                        Group {
                            if syncComplete {
                                HStack {
                                    Image(systemName: "checkmark.shield.fill")
                                    Text("DATA SYNCED")
                                }
                                .foregroundColor(neonGreen)
                            } else if isSyncing {
                                HStack {
                                    ProgressView()
                                        .tint(neonCyan)
                                    Text("SYNCING TO MAINFRAME...")
                                }
                                .foregroundColor(neonCyan)
                            } else {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("SYNC NEURAL DATA")
                                }
                                .foregroundColor(neonCyan)
                            }
                        }
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(syncComplete ? neonGreen : neonCyan.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: syncComplete ? neonGreen.opacity(0.5) : (isSyncing ? neonCyan.opacity(0.5) : .clear), radius: 8)
                    }
                    .animation(.easeInOut, value: isSyncing)
                    .animation(.easeInOut, value: syncComplete)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
        }
        .background(
            ZStack {
                Color(red: 0.03, green: 0.03, blue: 0.08).ignoresSafeArea()
                CyberpunkGridBackground().opacity(0.25).ignoresSafeArea()
            }
        )
        .sheet(item: $selectedStatTitle) { statTitle in
            StatDetailView(statTitle: statTitle)
        }
    }
    
    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
        }
        return "\(n)"
    }
}

// Make String identifiable for .sheet(item:)
extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - AnimatedInsigniaView

struct AnimatedInsigniaView: View {
    let iconName: String
    let themeColor: Color
    let accentColor: Color
    
    @State private var ring1Rotation: Double = 0
    @State private var ring2Rotation: Double = 0
    @State private var ring3Rotation: Double = 0
    @State private var glowPulse = false
    
    var body: some View {
        ZStack {
            // Outer Ring 3 — widest, slowest, dashed
            Circle()
                .stroke(
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 14])
                )
                .foregroundColor(accentColor.opacity(0.25))
                .frame(width: 150, height: 150)
                .rotationEffect(.degrees(ring3Rotation))
            
            // Ring 2 — medium
            Circle()
                .stroke(
                    style: StrokeStyle(lineWidth: 2, dash: [4, 8])
                )
                .foregroundColor(themeColor.opacity(0.35))
                .frame(width: 115, height: 115)
                .rotationEffect(.degrees(ring2Rotation))
            
            // Inner Ring 1 — smallest, fastest
            Circle()
                .stroke(
                    style: StrokeStyle(lineWidth: 2.5, dash: [3, 6])
                )
                .foregroundColor(themeColor.opacity(0.5))
                .frame(width: 85, height: 85)
                .rotationEffect(.degrees(ring1Rotation))
            
            // Core glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [themeColor.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(glowPulse ? 1.15 : 0.9)
            
            // Center icon — user's selected avatar
            Image(systemName: iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 42, height: 42)
                .foregroundColor(.white)
                .shadow(color: themeColor, radius: glowPulse ? 16 : 8)
                .shadow(color: accentColor.opacity(0.4), radius: 20)
        }
        .onAppear {
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                ring1Rotation = 360
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                ring2Rotation = -360
            }
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                ring3Rotation = 360
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

// MARK: - InteractiveStatCard

struct InteractiveStatCard: View {
    let title: String
    let value: String
    let icon: String
    let action: () -> Void
    
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(neonCyan)
                        .font(.system(size: 16))
                        .shadow(color: neonCyan.opacity(0.5), radius: 4)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                }
                
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(1)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(neonCyan.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: neonCyan.opacity(0.08), radius: 10)
        }
        .buttonStyle(StatCardButtonStyle())
    }
}

struct StatCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - StatDetailView

struct StatDetailView: View {
    @Environment(\.dismiss) var dismiss
    
    let statTitle: String
    
    @State private var barHeights: [CGFloat] = Array(repeating: 0, count: 7)
    @State private var dailyData: [DailyStat] = []
    
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    private let electricBlue = Color(red: 0.0, green: 0.4, blue: 1.0)
    
    // MARK: - Computed data from real stats
    
    /// Extract the relevant metric value from a DailyStat based on which card was tapped
    private func metricValue(for stat: DailyStat) -> Double {
        switch statTitle {
        case "TOTAL SESSIONS":
            return Double(stat.sessions)
        case "GLITCHES PURGED":
            return Double(stat.kills)
        case "FOCUS TIME":
            return stat.focusSeconds / 60.0  // Display in minutes
        case "ACCURACY":
            guard stat.shots > 0 else { return 0 }
            return Double(stat.hits) / Double(stat.shots) * 100.0
        default:
            return Double(stat.sessions)
        }
    }
    
    private var metricValues: [Double] {
        dailyData.map { metricValue(for: $0) }
    }
    
    private var maxValue: Double {
        metricValues.max() ?? 1
    }
    
    /// Normalized bar fractions (0...1) relative to best day
    private var normalizedBars: [CGFloat] {
        let mv = maxValue
        guard mv > 0 else { return Array(repeating: 0, count: 7) }
        return metricValues.map { CGFloat($0 / mv) }
    }
    
    // MARK: - Summary Pills (real data)
    
    private var avgValue: String {
        let vals = metricValues
        let nonZero = vals.filter { $0 > 0 }
        guard !nonZero.isEmpty else { return "—" }
        let avg = nonZero.reduce(0, +) / Double(nonZero.count)
        return formatMetric(avg)
    }
    
    private var bestValue: String {
        let best = metricValues.max() ?? 0
        guard best > 0 else { return "—" }
        return formatMetric(best)
    }
    
    private var trendValue: String {
        let vals = metricValues
        // Compare last 3 days avg vs previous 4 days avg
        let recent = Array(vals.suffix(3))
        let earlier = Array(vals.prefix(4))
        
        let recentAvg = recent.isEmpty ? 0 : recent.reduce(0, +) / Double(recent.count)
        let earlierAvg = earlier.isEmpty ? 0 : earlier.reduce(0, +) / Double(earlier.count)
        
        guard earlierAvg > 0 else {
            return recentAvg > 0 ? "▲ NEW" : "—"
        }
        
        let change = Int(((recentAvg - earlierAvg) / earlierAvg) * 100)
        if change > 0 { return "▲ \(change)%" }
        else if change < 0 { return "▼ \(abs(change))%" }
        else { return "→ 0%" }
    }
    
    private func formatMetric(_ value: Double) -> String {
        switch statTitle {
        case "FOCUS TIME":
            let mins = Int(value)
            return mins >= 60 ? "\(mins / 60)h \(mins % 60)m" : "\(mins)m"
        case "ACCURACY":
            return "\(Int(value))%"
        default:
            return "\(Int(value))"
        }
    }
    
    var body: some View {
        ZStack {
            
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                VStack(spacing: 6) {
                    Text(statTitle)
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(2)
                        .shadow(color: neonCyan.opacity(0.5), radius: 6)
                    
                    Text("LAST 7 DAYS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(1)
                }
                
                VStack(spacing: 12) {
                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(0..<7, id: \.self) { index in
                            VStack(spacing: 6) {
                                // Value label above bar
                                if index < dailyData.count {
                                    let val = metricValues[index]
                                    Text(val > 0 ? formatMetric(val) : "")
                                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                                        .foregroundColor(neonCyan.opacity(0.7))
                                }
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        barHeights[index] > 0
                                            ? LinearGradient(
                                                colors: [electricBlue, neonCyan],
                                                startPoint: .bottom,
                                                endPoint: .top
                                              )
                                            : LinearGradient(
                                                colors: [Color.white.opacity(0.05), Color.white.opacity(0.08)],
                                                startPoint: .bottom,
                                                endPoint: .top
                                              )
                                    )
                                    .frame(height: max(4, 140 * barHeights[index]))
                                    .shadow(color: barHeights[index] > 0 ? neonCyan.opacity(0.3) : .clear, radius: 4)
                                
                                Text(index < dailyData.count ? dailyData[index].dayLabel : "")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 190)
                }
                .padding(20)
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal)
                
                HStack(spacing: 20) {
                    StatSummaryPill(label: "AVG", value: avgValue)
                    StatSummaryPill(label: "BEST", value: bestValue)
                    StatSummaryPill(label: "TREND", value: trendValue)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .background(Color(red: 0.03, green: 0.03, blue: 0.08).ignoresSafeArea())
        .onAppear {
            dailyData = HealthDataManager.shared.last7Days()
            let targets = normalizedBars
            withAnimation(.easeOut(duration: 0.8)) {
                for i in 0..<targets.count {
                    barHeights[i] = targets[i]
                }
            }
        }
    }
}

struct StatSummaryPill: View {
    let label: String
    let value: String
    
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(neonCyan)
                .shadow(color: neonCyan.opacity(0.4), radius: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(neonCyan.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - CareerMilestoneCard (Battle Pass Item)

struct CareerMilestoneCard: View {
    let level: Int
    let rewardName: String
    let icon: String
    let playerLevel: Int
    let accentColor: Color
    
    private var isUnlocked: Bool { playerLevel >= level }
    
    var body: some View {
        VStack(spacing: 8) {
            // Milestone level badge
            Text("LVL \(level)")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(isUnlocked ? .black : .gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isUnlocked ? accentColor : Color.white.opacity(0.1))
                .clipShape(Capsule())
            
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isUnlocked ? accentColor.opacity(0.15) : Color.white.opacity(0.04))
                    .frame(width: 56, height: 56)
                
                if isUnlocked {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(accentColor)
                        .shadow(color: accentColor.opacity(0.6), radius: 6)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            
            // Reward name
            Text(rewardName)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(isUnlocked ? .white : .gray.opacity(0.5))
                .tracking(0.5)
                .lineLimit(1)
            
            // Status indicator
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(accentColor)
                    .shadow(color: accentColor.opacity(0.5), radius: 4)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 12, height: 12)
            }
        }
        .frame(width: 80)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isUnlocked ? accentColor.opacity(0.05) : Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isUnlocked ? accentColor.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: isUnlocked ? accentColor.opacity(0.15) : .clear, radius: 8)
    }
}


struct CyberpunkGridBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let spacing: CGFloat = 30
                
                for i in 0...Int(width / spacing) {
                    path.move(to: CGPoint(x: CGFloat(i) * spacing, y: 0))
                    path.addLine(to: CGPoint(x: CGFloat(i) * spacing, y: height))
                }
                
                for i in 0...Int(height / spacing) {
                    path.move(to: CGPoint(x: 0, y: CGFloat(i) * spacing))
                    path.addLine(to: CGPoint(x: width, y: CGFloat(i) * spacing))
                }
            }
            .stroke(Color.blue.opacity(0.15), lineWidth: 1)
        }
        .mask(
            LinearGradient(
                colors: [.clear, .black, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
