import SwiftUI

/// Main content view that handles onboarding flow
struct MainAppView: View {
    @State private var showOnboarding = false
    @State private var showHangar = false
    @State private var showCalibration = false
    @State private var showGame = false
    @State private var showTutorial = false
    
    init(startAtHangar: Bool = false) {
        _showHangar = State(initialValue: startAtHangar)
    }
    
    var body: some View {
        ZStack {
            // Background persistence if needed, or black background
            
            Group {
                if showGame {
                    GameView(showGame: $showGame, showHangar: $showHangar)
                        .transition(.opacity)
                } else if showTutorial {
                    GameTutorialView(showTutorial: $showTutorial, showGame: $showGame)
                        .transition(.opacity)
                } else if showCalibration {
                    CalibrationView(
                        showCalibration: $showCalibration,
                        showTutorial: $showTutorial,
                        showOnboarding: $showOnboarding,
                        showHangar: $showHangar
                    )
                    .transition(.opacity.combined(with: .scale(scale: 1.1)))
                } else if showHangar {
                    HangarView(
                        showHangar: $showHangar,
                        showCalibration: $showCalibration
                    )
                    .transition(.opacity)
                } else if showOnboarding {
                    OnboardingView(
                        showOnboarding: $showOnboarding,
                        showHangar: $showHangar
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                } else {
                    IntroView()
                    .transition(.opacity)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.5), value: showGame)
        .animation(.easeInOut(duration: 0.5), value: showTutorial)
        .animation(.easeInOut(duration: 0.5), value: showCalibration)
        .animation(.easeInOut(duration: 0.5), value: showHangar)
        .animation(.easeInOut(duration: 0.5), value: showOnboarding)
    }
}

#Preview {
    MainAppView()
}

struct ContentView: View {
    var body: some View {
        MainAppView()
    }
}

#Preview {
    ContentView()
}