import SwiftUI

/// Cinematic auto-advancing splash screen with animated eye reactor and dark gradient background.
/// No user interaction required — auto-navigates via BlinkBreakApp's timer.
struct IntroView: View {
    @State private var isLogoVisible = false
    @State private var isPulsing = false
    @State private var rotationAngle = 0.0
    
    // MARK: - BLINK STATE
    @State private var isBlinking = false
    @State private var blinkTimer: Timer?
    
    // MARK: - LOADING STATE
    @State private var isLoaderAnimating = false
    
    // Theme Colors (preserved)
    private let deepSpaceDark = Color(red: 11/255, green: 15/255, blue: 42/255) // #0b0f2a
    private let neonCyan = Color.cyan
    private let electricBlue = Color.blue
    private let pureBlack = Color.black
    
    var body: some View {
        ZStack {
            // MARK: - BACKGROUND
            RadialGradient(
                gradient: Gradient(colors: [deepSpaceDark, pureBlack]),
                center: .center,
                startRadius: 5,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            // Starfield Overlay (Subtle)
            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<15, id: \.self) { _ in
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: CGFloat.random(in: 1...2), height: CGFloat.random(in: 1...2))
                            .position(
                                x: CGFloat.random(in: 0...geometry.size.width),
                                y: CGFloat.random(in: 0...geometry.size.height)
                            )
                    }
                }
            }
            .opacity(0.6)
            
            // MARK: - MAIN LAYOUT
            VStack {
                Spacer()
                
                // MARK: - HERO ELEMENT: EYE REACTOR (Centered)
                ZStack {
                    // 1. Outer blurred halo
                    Circle()
                        .fill(electricBlue.opacity(0.2))
                        .frame(width: 180, height: 180)
                        .blur(radius: 20)
                    
                    // 2. Mid blue glow ring (Rotating)
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                gradient: Gradient(colors: [electricBlue.opacity(0.8), .clear, electricBlue.opacity(0.8)]),
                                center: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(rotationAngle))
                        .onAppear {
                            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                                rotationAngle = 360
                            }
                        }
                    
                    // MARK: - BLINKING CORE (IRIS + PUPIL)
                    ZStack {
                        // 3. Inner bright cyan core
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [neonCyan.opacity(0.6), electricBlue.opacity(0.3)]),
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 100, height: 100)
                            .overlay(
                                Circle()
                                    .stroke(neonCyan.opacity(0.8), lineWidth: 1)
                            )
                            .shadow(color: neonCyan.opacity(0.5), radius: 15)
                        
                        // 4. Center "Eye" Pupil
                        Circle()
                            .fill(pureBlack)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .fill(neonCyan)
                                    .frame(width: 12, height: 12)
                            )
                    }
                    // Apply Robotic Blink (Vertical Squash)
                    .scaleEffect(x: 1.0, y: isBlinking ? 0.1 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isBlinking)
                }
                .scaleEffect(isPulsing ? 1.05 : 0.95)
                .opacity(isLogoVisible ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isPulsing)
                .onAppear {
                    isPulsing = true
                    scheduleBlink()          // Start robotic blink cycle
                    isLoaderAnimating = true // Start loading ring animation
                    withAnimation(.easeOut(duration: 1.0)) {
                        isLogoVisible = true
                    }
                }
                .onDisappear {
                    // Clean up timer to prevent memory leaks
                    blinkTimer?.invalidate()
                    blinkTimer = nil
                }
                
                // MARK: - TYPOGRAPHY
                VStack(spacing: 16) {
                    Text("BlinkBreak")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: neonCyan.opacity(0.8), radius: 10, x: 0, y: 0)
                        .opacity(isLogoVisible ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 1.0).delay(0.3), value: isLogoVisible)
                    
                    Text("Protect Your Eyes. Play Smarter.")
                        .font(.system(size: 16, weight: .medium, design: .default))
                        .foregroundColor(Color.white.opacity(0.6))
                        .tracking(1.5)
                        .opacity(isLogoVisible ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 1.0).delay(0.5), value: isLogoVisible)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // MARK: - LOADING SECTION (Bottom)
                VStack(spacing: 12) {
                    LoadingRing(isAnimating: $isLoaderAnimating)
                    
                    Text("SYSTEM INITIALIZING...")
                        .font(.custom("Courier", size: 12))
                        .fontWeight(.bold)
                        .foregroundColor(neonCyan.opacity(0.7))
                        .tracking(2)
                }
                .opacity(isLogoVisible ? 1.0 : 0.0)
                .animation(.easeOut(duration: 1.0).delay(0.6), value: isLogoVisible)
                
                // MARK: - FOOTER: PRIVACY SIGNAL
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                    Text("Secure Offline Environment")
                        .font(.caption)
                }
                .foregroundColor(neonCyan.opacity(0.4))
                .padding(.top, 16)
                .padding(.bottom, 50)
                .opacity(isLogoVisible ? 1.0 : 0.0)
                .animation(.easeOut(duration: 1.0).delay(1.0), value: isLogoVisible)
            }
        }
    }
    
    // MARK: - ROBOTIC BLINK LOGIC
    
    /// Schedules a blink to happen after a random interval (3-4 seconds)
    private func scheduleBlink() {
        blinkTimer?.invalidate()
        
        let randomInterval = Double.random(in: 3.0...4.0)
        
        blinkTimer = Timer.scheduledTimer(withTimeInterval: randomInterval, repeats: false) { _ in
            Task { @MainActor in
                performBlink()
                scheduleBlink()
            }
        }
    }
    
    /// Performs a single open-close-open blink cycle
    private func performBlink() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isBlinking = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.15)) {
                isBlinking = false
            }
        }
    }
}

// MARK: - SUBCOMPONENTS

struct LoadingRing: View {
    @Binding var isAnimating: Bool
    
    var body: some View {
        Circle()
            .trim(from: 0.2, to: 1)
            .stroke(
                LinearGradient(
                    colors: [.cyan, .blue],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: StrokeStyle(
                    lineWidth: 4,
                    lineCap: .round
                )
            )
            .frame(width: 40, height: 40)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .shadow(color: .cyan.opacity(0.8), radius: 8, x: 0, y: 0)
            .animation(
                isAnimating ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                value: isAnimating
            )
    }
}

#Preview {
    IntroView()
}