import SwiftUI

/// Full "System Control Dashboard" — a scrollable, modular settings console
/// with accessibility, sensor, audio/haptic, visual, and data-reset controls.
struct SettingsView: View {
    @Binding var isPresented: Bool
    
    // MARK: - Persisted Settings
    @AppStorage("manualOverride") private var manualOverride: Bool = false
    @AppStorage("neuralSensitivity") private var neuralSensitivity: Double = 1.0
    @AppStorage("audioBGM") private var audioBGM: Bool = true
    @AppStorage("audioSFX") private var audioSFX: Bool = true
    @AppStorage("hapticFeedback") private var hapticFeedback: Bool = true
    @AppStorage("nightmareTheme") private var nightmareTheme: Bool = false
    
    // MARK: - Local State
    @State private var showResetAlert = false
    
    // MARK: - Theme
    private let neonCyan = Color(red: 0.0, green: 0.94, blue: 1.0)
    private let dangerRed = Color(red: 1.0, green: 0.25, blue: 0.25)
    
    var body: some View {
        ZStack {
            
            VStack(spacing: 0) {
                
                // ─── HEADER ───────────────────────────────
                VStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                        .shadow(color: neonCyan.opacity(0.3), radius: 8)
                    
                    Text("SYSTEM SETTINGS")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(3)
                    
                    Text("PILOT CONFIGURATION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(2)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // ─── SCROLLABLE MODULES ───────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // ═══════════════════════════════════
                        // MODULE 1 — ACCESSIBILITY
                        // ═══════════════════════════════════
                        SettingsModuleCard {
                            VStack(alignment: .leading, spacing: 16) {
                                // Header row
                                HStack {
                                    Image(systemName: "hand.tap.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(manualOverride ? neonCyan : .gray)
                                        .shadow(color: manualOverride ? neonCyan.opacity(0.6) : .clear, radius: 6)
                                    
                                    Text("ACCESSIBILITY")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text(manualOverride ? "ACTIVE" : "OFF")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(manualOverride ? .green : .gray)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(manualOverride ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                
                                Text("Enable touch controls (Drag to move, Tap to shoot) for pilots unable to use optical tracking.")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                                    .lineSpacing(3)
                                
                                Toggle(isOn: $manualOverride) {
                                    Text("MANUAL OVERRIDE")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .toggleStyle(SwitchToggleStyle(tint: neonCyan))
                                
                                // Info note (shown when active)
                                if manualOverride {
                                    HStack(spacing: 8) {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundColor(neonCyan)
                                            .font(.system(size: 12))
                                        Text("AR eye tracking will be supplemented by touch. Both inputs work simultaneously.")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: manualOverride)
                        
                        // ═══════════════════════════════════
                        // MODULE 2 — SENSOR CALIBRATION
                        // ═══════════════════════════════════
                        SettingsModuleCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 8) {
                                    Image(systemName: "scope")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(neonCyan)
                                        .shadow(color: neonCyan.opacity(0.5), radius: 4)
                                    
                                    Text("NEURAL LINK SENSITIVITY")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                
                                Text("Adjust optical tracking responsiveness.")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "tortoise.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                    
                                    Slider(value: $neuralSensitivity, in: 0.5...2.0)
                                        .tint(neonCyan)
                                    
                                    Image(systemName: "hare.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(neonCyan)
                                }
                                
                                // Value readout
                                Text("CURRENT: \(Int(neuralSensitivity * 100))%")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(neonCyan.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        
                        // ═══════════════════════════════════
                        // MODULE 3 — TACTICAL FEEDBACK
                        // ═══════════════════════════════════
                        SettingsModuleCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 8) {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.green)
                                        .shadow(color: .green.opacity(0.5), radius: 4)
                                    
                                    Text("AV / HAPTIC SYSTEMS")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                
                                // BGM Toggle
                                SettingsToggleRow(
                                    label: "SYNTHWAVE BGM",
                                    isOn: $audioBGM,
                                    tintColor: neonCyan
                                )
                                
                                // SFX Toggle
                                SettingsToggleRow(
                                    label: "WEAPON TELEMETRY",
                                    isOn: $audioSFX,
                                    tintColor: neonCyan
                                )
                                
                                // Haptic Toggle
                                SettingsToggleRow(
                                    label: "FORCE FEEDBACK",
                                    isOn: $hapticFeedback,
                                    tintColor: .green
                                )
                            }
                        }
                        
                        // ═══════════════════════════════════
                        // MODULE 4 — VISUAL OVERRIDE
                        // ═══════════════════════════════════
                        SettingsModuleCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 8) {
                                    Image(systemName: "eye.trianglebadge.exclamationmark")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(nightmareTheme ? dangerRed : .orange)
                                        .shadow(color: (nightmareTheme ? dangerRed : .orange).opacity(0.5), radius: 4)
                                    
                                    Text("HUD OPTICS")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                
                                Text("Engage deep-red biohazard UI for high-intensity missions.")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                    .lineSpacing(2)
                                
                                Toggle(isOn: $nightmareTheme) {
                                    Text("NIGHTMARE PROTOCOL")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .toggleStyle(SwitchToggleStyle(tint: dangerRed))
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: nightmareTheme)
                        
                        // ═══════════════════════════════════
                        // MODULE 5 — DANGER ZONE
                        // ═══════════════════════════════════
                        VStack(spacing: 0) {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                showResetAlert = true
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("PURGE NEURAL DATA")
                                        .font(.system(size: 14, weight: .black, design: .monospaced))
                                        .tracking(1)
                                }
                                .foregroundColor(dangerRed)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(dangerRed.opacity(0.08))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(dangerRed.opacity(0.4), lineWidth: 1)
                                )
                            }
                        }
                        
                        // Bottom spacer for scroll breathing room
                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                }
                
                // ─── CLOSE BUTTON ─────────────────────────
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        isPresented = false
                    }
                }) {
                    Text("CLOSE SETTINGS")
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
                .padding(.top, 12)
                .padding(.bottom, 50)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .alert("⚠️ PURGE NEURAL DATA", isPresented: $showResetAlert) {
            Button("CANCEL", role: .cancel) {}
            Button("PURGE", role: .destructive) {
                // Reset all gamification data
                UserDefaults.standard.removeObject(forKey: "playerLevel")
                UserDefaults.standard.removeObject(forKey: "playerXP")
                UserDefaults.standard.removeObject(forKey: "userStreak")
                UserDefaults.standard.removeObject(forKey: "totalSessionsToday")
                UserDefaults.standard.removeObject(forKey: "mission_distance_500_progress")
                UserDefaults.standard.removeObject(forKey: "mission_kills_10_progress")
                UserDefaults.standard.removeObject(forKey: "mission_kills_50_progress")
                UserDefaults.standard.removeObject(forKey: "mission_survive_30_progress")
                UserDefaults.standard.removeObject(forKey: "mission_survive_60_progress")
                UserDefaults.standard.removeObject(forKey: "mission_distance_2000_progress")
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        } message: {
            Text("This will permanently erase your Pilot Level, XP, streak, and active Bounties. This cannot be undone.")
        }
    }
}

// MARK: - Reusable Module Card Container

/// Glassmorphic card wrapper used by every settings module
struct SettingsModuleCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(Color.white.opacity(0.04))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Reusable Toggle Row

/// Compact toggle row with monospaced label and colored tint
struct SettingsToggleRow: View {
    let label: String
    @Binding var isOn: Bool
    let tintColor: Color
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .toggleStyle(SwitchToggleStyle(tint: tintColor))
    }
}

#Preview {
    SettingsView(isPresented: .constant(true))
}
