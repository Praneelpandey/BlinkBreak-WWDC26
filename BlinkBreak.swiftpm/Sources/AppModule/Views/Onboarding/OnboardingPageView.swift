import SwiftUI

/// Individual onboarding page component with consistent styling
struct OnboardingPageView: View {
    let title: String
    let subtitle: String
    let description: String
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 30) {
            // Icon with soft glow effect
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.2).opacity(0.8),
                            Color(red: 0.15, green: 0.15, blue: 0.25).opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 140, height: 140)
                    .shadow(color: Color(red: 0.0, green: 0.8, blue: 0.4).opacity(0.2), radius: 20, x: 0, y: 10)
                
                Image(systemName: systemImage)
                    .font(.system(size: 60, weight: .regular))
                    .foregroundColor(Color(red: 0.0, green: 0.8, blue: 0.4))
                    .shadow(color: Color(red: 0.0, green: 0.8, blue: 0.4).opacity(0.5), radius: 10, x: 0, y: 5)
            }
            .padding(.top, 60)
            
            // Title with soft glow
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .shadow(color: Color(red: 0.0, green: 0.8, blue: 0.4).opacity(0.2), radius: 5, x: 0, y: 2)
            
            // Subtitle
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundColor(Color(red: 0.4, green: 0.8, blue: 0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Description
            Text(description)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.08, green: 0.08, blue: 0.18)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

#Preview {
    OnboardingPageView(
        title: "Welcome",
        subtitle: "",
        description: "This is a sample description for the onboarding screen.",
        systemImage: "eye.fill"
    )
}