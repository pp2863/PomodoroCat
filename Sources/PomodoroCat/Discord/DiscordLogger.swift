import Foundation

final class DiscordLogger {
    static let shared = DiscordLogger()
    private init() {}

    func postFocusComplete(minutes: Int, completedAt: Date, webhookURL: URL, completion: @escaping (Bool) -> Void) {
        let formatter = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "embeds": [[
                "title": "🐾 Focus session complete",
                "description": "\(minutes) minutes focused — nice work!",
                "color": 5793266,
                "timestamp": formatter.string(from: completedAt)
            ]]
        ]
        send(payload: payload, to: webhookURL, retriesLeft: 1, completion: completion)
    }

    func sendTestMessage(to webhookURL: URL, completion: @escaping (Bool) -> Void) {
        let payload: [String: Any] = [
            "content": "✅ PomodoroCat webhook test successful"
        ]
        send(payload: payload, to: webhookURL, retriesLeft: 0, completion: completion)
    }

    private func send(payload: [String: Any], to url: URL, retriesLeft: Int, completion: @escaping (Bool) -> Void) {
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            let statusOK = (response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false
            if error == nil && statusOK {
                completion(true)
            } else if retriesLeft > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                    self?.send(payload: payload, to: url, retriesLeft: retriesLeft - 1, completion: completion)
                }
            } else {
                completion(false)
            }
        }.resume()
    }
}
