import SwiftUI

enum AppScreen {
    case onboarding
    case warping
    case hangar
}

struct RootContentView: View {
    @AppStorage("pilotNickname") private var savedName: String = ""
    @State private var currentScreen: AppScreen = .onboarding
    
    @Binding var showHangar: Bool
    @Binding var showCalibration: Bool
    
    var body: some View {
        ZStack {
            switch currentScreen {
            case .onboarding:
                OnboardingNameView(onConfirm: {
                    currentScreen = .warping
                })
            case .warping:
                WarpTransitionView(onComplete: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentScreen = .hangar
                    }
                })
            case .hangar:
                HangarView(
                    showHangar: $showHangar,
                    showCalibration: $showCalibration
                )
            }
        }
        .onAppear {
            if !savedName.isEmpty {
                currentScreen = .hangar
            }
        }
    }
}
