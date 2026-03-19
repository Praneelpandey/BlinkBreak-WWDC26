import SwiftUI

struct VisionIndexMeter: View {
    @ObservedObject var progressManager = ProgressManager.shared
    @State private var isAnimating: Bool = false
    @State private var pulseGlow: Bool = false
    
    private var score: Int {
        progressManager.visionIndexScore
    }
    
    private var statusColor: Color {
        if score >= 90 { return .green }
        if score >= 70 { return .yellow }
        if score >= 50 { return .orange }
        return .red
    }
    
    private var statusText: String {
        if score >= 90 { return "OPTIMAL" }
        if score >= 70 { return "STABLE" }
        if score >= 50 { return "FATIGUED" }
        return "CRITICAL"
    }
    
    private var progress: Double {
        Double(score) / 100.0
    }
    
    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 6)
                .frame(width: 64, height: 64)
            
            // Fill
            Circle()
                .trim(from: 0, to: isAnimating ? progress : 0)
                .stroke(statusColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 64, height: 64)
                .rotationEffect(.degrees(-90))
                .shadow(color: statusColor.opacity(0.8), radius: pulseGlow ? 12 : 4)
            
            // Center labels
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: statusColor.opacity(0.5), radius: 5)
                
                Text(statusText)
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .foregroundColor(statusColor)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) {
                isAnimating = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
    }
}
