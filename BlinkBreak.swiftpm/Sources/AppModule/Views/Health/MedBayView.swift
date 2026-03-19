import SwiftUI

/// Educational "Medical Archives" screen explaining the health science behind BlinkBreak.
/// Uses cyberpunk glassmorphic cards with neon green/cyan medical accents.
struct MedBayView: View {
    @Binding var isPresented: Bool
    
    private let neonGreen = Color(red: 0.0, green: 0.9, blue: 0.4)
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    var body: some View {
        ZStack {
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 32))
                            .foregroundColor(neonGreen)
                            .shadow(color: neonGreen.opacity(0.8), radius: 12)
                        
                        Text("MEDICAL ARCHIVES")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(neonGreen)
                            .tracking(3)
                            .shadow(color: neonGreen.opacity(0.6), radius: 10)
                        
                        Text("DIGITAL EYE HEALTH INTELLIGENCE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(2)
                    }
                    .padding(.top, 40)
                    
                    // Section 1 — The Threat
                    MedBayCard(
                        icon: "eye.trianglebadge.exclamationmark",
                        iconColor: .red,
                        title: "KNOWN ANOMALY: The Dry Eye Glitch",
                        content: """
                        When staring at screens, your blink rate drops from a healthy 15–20 blinks/min \
                        to as low as 3–4 blinks/min. This is called **blink suppression**.
                        
                        Without regular blinking, your tear film evaporates, leaving the cornea exposed. \
                        This causes dryness, irritation, blurred vision, and long-term strain — \
                        collectively known as **Computer Vision Syndrome (CVS)**.
                        
                        Over 50% of frequent screen users experience CVS symptoms.
                        """
                    )
                    
                    // Section 2 — The Countermeasure
                    MedBayCard(
                        icon: "drop.fill",
                        iconColor: neonCyan,
                        title: "PROTOCOL: Weaponized Blinking",
                        content: """
                        Each blink spreads a fresh layer of **tear film** across your cornea — \
                        a 3-layer shield of lipids, water, and mucin that protects, nourishes, \
                        and lubricates your eyes.
                        
                        In BlinkBreak, every **double-blink fires your laser**. This trains your brain \
                        to blink deliberately and frequently, counteracting screen-induced suppression.
                        
                        The game transforms a passive health habit into an **active combat mechanic**.
                        """
                    )
                    
                    // Section 3 — The 20-20-20 Rule
                    MedBayCard(
                        icon: "timer",
                        iconColor: .yellow,
                        title: "THE 20-20-20 RULE",
                        content: """
                        Ophthalmologists recommend: every **20 minutes**, look at something \
                        **20 feet away** for **20 seconds**.
                        
                        This relaxes the ciliary muscle inside your eye, which contracts to focus \
                        on near objects. Sustained contraction causes **accommodative fatigue** — \
                        the primary driver of screen headaches.
                        
                        BlinkBreak's **Boss Break** mechanic and **Tactical Pause** system are \
                        designed around this principle, prompting you to rest at healthy intervals.
                        """
                    )
                    
                    // Close Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            isPresented = false
                        }
                    }) {
                        Text("CLOSE ARCHIVE")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [neonGreen, neonCyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: neonGreen.opacity(0.5), radius: 10)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 50)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

/// Individual glassmorphic knowledge card for the Med-Bay
struct MedBayCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .shadow(color: iconColor.opacity(0.6), radius: 6)
                
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            // Divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [iconColor.opacity(0.6), iconColor.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
            
            Text(content)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(iconColor.opacity(0.15), lineWidth: 1)
        )
    }
}

#Preview {
    MedBayView(isPresented: .constant(true))
}
