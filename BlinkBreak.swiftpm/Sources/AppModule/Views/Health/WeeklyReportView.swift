import SwiftUI

/// A premium, glassmorphic analytics dashboard accessed from HangarView.
/// Displays rolling weekly ocular health statistics natively stored within HealthDataManager.
struct WeeklyReportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var healthData = HealthDataManager.shared
    
    // Animation States
    @State private var animateRing = false
    @State private var showStats = false
    
    // Theming
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    private let neonGreen = Color(red: 0.0, green: 0.9, blue: 0.4)
    private let alertRed = Color(red: 1.0, green: 0.2, blue: 0.2)
    
    var body: some View {
        ZStack {
            // Base layer
            Color.black.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 30) {
                    headerSection
                    
                    if showStats {
                        summaryMessageSection
                        metricsGridSection
                        healthRingSection
                        trendChartSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 60)
            }
            
            // Close Button
            VStack {
                Spacer()
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                }) {
                    Text("CLOSE REPORT")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showStats = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                    animateRing = true
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 32))
                .foregroundColor(neonCyan)
                .shadow(color: neonCyan.opacity(0.6), radius: 8)
            
            Text("NEURAL VISION REPORT")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .tracking(3)
                .shadow(color: neonCyan.opacity(0.3), radius: 5)
            
            // Format Week Date safely
            let weekString = healthData.currentWeek.weekStartDate.formatted(.dateTime.month().day())
            Text("WEEK STARTING \(weekString.uppercased())")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .tracking(2)
        }
        .padding(.top, 40)
    }
    
    private var summaryMessageSection: some View {
        let reduction = healthData.currentWeek.strainReductionPercent
        let (message, color) = summaryText(for: reduction)
        
        return VStack(spacing: 12) {
            Text("SYSTEM ANALYSIS")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(2)
            
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.15), radius: 10)
    }
    
    private var metricsGridSection: some View {
        let stats = healthData.currentWeek
        
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ReportStatCard(
                title: "SESSIONS",
                value: "\(stats.totalSessions)",
                icon: "play.circle.fill",
                color: neonCyan
            )
            ReportStatCard(
                title: "TOTAL BLINKS",
                value: "\(stats.totalBlinks)",
                icon: "eye.fill",
                color: neonGreen
            )
            ReportStatCard(
                title: "FOCUS TIME",
                value: "\(Int(stats.totalFocusSeconds / 60))m",
                icon: "timer",
                color: .orange
            )
            ReportStatCard(
                title: "BOSS BREAKS",
                value: "\(Int(stats.totalBreakSeconds / 60))m",
                icon: "cup.and.saucer.fill",
                color: .purple
            )
        }
    }
    
    private var healthRingSection: some View {
        let reduction = CGFloat(healthData.currentWeek.strainReductionPercent) / 100.0
        let displayColor = reduction >= 0.5 ? neonGreen : (reduction > 0.2 ? .orange : alertRed)
        
        return VStack(spacing: 20) {
            Text("OCULAR STRAIN REDUCTION")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .tracking(2)
            
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 20)
                
                // Animated Fill
                Circle()
                    .trim(from: 0, to: animateRing ? reduction : 0)
                    .stroke(
                        displayColor,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: displayColor.opacity(0.5), radius: 10)
                
                // Center Readout
                VStack(spacing: 2) {
                    Text("\(Int(reduction * 100))%")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text("OPTIMAL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(displayColor)
                        .tracking(1)
                }
            }
            .frame(width: 200, height: 200)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white.opacity(0.04))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
    
    private var trendChartSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.white.opacity(0.5))
                Text("HISTORICAL STRAIN REDUCTION")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(2)
                Spacer()
            }
            
            // SwiftUI Native Bar Chart Visualization
            HStack(alignment: .bottom, spacing: 12) {
                // Determine the last up to 6 historic weeks
                let chartHistory = Array(healthData.history.suffix(6))
                
                // Always render 7 slots (Current Week + 6 padding minimum)
                ForEach(0..<6, id: \.self) { i in
                    if i < chartHistory.count {
                        ChartBar(percent: chartHistory[i].strainReductionPercent)
                    } else {
                        ChartBar(percent: 0, isEmpty: true)
                    }
                }
                
                // Render the Active Current Week last
                ChartBar(percent: healthData.currentWeek.strainReductionPercent, isCurrent: true)
            }
            .frame(height: 120)
            .padding(.vertical, 10)
        }
        .padding(20)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
    
    // MARK: - Logic Helpers
    
    private func summaryText(for reduction: Int) -> (String, Color) {
        if reduction >= 80 {
            return ("Exceptional performance. Your blinking habits have dramatically minimized optical fatigue.", neonGreen)
        } else if reduction >= 50 {
            return ("Solid progress. Your ocular strain decreased significantly this week.", neonCyan)
        } else if reduction >= 20 {
            return ("Moderate improvement. Engage in longer missions to increase blink conditioning.", .orange)
        } else {
            return ("Critical strain levels detected. You must actively break gaze and blink frequently.", alertRed)
        }
    }
}

// MARK: - Subcomponents

struct ReportStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: color.opacity(0.3), radius: 4)
                
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}

struct ChartBar: View {
    let percent: Int
    var isEmpty: Bool = false
    var isCurrent: Bool = false
    
    private let heightRatio = 100.0
    
    @State private var animatedHeight: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 20)
                    
                    if !isEmpty {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: isCurrent ? [Color.cyan, Color.blue] : [Color.gray.opacity(0.6), Color.gray.opacity(0.3)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 20, height: animatedHeight * geo.size.height)
                            .shadow(color: isCurrent ? Color.cyan.opacity(0.5) : .clear, radius: 6)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            Text(isCurrent ? "NOW" : (isEmpty ? "-" : "\(percent)%"))
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(isCurrent ? Color.cyan : .gray)
        }
        .onAppear {
            let targetRatio = CGFloat(percent) / heightRatio
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(Double.random(in: 0...0.3))) {
                animatedHeight = targetRatio
            }
        }
    }
}

#Preview {
    WeeklyReportView()
}
