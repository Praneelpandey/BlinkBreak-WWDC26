import Foundation

struct Achievement: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    var isUnlocked: Bool
    var unlockDate: Date?
}
