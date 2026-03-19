import SwiftUI

struct Star: Identifiable {
    let id: UUID
    let angle: Double
    let distance: CGFloat
    let delay: Double
    let length: CGFloat
}

struct WarpTransitionView: View {
    var onComplete: () -> Void
    
    @State private var stars: [Star] = (0..<60).map { _ in
        Star(
            id: UUID(),
            angle: Double.random(in: 0...360),
            distance: CGFloat.random(in: 400...1000),
            delay: Double.random(in: 0...1.0),
            length: CGFloat.random(in: 20...100)
        )
    }
    
    @State private var isAnimating = false
    @State private var flashOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.3
    
    @State private var hasCompleted = false
    
    var body: some View {
        ZStack {
            
            GeometryReader { geometry in
                ZStack {
                    ForEach(stars) { star in
                        let radians = star.angle * .pi / 180
                        
                        let xOffset = cos(radians) * star.distance
                        let yOffset = sin(radians) * star.distance
                        
                        Capsule()
                            .fill(Color.white)
                            .frame(width: star.length, height: 2)
                            .rotationEffect(.degrees(star.angle))
                            .scaleEffect(isAnimating ? 1.5 : 0)
                            .opacity(isAnimating ? 1.0 : 0.0)
                            .offset(
                                x: isAnimating ? xOffset : 0,
                                y: isAnimating ? yOffset : 0
                            )
                            .animation(
                                .linear(duration: 0.6)
                                .repeatForever(autoreverses: false)
                                .delay(star.delay),
                                value: isAnimating
                            )
                    }
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            
            VStack {
                Spacer()
                Text("ENTERING HYPERSPACE...")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.0, green: 0.94, blue: 1.0))
                    .shadow(color: Color(red: 0.0, green: 0.94, blue: 1.0).opacity(0.8), radius: 5)
                    .opacity(textOpacity)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: textOpacity)
                    .padding(.bottom, 60)
            }
            
        }
        .background(Color.black.ignoresSafeArea())
        .overlay(
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
        .onAppear {
            isAnimating = true
            textOpacity = 1.0
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
                guard !hasCompleted else { return }
                withAnimation(.easeIn(duration: 0.3)) {
                    flashOpacity = 1.0
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                guard !hasCompleted else { return }
                hasCompleted = true
                onComplete()
            }
        }
        .onDisappear {
            hasCompleted = true
        }
    }
}
