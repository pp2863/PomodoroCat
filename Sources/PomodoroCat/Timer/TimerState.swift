enum SessionType: String, Codable, Equatable {
    case focus
    case shortBreak
    case longBreak
}

enum TimerPhase: Equatable {
    case idle
    case running(SessionType)
    case paused(SessionType)
}
