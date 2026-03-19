import SwiftUI

/// A cinematic, high-fidelity onboarding experience for BlinkBreak.
/// Features a futuristic sci-fi theme with holographic animations, neon glow effects,
/// and deep space aesthetics.
struct OnboardingView: View {
    // MARK: - Bindings
    @Binding var showOnboarding: Bool
    @Binding var showHangar: Bool

    // MARK: - State
    @State private var currentPage = 0
    @State private var isAnimating = false
    @State private var orbRotation: Double = 0
    @State private var orbScale: CGFloat = 1.0
    
    // MARK: - Constants
    private let totalPages = 4
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0) // #00F0FF
    private let electricBlue = Color(red: 0.0, green: 0.4, blue: 1.0)
    private let deepSpaceBlack = Color(red: 0.05, green: 0.05, blue: 0.1)

    // MARK: - Onboarding Data
    private let screens = [
        OnboardingData(
            title: "BLINKBREAK",
            subtitle: "SYSTEM INITIALIZATION",
            description: "Welcome, Pilot. Your mission is to defeat digital eye strain through advanced ocular combat training.",
            iconName: "eye.circle.fill"
        ),
        OnboardingData(
            title: "OCULAR CONTROL",
            subtitle: "NEURAL LINK ESTABLISHED",
            description: "Navigate deep space using only your eyes. Look to steer. Blink to engage countermeasures.",
            iconName: "arrow.up.arrow.down.circle"
        ),
        OnboardingData(
            title: "20-20-20 PROTOCOL",
            subtitle: "HEALTH SYSTEMS ONLINE",
            description: "Every 20 minutes, scan a target 20 feet away for 20 seconds. Reinforce your vision shields.",
            iconName: "clock.arrow.2.circlepath"
        ),
        OnboardingData(
            title: "SECURE CHANNEL",
            subtitle: "DATA ENCRYPTION ACTIVE",
            description: "All biometric data is processed locally on your device. Your flight telemetry remains classified.",
            iconName: "lock.shield"
        )
    ]

    var body: some View {
        ZStack {
            // 1. Kinetic Background Layer
            OnboardingDeepSpaceBackground(animate: $isAnimating)
                .ignoresSafeArea()

            // 2. Central Holographic Element (Persistent across pages)
            VStack {
                Spacer()
                HolographicOrb(rotation: $orbRotation, scale: $orbScale, color: neonCyan)
                    .frame(width: 300, height: 300)
                    .offset(y: -50) // Shift up slightly to balance layout
                Spacer()
            }
            .allowsHitTesting(false) // Let touches pass through to background if needed

            // 3. Content Layer (Paged)
            ZStack {
                // Content Card Area (Full Screen Swipe)
                TabView(selection: $currentPage) {
                    ForEach(0..<screens.count, id: \.self) { index in
                        VStack {
                            OnboardingContentCard(data: screens[index], accentColor: neonCyan)
                                .padding(.top, 40) // Move card to upper section
                            
                            Spacer() // Push remaining content up
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle()) // Enable full-screen hit testing
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // 4. Footer Controls (Overlaid at bottom)
                VStack {
                    Spacer()
                    
                    VStack(spacing: 24) {
                        // Custom Page Indicators
                        HStack(spacing: 12) {
                            ForEach(0..<totalPages, id: \.self) { index in
                                CyberPageIndicator(isActive: currentPage == index, color: neonCyan)
                            }
                        }
                        
                        // Main Action Button
                        Button(action: handleNext) {
                            NeonButtonContent(
                                text: currentPage == totalPages - 1 ? "LAUNCH HANGAR" : "NEXT STEP",
                                color: neonCyan
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.bottom, 50) // Bottom safe area breathing room
                    .padding(.horizontal, 30)
                }
            }
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: currentPage) { newValue in
            triggerPageChangeAnimation()
        }
    }

    // MARK: - App Storage
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    // MARK: - Actions & Logic

    private func handleNext() {
        if currentPage < totalPages - 1 {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                currentPage += 1
            }
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        // Dramatic exit animation
        withAnimation(.easeInOut(duration: 1.0)) {
            orbScale = 20.0 // Zoom into the orb/portal
            isAnimating = false // Stop background motion
        }
        
        // Delay logic to swap views
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
             hasCompletedOnboarding = true
             showOnboarding = false
             showHangar = true // Assuming showHangar triggers the transition in parent
        }
    }

    private func startAnimations() {
        isAnimating = true
        // Continuous subtle rotation for the Orb
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            orbRotation = 360
        }
    }
    
    private func triggerPageChangeAnimation() {
        // Pulse the orb on page change
        withAnimation(.easeInOut(duration: 0.3)) {
            orbScale = 1.2
        }
        withAnimation(.easeInOut(duration: 0.3).delay(0.3)) {
            orbScale = 1.0
        }
    }
}

// MARK: - Models

struct OnboardingData {
    let title: String
    let subtitle: String
    let description: String
    let iconName: String
}

// MARK: - Subviews

/// Main Content Card with Glassmorphism
struct OnboardingContentCard: View {
    let data: OnboardingData
    let accentColor: Color
    
    var body: some View {
        VStack(spacing: 16) {
            // Animated Icon
            if #available(iOS 17.0, *) {
                Image(systemName: data.iconName)
                    .font(.system(size: 48))
                    .foregroundColor(accentColor)
                    .symbolEffect(.bounce, value: data.title)
                    .shadow(color: accentColor.opacity(0.6), radius: 12, x: 0, y: 0)
                    .padding(.bottom, 8)
            } else {
                Image(systemName: data.iconName)
                    .font(.system(size: 48))
                    .foregroundColor(accentColor)
                    .shadow(color: accentColor.opacity(0.6), radius: 12, x: 0, y: 0)
                    .padding(.bottom, 8)
            }
            
            VStack(spacing: 4) {
                Text(data.title)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1)
                    .shadow(color: accentColor.opacity(0.4), radius: 8, x: 0, y: 0)
                    .minimumScaleFactor(0.5) // Prevent cutoff
                    .lineLimit(1) // Single line title
                    .multilineTextAlignment(.center)
                
                Text(data.subtitle)
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(2)
                    .foregroundColor(accentColor.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            Text(data.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(Color.white.opacity(0.8))
                .lineSpacing(4)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
        }
        .padding(30) // Inner content padding (unchanged)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .opacity(0.9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [accentColor.opacity(0.4), accentColor.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 20) // Updated horizontal padding to 20
    }
}

/// A futuristic button with improved visual feedback
struct NeonButtonContent: View {
    let text: String
    let color: Color
    
    @State private var isHovering = false // For scale effect
    
    var body: some View {
        ZStack {
            // Glow layer
            Capsule()
                .fill(color)
                .opacity(0.2)
                .blur(radius: 12)
            
            // Gradient Background
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [color, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // Highlight / Shine
            Capsule()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                
            HStack {
                Text(text)
                    .font(.headline)
                    .fontWeight(.bold)
                    .tracking(1)
                    .foregroundColor(.black)
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.black))
                    .foregroundColor(.black.opacity(0.7))
            }
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.spring(), value: isHovering)
    }
}

/// Custom futuristic page indicator
struct CyberPageIndicator: View {
    let isActive: Bool
    let color: Color
    
    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .blur(radius: 4)
            }
            
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? color : Color.white.opacity(0.2))
                .frame(width: isActive ? 16 : 8, height: 8)
                .animation(.spring(), value: isActive)
        }
    }
}

// MARK: - Visual Effects

/// Complex animated background representing deep space travel
struct OnboardingDeepSpaceBackground: View {
    @Binding var animate: Bool
    @State private var starOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Deep Void
            Color(red: 0.05, green: 0.05, blue: 0.1)
                .overlay(
                    RadialGradient(
                        colors: [Color.blue.opacity(0.1), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 400
                    )
                )
            
            // Moving Grid (Perspective)
            GeometryReader { geo in
                ZStack {
                    // Vertical moving lines (illusion of forward speed)
                    Path { path in
                        let width = geo.size.width
                        let height = geo.size.height
                        
                        // Radiate from center
                        for i in 0..<20 {
                            let angle = Double(i) * (360.0 / 20.0)
                            let x = width/2 + cos(angle * .pi / 180) * width
                            let y = height/2 + sin(angle * .pi / 180) * height
                            
                            path.move(to: CGPoint(x: width/2, y: height/2))
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(Color.cyan.opacity(0.1), lineWidth: 1)
                    
                    // Concentric circles moving outward
                    ForEach(0..<5) { i in
                        Circle()
                            .stroke(Color.cyan.opacity(0.05), lineWidth: 1)
                            .scaleEffect(animate ? 2.0 : 0.1)
                            .opacity(animate ? 0.0 : 0.5)
                            .animation(
                                Animation.linear(duration: 4)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.8),
                                value: animate
                            )
                    }
                }
                .mask(RadialGradient(colors: [.black, .clear], center: .center, startRadius: 100, endRadius: 600))
            }
            
            // Starfield
            GeometryReader { geo in
                ForEach(0..<40) { _ in
                    Circle()
                        .fill(Color.white)
                        .frame(width: CGFloat.random(in: 1...3))
                        .opacity(Double.random(in: 0.3...0.8))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                }
            }
        }
    }
}

/// Central holographic element that acts as the "Ghost" of the machine
struct HolographicOrb: View {
    @Binding var rotation: Double
    @Binding var scale: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            // Core Glow
            Circle()
                .fill(color.opacity(0.1))
                .blur(radius: 40)
            
            // Rotating Outer Rings
            ForEach(0..<3) { i in
                Circle()
                    .trim(from: 0.0, to: 0.7)
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.8), .clear],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(rotation * (Double(i) * 0.5 + 1.0)))
                    .rotation3DEffect(
                        .degrees(45 + Double(i * 30)),
                        axis: (x: 1, y: 1, z: 0)
                    )
                    .frame(width: 200 + CGFloat(i * 40), height: 200 + CGFloat(i * 40))
            }
            
            // Inner Data Core
            Circle()
                .strokeBorder(color.opacity(0.5), lineWidth: 1)
                .background(Circle().fill(color.opacity(0.05)))
                .frame(width: 140, height: 140)
                .overlay(
                    Image(systemName: "globe")
                        .font(.system(size: 60, weight: .thin))
                        .foregroundColor(color.opacity(0.8))
                        .rotationEffect(.degrees(-rotation))
                )
        }
        .scaleEffect(scale)
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true), showHangar: .constant(false))
        .preferredColorScheme(.dark)
}