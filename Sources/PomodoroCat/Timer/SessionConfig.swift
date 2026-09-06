import Foundation

struct SessionConfig: Codable, Equatable {
    var focusMinutes: Int
    var shortBreakMinutes: Int

    static let classic = SessionConfig(focusMinutes: 25, shortBreakMinutes: 1)
    static let medium = SessionConfig(focusMinutes: 50, shortBreakMinutes: 5)
    static let long = SessionConfig(focusMinutes: 90, shortBreakMinutes: 10)
}
