import SwiftUI

// MARK: - Friend Challenge View

struct FriendChallengeView: View {
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("playerLevel") private var playerLevel: Int = 1
    @AppStorage("userStreak") private var userStreak: Int = 0
    
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    private let neonGreen = Color(red: 0.0, green: 1.0, blue: 0.6)
    
    // Mock friend data (privacy-friendly, no real networking)
    private let friends: [MockPilot] = [
        MockPilot(name: "ARJUN", callsign: "THUNDERBOLT", level: 15, streak: 5, bestScore: 780, avatar: "bolt.shield.fill"),
        MockPilot(name: "SARAH", callsign: "NOVA", level: 18, streak: 12, bestScore: 1240, avatar: "star.fill"),
        MockPilot(name: "KENJI", callsign: "PHANTOM", level: 10, streak: 2, bestScore: 420, avatar: "eye.fill"),
        MockPilot(name: "LILA", callsign: "VIPER", level: 22, streak: 21, bestScore: 2100, avatar: "flame.fill"),
    ]
    
    var body: some View {
        ZStack {
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FRIEND CHALLENGES")
                                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                                .foregroundColor(.white)
                                .tracking(2)
                            Text("COMPETE · COMPARE · CONQUER")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(neonCyan.opacity(0.6))
                                .tracking(1)
                        }
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Your Stats Card
                    VStack(spacing: 8) {
                        Text("YOUR PROFILE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                            .tracking(2)
                        
                        HStack(spacing: 20) {
                            StatBubble(label: "LEVEL", value: "\(playerLevel)", color: neonCyan)
                            StatBubble(label: "STREAK", value: "\(userStreak)d", color: .orange)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(neonCyan.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Challenge Cards
                    ForEach(friends) { friend in
                        ChallengeCard(
                            friend: friend,
                            playerStreak: userStreak,
                            playerLevel: playerLevel
                        )
                    }
                    .padding(.horizontal)
                    
                    // Privacy Notice
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 10))
                            .foregroundColor(neonGreen.opacity(0.6))
                        Text("No tracking · No chat · Stats only")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .background(Color(red: 0.03, green: 0.03, blue: 0.08).ignoresSafeArea())
    }
}

// MARK: - Mock Pilot Model

struct MockPilot: Identifiable {
    let id = UUID()
    let name: String
    let callsign: String
    let level: Int
    let streak: Int
    let bestScore: Int
    let avatar: String
}

// MARK: - Challenge Card

struct ChallengeCard: View {
    let friend: MockPilot
    let playerStreak: Int
    let playerLevel: Int
    
    @State private var isExpanded = false
    
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    private var challengeText: String {
        if friend.streak > playerStreak {
            return "Beat \(friend.name)'s \(friend.streak)-day streak!"
        } else if friend.level > playerLevel {
            return "Reach \(friend.name)'s Level \(friend.level)!"
        } else {
            return "Outscore \(friend.name)'s \(friend.bestScore)m best!"
        }
    }
    
    private var isAhead: Bool {
        playerStreak >= friend.streak && playerLevel >= friend.level
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(neonCyan.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: friend.avatar)
                        .foregroundColor(neonCyan)
                        .font(.system(size: 18))
                }
                
                // Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(friend.callsign)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        if isAhead {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        }
                    }
                    
                    Text(challengeText)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                // Level Badge
                VStack(spacing: 2) {
                    Text("LVL")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("\(friend.level)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            
            // Stats Row
            HStack(spacing: 12) {
                MiniStat(icon: "flame.fill", value: "\(friend.streak)d", color: .orange)
                MiniStat(icon: "location.fill", value: "\(friend.bestScore)m", color: neonCyan)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isAhead ? Color.green.opacity(0.3) : neonCyan.opacity(0.15),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Helper Views

struct StatBubble: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.4), radius: 4)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.06))
        .cornerRadius(10)
    }
}

struct MiniStat: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .cornerRadius(6)
    }
}
