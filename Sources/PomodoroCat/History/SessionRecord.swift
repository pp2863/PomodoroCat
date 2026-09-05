import Foundation

struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let type: SessionType
    let startedAt: Date
    let completedAt: Date
    let durationMinutes: Int
    var discordPosted: Bool?
}
