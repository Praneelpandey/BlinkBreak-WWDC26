import SwiftUI

struct FocusGalaxyView: View {
    @StateObject private var progressManager = ProgressManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedStar: FocusStar?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Simple Starfield Background
            ForEach(0..<40, id: \.self) { _ in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.1...0.4)))
                    .frame(width: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
            }
            
            VStack {
                // Header
                HStack {
                    Button(action: {
                        HapticManager.shared.playSelectionHaptic()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                    Spacer()
                    Text("MEMORY GALAXY")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(3)
                        .shadow(color: .purple.opacity(0.8), radius: 10)
                    Spacer()
                    Image(systemName: "chevron.left").opacity(0)
                }
                .padding()
                
                if progressManager.memoryGalaxy.isEmpty {
                    Spacer()
                    Text("NO STARS IN YOUR GALAXY YET.\nPLAY A MISSION.")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Spacer()
                } else {
                    // Scatter Plot Area
                    GeometryReader { geo in
                        let sortedStars = progressManager.memoryGalaxy.sorted { $0.date < $1.date }
                        
                        ZStack {
                            ForEach(Array(sortedStars.enumerated()), id: \.element.id) { index, star in
                                let xPos = calculateX(index: index, total: sortedStars.count, width: geo.size.width)
                                let yPos = calculateY(score: star.focusScore, height: geo.size.height)
                                let size = min(max(CGFloat(star.duration) / 8.0, 15.0), 40.0)
                                let color = colorForScore(star.focusScore)
                                
                                Button(action: {
                                    HapticManager.shared.playSelectionHaptic()
                                    selectedStar = star
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(color.opacity(0.3))
                                            .frame(width: size + 10, height: size + 10)
                                            .blur(radius: 6)
                                        
                                        Circle()
                                            .fill(color)
                                            .frame(width: size, height: size)
                                            .shadow(color: color.opacity(0.8), radius: 6)
                                            .overlay(Circle().stroke(Color.white, lineWidth: selectedStar?.id == star.id ? 2 : 0))
                                    }
                                }
                                .position(x: xPos, y: yPos)
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(40)
                }
            }
        }
        .fullScreenCover(item: $selectedStar) { star in
            MissionReplayView(star: star)
        }
    }
    
    private func calculateX(index: Int, total: Int, width: CGFloat) -> CGFloat {
        if total <= 1 { return width / 2 }
        return CGFloat(index) / CGFloat(total - 1) * (width - 40) + 20
    }
    
    private func calculateY(score: Double, height: CGFloat) -> CGFloat {
        let normalized = max(0, min(100, score)) / 100.0
        return height - (CGFloat(normalized) * (height - 40) + 20)
    }
    
    private func colorForScore(_ score: Double) -> Color {
        if score >= 90 { return .green }
        if score >= 70 { return .yellow }
        if score >= 50 { return .orange }
        return .red
    }
}
