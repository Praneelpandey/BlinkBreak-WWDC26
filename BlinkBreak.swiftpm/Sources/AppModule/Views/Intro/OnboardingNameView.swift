import SwiftUI

// MARK: - Pilot Avatar Model

struct PilotAvatar: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    let primaryColor: Color
    let secondaryColor: Color
    
    static let allAvatars: [PilotAvatar] = [
        PilotAvatar(
            id: "vanguard",
            name: "VANGUARD",
            icon: "shield.checkered",
            primaryColor: Color(red: 0.0, green: 0.94, blue: 1.0),   // Cyan
            secondaryColor: Color(red: 0.0, green: 0.4, blue: 1.0)
        ),
        PilotAvatar(
            id: "striker",
            name: "STRIKER",
            icon: "bolt.shield.fill",
            primaryColor: Color(red: 1.0, green: 0.3, blue: 0.3),   // Red
            secondaryColor: Color(red: 0.8, green: 0.1, blue: 0.4)
        ),
        PilotAvatar(
            id: "recon",
            name: "RECON",
            icon: "eye.trianglebadge.exclamationmark",
            primaryColor: Color(red: 0.0, green: 1.0, blue: 0.5),   // Green
            secondaryColor: Color(red: 0.0, green: 0.7, blue: 0.3)
        ),
        PilotAvatar(
            id: "phantom",
            name: "PHANTOM",
            icon: "moon.stars.fill",
            primaryColor: Color(red: 0.7, green: 0.3, blue: 1.0),   // Purple
            secondaryColor: Color(red: 0.4, green: 0.1, blue: 0.8)
        ),
        PilotAvatar(
            id: "nova",
            name: "NOVA",
            icon: "sparkles",
            primaryColor: Color(red: 1.0, green: 0.8, blue: 0.0),   // Gold
            secondaryColor: Color(red: 1.0, green: 0.5, blue: 0.0)
        ),
        PilotAvatar(
            id: "wraith",
            name: "WRAITH",
            icon: "hurricane",
            primaryColor: Color(red: 1.0, green: 0.4, blue: 0.7),   // Pink
            secondaryColor: Color(red: 0.8, green: 0.1, blue: 0.5)
        ),
    ]
}

// MARK: - Onboarding Name View

struct OnboardingNameView: View {
    @AppStorage("pilotNickname") private var pilotNickname: String = ""
    @AppStorage("pilotAvatar") private var pilotAvatar: String = "vanguard"
    
    @State private var enteredName: String = ""
    
    var onConfirm: () -> Void
    
    // Animation states
    @State private var isAnimating = false
    
    private var selectedAvatar: PilotAvatar {
        PilotAvatar.allAvatars.first { $0.id == pilotAvatar } ?? PilotAvatar.allAvatars[0]
    }
    
    var body: some View {
        ZStack {
            
            VStack(spacing: 40) {
                Spacer()
                
                titleSection
                avatarSelectionSection
                textInputSection
                
                Spacer()
                
                confirmButton
            }
        }
        .background(animatedBackground)
    }
    
    // MARK: - Subviews
    
    private var animatedBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ZStack {
                Circle()
                    .fill(selectedAvatar.primaryColor.opacity(0.12))
                    .frame(width: 300)
                    .blur(radius: isAnimating ? 80 : 40)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .offset(y: isAnimating ? -20 : 20)
                
                Path { path in
                    for i in 0..<10 {
                        path.move(to: CGPoint(x: 0, y: i * 100))
                        path.addLine(to: CGPoint(x: 1000, y: i * 100))
                    }
                }
                .stroke(Color.white.opacity(0.02), lineWidth: 1)
            }
            .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
        }
    }
    
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("IDENTIFY YOURSELF, PILOT")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: selectedAvatar.primaryColor.opacity(0.8), radius: 10)
            
            Text("SYSTEM REGISTRATION")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.gray)
                .tracking(4)
        }
    }
    
    private var avatarSelectionSection: some View {
        VStack(spacing: 16) {
            Text("SELECT NEURAL LINK AVATAR")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(selectedAvatar.primaryColor)
                .tracking(2)
                .shadow(color: selectedAvatar.primaryColor.opacity(0.5), radius: 5)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(PilotAvatar.allAvatars) { avatar in
                        avatarButton(for: avatar)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 10)
            }
            
            // Selected role label
            Text(selectedAvatar.name)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(selectedAvatar.primaryColor)
                .tracking(3)
                .shadow(color: selectedAvatar.primaryColor.opacity(0.6), radius: 4)
                .animation(.easeInOut(duration: 0.2), value: pilotAvatar)
        }
    }
    
    private func avatarButton(for avatar: PilotAvatar) -> some View {
        let isActive = pilotAvatar == avatar.id
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                pilotAvatar = avatar.id
                HapticManager.shared.playSelectionHaptic()
            }
        }) {
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                avatar.primaryColor.opacity(isActive ? 0.25 : 0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 40
                        )
                    )
                    .frame(width: 78, height: 78)
                
                // Background circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                avatar.primaryColor.opacity(isActive ? 0.25 : 0.08),
                                avatar.secondaryColor.opacity(isActive ? 0.15 : 0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                
                // Icon
                Image(systemName: avatar.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isActive ? avatar.primaryColor : avatar.primaryColor.opacity(0.4))
                    .shadow(color: isActive ? avatar.primaryColor.opacity(0.8) : .clear, radius: 8)
                
                // Border ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                avatar.primaryColor.opacity(isActive ? 1.0 : 0.2),
                                avatar.secondaryColor.opacity(isActive ? 0.8 : 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isActive ? 2.5 : 1
                    )
                    .frame(width: 64, height: 64)
            }
            .scaleEffect(isActive ? 1.15 : 1.0)
            .shadow(color: isActive ? avatar.primaryColor.opacity(0.5) : .clear, radius: 12)
        }
        .buttonStyle(.plain)
    }
    
    private var textInputSection: some View {
        VStack(spacing: 8) {
            TextField("Enter Callsign...", text: Binding(
                get: { enteredName },
                set: { enteredName = $0.uppercased() }
            ))
            .font(.system(.title3, design: .monospaced))
            .foregroundColor(.white)
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        enteredName.isEmpty
                            ? Color.white.opacity(0.2)
                            : selectedAvatar.primaryColor,
                        lineWidth: enteredName.isEmpty ? 1 : 2
                    )
                    .shadow(color: enteredName.isEmpty ? .clear : selectedAvatar.primaryColor.opacity(0.5), radius: 5)
            )
            .padding(.horizontal, 40)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.characters)
        }
    }
    
    private var confirmButton: some View {
        Button(action: {
            guard !enteredName.isEmpty else { return }
            
            HapticManager.shared.playImpactHaptic(style: .heavy)
            pilotNickname = enteredName
            
            onConfirm()
        }) {
            Text("CONFIRM IDENTITY")
                .font(.headline)
                .fontWeight(.bold)
                .tracking(1)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: [selectedAvatar.primaryColor, selectedAvatar.secondaryColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: enteredName.isEmpty ? .clear : selectedAvatar.primaryColor.opacity(isAnimating ? 0.8 : 0.4), radius: isAnimating ? 15 : 8, x: 0, y: 0)
        }
        .disabled(enteredName.trimmingCharacters(in: .whitespaces).isEmpty)
        .opacity(enteredName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1.0)
        .padding(.horizontal, 40)
        .padding(.bottom, 50)
    }
}

#Preview {
    OnboardingNameView(onConfirm: {})
}

