import SwiftUI

struct AchievementsView: View {
    @StateObject private var progressManager = ProgressManager.shared
    @Environment(\.dismiss) var dismiss
    
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Background Grid
            VStack(spacing: 0) {
                ForEach(0..<10) { _ in
                    HStack(spacing: 0) {
                        ForEach(0..<6) { _ in
                            Rectangle()
                                .stroke(Color.white.opacity(0.02), lineWidth: 1)
                                .frame(width: UIScreen.main.bounds.width / 6, height: UIScreen.main.bounds.width / 6)
                        }
                    }
                }
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        HapticManager.shared.playSelectionHaptic()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(neonCyan)
                    }
                    
                    Spacer()
                    
                    Text("COMMENDATIONS")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(3)
                        .shadow(color: neonCyan.opacity(0.5), radius: 10)
                    
                    Spacer()
                    
                    // Invisible spacer for balance
                    Image(systemName: "chevron.left").opacity(0)
                        .font(.system(size: 20))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(Color.black.opacity(0.8))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(neonCyan.opacity(0.3)),
                    alignment: .bottom
                )
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(progressManager.achievements) { achievement in
                            AchievementCard(achievement: achievement)
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 60)
                }
            }
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? neonCyan.opacity(0.15) : Color.white.opacity(0.05))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle().stroke(achievement.isUnlocked ? neonCyan : Color.white.opacity(0.2), lineWidth: achievement.isUnlocked ? 2 : 1)
                    )
                
                Image(systemName: achievement.isUnlocked ? "star.circle.fill" : "lock.fill")
                    .font(.system(size: 30))
                    .foregroundColor(achievement.isUnlocked ? neonCyan : Color.white.opacity(0.3))
                    .shadow(color: achievement.isUnlocked ? neonCyan.opacity(0.8) : .clear, radius: 10)
            }
            
            VStack(spacing: 4) {
                Text(achievement.name.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(achievement.isUnlocked ? .white : .white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                
                Text(achievement.description)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            if achievement.isUnlocked, let date = achievement.unlockDate {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(neonCyan.opacity(0.8))
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .shadow(color: achievement.isUnlocked ? neonCyan.opacity(0.1) : .clear, radius: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(achievement.isUnlocked ? neonCyan.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
