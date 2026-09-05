import Foundation

struct SessionConfig: Codable, Equatable {
    var focusMinutes: Int
    var shortBreakMinutes: Int
    var longBreakMinutes: Int
    var sessionsUntilLongBreak: Int

    static let classic = SessionConfig(focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, sessionsUntilLongBreak: 4)
    static let long = SessionConfig(focusMinutes: 50, shortBreakMinutes: 10, longBreakMinutes: 20, sessionsUntilLongBreak: 4)
}
