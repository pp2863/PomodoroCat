import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    func notifySessionCompleted(type: SessionType) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        switch type {
        case .focus:
            content.title = "Focus session complete 🐾"
            content.body = "Great work! Time for a break."
        case .shortBreak:
            content.title = "Break's over"
            content.body = "Ready to focus again?"
        case .longBreak:
            content.title = "Long break's over"
            content.body = "Ready for a fresh set of focus sessions?"
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
