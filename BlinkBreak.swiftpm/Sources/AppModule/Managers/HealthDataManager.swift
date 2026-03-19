import Foundation
import Combine
import SwiftUI

// MARK: - WeeklyStats Model

/// Contains aggregated eye health data for a specific 7-day period.
struct WeeklyStats: Codable, Identifiable {
    var id: UUID = UUID()
    let weekStartDate: Date
    var totalSessions: Int
    var totalBlinks: Int
    var totalFocusSeconds: Double
    var totalBreakSeconds: Double
    var strainReductionPercent: Int
    
    // Default empty week
    static func empty(for date: Date) -> WeeklyStats {
        WeeklyStats(
            weekStartDate: date.startOfWeek,
            totalSessions: 0,
            totalBlinks: 0,
            totalFocusSeconds: 0,
            totalBreakSeconds: 0,
            strainReductionPercent: 0
        )
    }
    
    var blinksPerMinute: Double {
        guard totalFocusSeconds > 0 else { return 0 }
        return Double(totalBlinks) / (totalFocusSeconds / 60.0)
    }
}

// MARK: - Health Sequence File
struct HealthArchive: Codable {
    var history: [WeeklyStats]
    var currentWeek: WeeklyStats
}

// MARK: - Daily Stat (per-day granularity for bar charts)

/// A single day's aggregated stats — used to power the Pilot Dossier bar charts.
struct DailyStat: Codable, Identifiable {
    var id: String { dateKey } // e.g. "2026-02-26"
    let dateKey: String
    var sessions: Int = 0
    var kills: Int = 0
    var focusSeconds: Double = 0
    var shots: Int = 0
    var hits: Int = 0
    
    /// Day-of-week index (1=Sun...7=Sat) for chart ordering
    var weekdayIndex: Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateKey) else { return 1 }
        return Calendar.current.component(.weekday, from: date)
    }
    
    /// Short day label
    var dayLabel: String {
        let labels = ["", "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        return labels[weekdayIndex]
    }
}

// MARK: - HealthDataManager

/// Robust local persistence manager for archiving weekly mission telemetry.
/// Offline-first, Privacy-first. Saves data to a JSON blob in the app's Document Directory.
@MainActor
class HealthDataManager: ObservableObject {
    static let shared = HealthDataManager()
    
    @Published var currentWeek: WeeklyStats
    @Published var history: [WeeklyStats] = []
    @Published var dailyStats: [DailyStat] = []
    
    private let archiveURL: URL
    private let dailyURL: URL
    
    private init() {
        // Set up local file URLs
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.archiveURL = documents.appendingPathComponent("NeuralVisionArchive.json")
        self.dailyURL = documents.appendingPathComponent("DailyStatsArchive.json")
        
        let now = Date()
        self.currentWeek = WeeklyStats.empty(for: now)
        
        loadArchive()
        loadDailyStats()
        validateWeekBoundary()
        pruneOldDailyStats()
    }
    
    // MARK: - Ingestion
    
    /// Called directly by GameView after a session to funnel raw telemetry into the health archive.
    func reportSession(blinks: Int, focusSeconds: Double, activeBreakSeconds: Double) {
        validateWeekBoundary()
        
        currentWeek.totalSessions += 1
        currentWeek.totalBlinks += blinks
        currentWeek.totalFocusSeconds += focusSeconds
        currentWeek.totalBreakSeconds += activeBreakSeconds
        
        // Strain reduction is a gamified metric. Base formula:
        // Ideal blink rate is ~15 BPM. Every session dragging the average closer to 15 reduces strain.
        // We cap it at 100%.
        let currentBPM = currentWeek.blinksPerMinute
        let optimalBPM = 15.0
        
        if currentBPM > 0 {
            let ratio = min(currentBPM / optimalBPM, 1.0)
            // Base reduction (up to 80%) + Bonus for taking actual Boss breaks (up to 20%).
            let baseReduction = Int(ratio * 80.0)
            let breakBonus = currentWeek.totalBreakSeconds > 20 ? 20 : Int(min(currentWeek.totalBreakSeconds, 20.0))
            
            currentWeek.strainReductionPercent = min(baseReduction + breakBonus, 100)
        }
        
        saveArchive()
        
        // Trigger generic ship unlock checks upon updated data
        UnlockManager.shared.checkForUnlocks()
    }
    
    // MARK: - Boundaries
    
    /// Checks if the ongoing week has rolled over into a new 7-day period.
    /// If so, archives the current active week and spins up a fresh struct.
    private func validateWeekBoundary() {
        let now = Date()
        let currentStart = currentWeek.weekStartDate
        
        if now.startOfWeek > currentStart {
            // Week has rolled over! Archive it if it has data.
            if currentWeek.totalSessions > 0 {
                history.append(currentWeek)
                // Cap history to 8 weeks for lightweight persistence overhead.
                if history.count > 8 {
                    history.removeFirst(history.count - 8)
                }
            }
            // Reset to empty week
            currentWeek = WeeklyStats.empty(for: now)
            saveArchive()
            
            // Re-check unlocks on week rollover (e.g. for "Perfect Week")
            UnlockManager.shared.checkForUnlocks()
        }
    }
    
    // MARK: - Persistence IO
    
    private func saveArchive() {
        let archive = HealthArchive(history: history, currentWeek: currentWeek)
        do {
            let data = try JSONEncoder().encode(archive)
            try data.write(to: archiveURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("❌ Failed to save Neural Vision Archive: \(error)")
        }
    }
    
    private func loadArchive() {
        guard FileManager.default.fileExists(atPath: archiveURL.path) else { return }
        do {
            let data = try Data(contentsOf: archiveURL)
            let archive = try JSONDecoder().decode(HealthArchive.self, from: data)
            self.history = archive.history
            self.currentWeek = archive.currentWeek
        } catch {
            print("⚠️ Failed to load Neural Vision Archive (might be first launch or corrupted format): \(error)")
        }
    }
    
    // MARK: - Daily Stats IO
    
    private static var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    /// Record a game session into today's daily stat bucket.
    func recordDailySession(kills: Int, focusSeconds: Double, shots: Int, hits: Int) {
        let key = Self.todayKey
        
        if let idx = dailyStats.firstIndex(where: { $0.dateKey == key }) {
            dailyStats[idx].sessions += 1
            dailyStats[idx].kills += kills
            dailyStats[idx].focusSeconds += focusSeconds
            dailyStats[idx].shots += shots
            dailyStats[idx].hits += hits
        } else {
            var stat = DailyStat(dateKey: key)
            stat.sessions = 1
            stat.kills = kills
            stat.focusSeconds = focusSeconds
            stat.shots = shots
            stat.hits = hits
            dailyStats.append(stat)
        }
        
        saveDailyStats()
    }
    
    /// Returns exactly 7 DailyStats for the last 7 days, filling in zeros for missing days.
    func last7Days() -> [DailyStat] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let today = Date()
        
        var result: [DailyStat] = []
        for offset in (0..<7).reversed() {
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let key = formatter.string(from: date)
            if let existing = dailyStats.first(where: { $0.dateKey == key }) {
                result.append(existing)
            } else {
                result.append(DailyStat(dateKey: key))
            }
        }
        return result
    }
    
    private func saveDailyStats() {
        do {
            let data = try JSONEncoder().encode(dailyStats)
            try data.write(to: dailyURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("❌ Failed to save daily stats: \(error)")
        }
    }
    
    private func loadDailyStats() {
        guard FileManager.default.fileExists(atPath: dailyURL.path) else { return }
        do {
            let data = try Data(contentsOf: dailyURL)
            self.dailyStats = try JSONDecoder().decode([DailyStat].self, from: data)
        } catch {
            print("⚠️ Failed to load daily stats: \(error)")
        }
    }
    
    /// Remove daily stats older than 14 days to keep file small.
    private func pruneOldDailyStats() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        let cutoffKey = formatter.string(from: cutoff)
        dailyStats.removeAll { $0.dateKey < cutoffKey }
        saveDailyStats()
    }
}

// MARK: - Date Helpers
extension Date {
    /// Returns the absolute Start Date of the current week (Sunday midnight).
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
}
