import Foundation

struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let type: SessionType
    let startedAt: Date
    let completedAt: Date
    let durationMinutes: Int
    /// What the session was for, typed on the cat before starting it. Optional
    /// so history written before this existed still decodes.
    let task: String?
    /// Whether the session made it into the Obsidian note. Set before the record
    /// is written, so history stays strictly append-only.
    var obsidianLogged: Bool?
}
