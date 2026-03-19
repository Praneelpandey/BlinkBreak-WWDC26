import SwiftUI

struct MissionReplayView: View {
    let star: FocusStar
    @Environment(\.dismiss) var dismiss
    
    @State private var replayProgress: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: {
                        HapticManager.shared.playSelectionHaptic()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("MISSION REPLAY")
                        .font(.headline.weight(.black).monospaced())
                        .foregroundColor(.cyan)
                        .tracking(2)
                    Spacer()
                    Image(systemName: "xmark").opacity(0).padding(8)
                }
                .padding()
                
                // Info
                HStack {
                    VStack(alignment: .leading) {
                        Text("VISION INDEX")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Text("\(Int(star.focusScore))")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("DURATION")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Text("\(Int(star.duration))s")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Telemetry Playback Frame
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Graph Background (grid)
                        Path { path in
                            for i in 1...4 {
                                let y = geo.size.height * CGFloat(i) / 4.0
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: geo.size.width, y: y))
                            }
                        }
                        .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        
                        // Path Plotting
                        if !star.telemetry.isEmpty {
                            Path { path in
                                for (index, pt) in star.telemetry.enumerated() {
                                    let safeDuration = max(star.duration, 0.1) // prevent div by zero
                                    let x = CGFloat(pt.timeOffset / safeDuration) * geo.size.width
                                    let y = CGFloat(1.0 - pt.playerY) * geo.size.height // Invert Y for SwiftUI
                                    
                                    if index == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .trim(from: 0, to: replayProgress)
                            .stroke(
                                LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                            )
                            .shadow(color: .cyan.opacity(0.8), radius: 6)
                            
                            // Event Dots
                            ForEach(star.telemetry.filter { $0.event != nil }, id: \.self) { pt in
                                let safeDuration = max(star.duration, 0.1)
                                let x = CGFloat(pt.timeOffset / safeDuration) * geo.size.width
                                let y = CGFloat(1.0 - pt.playerY) * geo.size.height
                                
                                Circle()
                                    .fill(colorForEvent(pt.event!))
                                    .frame(width: 8, height: 8)
                                    .position(x: x, y: y)
                                    .shadow(color: colorForEvent(pt.event!).opacity(0.8), radius: 5)
                                    .opacity(replayProgress > CGFloat(pt.timeOffset / safeDuration) ? 1.0 : 0.0)
                            }
                        }
                        
                        // Animated Scrubber Line
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 2, height: geo.size.height)
                            .position(x: geo.size.width * replayProgress, y: geo.size.height / 2)
                    }
                }
                .frame(height: 300)
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1)))
                .padding(20)
                
                Spacer()
                
                // Legend
                HStack(spacing: 20) {
                    LegendItem(color: .cyan, label: "LASER")
                    LegendItem(color: .green, label: "POWERUP")
                    LegendItem(color: .red, label: "DAMAGE")
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            let playbackDuration = min(star.duration, 8.0) // Playback cap
            withAnimation(.linear(duration: playbackDuration)) {
                replayProgress = 1.0
            }
        }
    }
    
    private func colorForEvent(_ event: TelemetryEvent) -> Color {
        switch event {
        case .blink: return .cyan
        case .hit: return .red
        case .powerup: return .green
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .shadow(color: color.opacity(0.8), radius: 4)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
        }
    }
}
