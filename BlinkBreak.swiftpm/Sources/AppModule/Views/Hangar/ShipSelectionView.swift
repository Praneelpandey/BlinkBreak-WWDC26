import SwiftUI

/// Shipyard — grid of custom vector ships with persistent selection.
struct ShipSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedShipType") private var selectedShipType: String = ShipType.dart.rawValue
    
    // MARK: - Theme
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    private let accentGold = Color(red: 1.0, green: 0.84, blue: 0.0)
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            
            VStack(spacing: 24) {
                
                // ─── Header ───────────────────────────
                VStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 28))
                        .foregroundColor(accentGold)
                        .shadow(color: accentGold.opacity(0.6), radius: 8)
                    
                    Text("SHIPYARD PROTOCOL")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(3)
                        .shadow(color: neonCyan.opacity(0.3), radius: 6)
                    
                    Text("SELECT YOUR VESSEL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(2)
                }
                .padding(.top, 40)
                
                // ─── Ship Grid ────────────────────────
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(ShipType.allCases) { shipType in
                            let isSelected = shipType.rawValue == selectedShipType
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                selectedShipType = shipType.rawValue
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    dismiss()
                                }
                            }) {
                                VStack(spacing: 10) {
                                    // Custom vector ship
                                    ShipRenderView(
                                        shipType: shipType,
                                        color: isSelected ? .white : .white.opacity(0.35),
                                        size: 60
                                    )
                                    .shadow(color: isSelected ? neonCyan.opacity(0.8) : .clear, radius: 10)
                                    
                                    // Ship name
                                    Text(shipType.displayName)
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                                    
                                    // Tier badge
                                    Text(shipType.tier)
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundColor(isSelected ? accentGold : .gray)
                                        .tracking(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(isSelected ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            isSelected
                                                ? LinearGradient(colors: [neonCyan, accentGold], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                : LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                            lineWidth: isSelected ? 1.5 : 1
                                        )
                                )
                                .shadow(color: isSelected ? neonCyan.opacity(0.3) : .clear, radius: 8)
                                .animation(.easeInOut(duration: 0.2), value: isSelected)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // ─── Close Button ─────────────────────
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                }) {
                    Text("CLOSE SHIPYARD")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    ShipSelectionView()
}
