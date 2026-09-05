import Foundation
import ServiceManagement

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var config: SessionConfig {
        didSet { persistConfig() }
    }
    @Published var webhookURLString: String {
        didSet { KeychainHelper.saveWebhookURL(webhookURLString) }
    }
    @Published var launchAtLogin: Bool {
        didSet { updateLaunchAtLogin() }
    }

    private let defaults = UserDefaults.standard
    private let configKey = "sessionConfig"
    private let launchAtLoginKey = "launchAtLogin"

    private init() {
        if let data = defaults.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(SessionConfig.self, from: data) {
            config = decoded
        } else {
            config = .classic
        }
        webhookURLString = KeychainHelper.loadWebhookURL() ?? ""
        launchAtLogin = defaults.bool(forKey: launchAtLoginKey)
    }

    private func persistConfig() {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: configKey)
        }
    }

    private func updateLaunchAtLogin() {
        defaults.set(launchAtLogin, forKey: launchAtLoginKey)
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Launch at login update failed: \(error)")
        }
    }
}
