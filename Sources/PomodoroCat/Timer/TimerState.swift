enum SessionType: String, Codable, Equatable {
    case focus
    case shortBreak
    /// No longer produced — long breaks were removed in favour of a single break
    /// length. Kept so history written before that still decodes: HistoryStore
    /// rewrites the whole file when patching a record, so an undecodable line
    /// would be dropped permanently.
    case longBreak
}

enum TimerPhase: Equatable {
    case idle
    case running(SessionType)
    case paused(SessionType)
}
