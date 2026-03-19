import SwiftUI

@main
struct BlinkBreakApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("pilotNickname") private var pilotNickname: String = ""
    
    // Live Service State
    @StateObject private var bountyManager = BountyManager()
    
    // MARK: - App Flows
    @State private var isShowingIntro = true
    
    // Navigation State (Lifted from MainAppView)
    @State private var showOnboarding = false
    @State private var showHangar = false
    @State private var showCalibration = false
    @State private var showGame = false
    @State private var showTutorial = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                
                if isShowingIntro {
                     IntroView()
                     .transition(.opacity)
                     .zIndex(10) // Ensure on top
                } else {
                    // Main Routing Logic
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
                             RootContentView(
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
                         }
                    }
                    .transition(.opacity)
                }
            }
            .environmentObject(bountyManager)
            .background(Color.black.ignoresSafeArea())
            .animation(.easeOut(duration: 0.8), value: isShowingIntro)
            .animation(.easeInOut(duration: 0.5), value: showGame)
            .animation(.easeInOut(duration: 0.5), value: showTutorial)
            .animation(.easeInOut(duration: 0.5), value: showCalibration)
            .animation(.easeInOut(duration: 0.5), value: showHangar)
            .animation(.easeInOut(duration: 0.5), value: showOnboarding)
            .onAppear {
                // Force intro -> Wait -> Decision
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        isShowingIntro = false
                        
                        if hasCompletedOnboarding {
                            showHangar = true
                        } else {
                            showOnboarding = true
                        }
                    }
                }
            }
        }
    }
}
