import SwiftUI

// MARK: - Core Modular UI

/// Next-gen interface for equipping specific unlocked parts to a Ship chassis.
struct ShipyardModulesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var unlockManager = UnlockManager.shared
    
    // UI State
    @State private var selectedCategory: PartCategory = .hull
    @State private var bounceTrigger = false
    @State private var previewPartIDs: [PartCategory: String] = [:]
    
    @AppStorage("equippedHull") private var equippedHullRaw: String = ShipType.dart.rawValue
    @State private var previewHull: ShipType? = nil
    
    // Aesthetic Tokens
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    private let deepSpaceBlack = Color(red: 0.05, green: 0.05, blue: 0.1)
    
    var body: some View {
        ZStack {
            deepSpaceBlack.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("MODULAR SHIPYARD")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(3)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(24)
                
                // Active Preview Space
                ZStack {
                    RadialGradient(
                        colors: [neonCyan.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 180
                    )
                    
                    // Uses the modified composites from CustomShipModels
                    LiveShipPreviewComposite(bounce: bounceTrigger, previewOverrides: previewPartIDs, previewHull: previewHull)
                    
                    // Revert Preview UI
                    let hasPartPreviews = !previewPartIDs.isEmpty
                    let hasHullPreview = previewHull != nil && previewHull?.rawValue != equippedHullRaw
                    if hasPartPreviews || hasHullPreview {
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: resetPreview) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.uturn.backward")
                                        Text("REVERT PREVIEW")
                                    }
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(neonCyan)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(neonCyan.opacity(0.5), lineWidth: 1))
                                    .shadow(color: neonCyan.opacity(0.3), radius: 4)
                                }
                                .padding(16)
                            }
                            Spacer()
                        }
                        .transition(.opacity)
                    }
                }
                .frame(height: 300)
                .background(Color.white.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.05), lineWidth: 1))
                .padding(.horizontal, 20)
                
                // Category Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(PartCategory.allCases, id: \.self) { category in
                            CategoryTab(
                                category: category,
                                isSelected: selectedCategory == category,
                                onSelect: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        selectedCategory = category
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
                
                // Parts List
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        if selectedCategory == .hull {
                            ForEach(ShipType.allCases) { ship in
                                let isEquipped = ship.rawValue == equippedHullRaw
                                let isUnlocked = ship == .dart || unlockManager.unlockedParts.contains(ship.rawValue)
                                let isPreviewed = previewHull == ship
                                
                                HullRowCard(
                                    ship: ship,
                                    isEquipped: isEquipped,
                                    isUnlocked: isUnlocked,
                                    isPreviewed: isPreviewed,
                                    onSelect: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            previewHull = ship
                                        }
                                        bouncePreview()
                                    },
                                    onEquip: {
                                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                        equippedHullRaw = ship.rawValue
                                        withAnimation {
                                            previewHull = nil
                                        }
                                        bouncePreview()
                                    }
                                )
                            }
                        } else {
                            ForEach(filteredParts, id: \.id) { part in
                                let isEquipped = unlockManager.isEquipped(partID: part.id)
                                let isUnlocked = unlockManager.isUnlocked(partID: part.id)
                                let isPreviewed = previewPartIDs[part.category] == part.id
                                
                                PartRowCard(
                                    part: part,
                                    isEquipped: isEquipped,
                                    isUnlocked: isUnlocked,
                                    isPreviewed: isPreviewed,
                                    onSelect: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            previewPartIDs[part.category] = part.id
                                        }
                                        bouncePreview()
                                    },
                                    onEquip: {
                                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                        unlockManager.equip(partID: part.id)
                                        withAnimation {
                                            _ = previewPartIDs.removeValue(forKey: part.category)
                                        }
                                        bouncePreview()
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onDisappear {
            previewPartIDs.removeAll()
            previewHull = nil
        }
    }
    
    // MARK: - Helpers
    
    private var filteredParts: [ShipPart] {
        unlockManager.registry.filter { $0.category == selectedCategory }
    }
    
    private func bouncePreview() {
        bounceTrigger = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            bounceTrigger = true
        }
    }
    
    private func resetPreview() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeInOut(duration: 0.3)) {
            previewPartIDs.removeAll()
            previewHull = nil
        }
        bouncePreview()
    }
}

// MARK: - Subcomponents

struct CategoryTab: View {
    let category: PartCategory
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            Text(category.rawValue)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(isSelected ? .black : .white.opacity(0.5))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isSelected ? Color(red: 0.0, green: 0.94, blue: 1.0) : Color.white.opacity(0.05))
                .clipShape(Capsule())
                .shadow(color: isSelected ? Color(red: 0.0, green: 0.94, blue: 1.0).opacity(0.6) : .clear, radius: 8)
        }
    }
}

struct PartRowCard: View {
    let part: ShipPart
    let isEquipped: Bool
    let isUnlocked: Bool
    let isPreviewed: Bool
    let onSelect: () -> Void
    let onEquip: () -> Void
    
    private let lockRed = Color(red: 1.0, green: 0.2, blue: 0.2)
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon Box
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isUnlocked ? neonCyan.opacity(0.1) : lockRed.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                if isUnlocked {
                    Image(systemName: part.icon)
                        .font(.system(size: 20))
                        .foregroundColor(neonCyan)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20))
                        .foregroundColor(lockRed)
                }
            }
            
            // Text Column
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(part.name.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(isUnlocked ? .white : .white.opacity(0.4))
                    
                    if isEquipped {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(neonCyan)
                            .font(.system(size: 12))
                    }
                }
                
                Text(part.description)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(isUnlocked ? .gray : lockRed.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Action State
            if isEquipped {
                Text("EQUIPPED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(neonCyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(neonCyan.opacity(0.15))
                    .clipShape(Capsule())
            } else if !isUnlocked {
                Text("LOCKED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(lockRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(lockRed.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                Button(action: onEquip) {
                    Text("EQUIP")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(isPreviewed ? neonCyan.opacity(0.08) : Color.white.opacity(0.03))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isEquipped ? neonCyan.opacity(0.5) : (isPreviewed ? neonCyan.opacity(0.8) : (isUnlocked ? Color.white.opacity(0.05) : lockRed.opacity(0.2))),
                    lineWidth: isEquipped || isPreviewed ? 2 : 1
                )
        )
        .shadow(color: isPreviewed ? neonCyan.opacity(0.2) : .clear, radius: 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

struct HullRowCard: View {
    let ship: ShipType
    let isEquipped: Bool
    let isUnlocked: Bool
    let isPreviewed: Bool
    let onSelect: () -> Void
    let onEquip: () -> Void
    
    private let lockRed = Color(red: 1.0, green: 0.2, blue: 0.2)
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon Box
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isUnlocked ? neonCyan.opacity(0.1) : lockRed.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                ShipRenderView(
                    shipType: ship,
                    color: isUnlocked ? neonCyan : lockRed,
                    size: 30
                )
            }
            
            // Text Column
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(ship.displayName.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(isUnlocked ? .white : .white.opacity(0.4))
                    
                    if isEquipped {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(neonCyan)
                            .font(.system(size: 12))
                    }
                }
                
                Text(ship.tier.uppercased() + " CLASS")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(isUnlocked ? .gray : lockRed.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Action State
            if isEquipped {
                Text("EQUIPPED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(neonCyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(neonCyan.opacity(0.15))
                    .clipShape(Capsule())
            } else if !isUnlocked {
                Text("LOCKED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(lockRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(lockRed.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                Button(action: onEquip) {
                    Text("EQUIP")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(isPreviewed ? neonCyan.opacity(0.08) : Color.white.opacity(0.03))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isEquipped ? neonCyan.opacity(0.5) : (isPreviewed ? neonCyan.opacity(0.8) : (isUnlocked ? Color.white.opacity(0.05) : lockRed.opacity(0.2))),
                    lineWidth: isEquipped || isPreviewed ? 2 : 1
                )
        )
        .shadow(color: isPreviewed ? neonCyan.opacity(0.2) : .clear, radius: 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

