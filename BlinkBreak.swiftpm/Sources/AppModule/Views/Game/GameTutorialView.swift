import SwiftUI

/// Pre-game "Mission Briefing" screen shown after Calibration, before GameView.
/// Explains controls with animated holographic cards on an AMOLED-black background.
struct GameTutorialView: View {
    @Binding var showTutorial: Bool
    @Binding var showGame: Bool
    
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    @State private var cardsVisible: [Bool] = [false, false, false, false]
    @State private var buttonReady = false
    
    private let cards: [(icon: String, title: String, desc: String)] = [
        ("eye", "LOOK TO MOVE", "Glance Up / Down to steer your ship"),
        ("eye.trianglebadge.exclamationmark", "BLINK TO ATTACK", "Double-blink to fire your laser cannon"),
        ("waveform.path.ecg", "STRAIN METER", "Avoid eye fatigue — take micro-breaks"),
        ("arrow.uturn.backward", "BOSS BREAK", "Look away from screen to cool the system")
    ]
    
    var body: some View {
        ZStack {
            
            VStack(spacing: 20) {
                // Header
                Text("MISSION BRIEFING")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(neonCyan)
                    .tracking(3)
                    .shadow(color: neonCyan.opacity(0.8), radius: 10)
                    .padding(.top, 50)
                
                Text("STUDY YOUR CONTROLS, PILOT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)
                
                // Briefing Cards
                VStack(spacing: 14) {
                    ForEach(0..<4, id: \.self) { i in
                        BriefingCard(icon: cards[i].icon, title: cards[i].title, description: cards[i].desc)
                            .opacity(cardsVisible[i] ? 1 : 0)
                            .offset(y: cardsVisible[i] ? 0 : 20)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Begin Mission Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showTutorial = false
                        showGame = true
                    }
                }) {
                    Text("BEGIN MISSION")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            LinearGradient(
                                colors: [neonCyan, Color(red: 0.0, green: 0.4, blue: 1.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: neonCyan.opacity(0.6), radius: 12)
                }
                .opacity(buttonReady ? 1 : 0)
                .scaleEffect(buttonReady ? 1 : 0.9)
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            // Stagger card entrance animations
            for i in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        cardsVisible[i] = true
                    }
                }
            }
            // Show button after all cards
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    buttonReady = true
                }
            }
        }
    }
}

/// Individual briefing card with icon, title, and description
struct BriefingCard: View {
    let icon: String
    let title: String
    let description: String
    
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(neonCyan)
                .shadow(color: neonCyan.opacity(0.6), radius: 6)
                .frame(width: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(neonCyan.opacity(0.15), lineWidth: 1)
        )
    }
}

#Preview {
    GameTutorialView(showTutorial: .constant(true), showGame: .constant(false))
}
