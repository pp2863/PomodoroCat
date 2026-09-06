import Foundation
import ServiceManagement

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var config: SessionConfig {
        didSet { persistConfig() }
    }
    @Published var obsidianLogPath: String {
        didSet { defaults.set(obsidianLogPath, forKey: obsidianLogPathKey) }
    }
    @Published var launchAtLogin: Bool {
        didSet { updateLaunchAtLogin() }
    }

    private let defaults = UserDefaults.standard
    private let configKey = "sessionConfig"
    private let launchAtLoginKey = "launchAtLogin"
    private let obsidianLogPathKey = "obsidianLogPath"

    private init() {
        if let data = defaults.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(SessionConfig.self, from: data) {
            config = decoded
        } else {
            config = .classic
        }
        // Resolve the vault once, then pin it. Detection keys off whichever vault
        // Obsidian last had open, so re-running it on every launch would silently
        // start logging into a different vault the moment another one is opened.
        if let storedPath = defaults.string(forKey: obsidianLogPathKey) {
            obsidianLogPath = storedPath
        } else {
            let detected = Self.detectDefaultLogPath()
            obsidianLogPath = detected
            defaults.set(detected, forKey: obsidianLogPathKey)
        }
        launchAtLogin = defaults.bool(forKey: launchAtLoginKey)
    }

    /// Obsidian records its vaults in its own config file, so a first run can
    /// point at the right note without the user typing a path.
    private static func detectDefaultLogPath() -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let configURL = appSupport.appendingPathComponent("obsidian/obsidian.json")
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let vaults = json["vaults"] as? [String: [String: Any]] else { return "" }

        let openVault = vaults.values.first { $0["open"] as? Bool == true }
        guard let path = (openVault ?? vaults.values.first)?["path"] as? String else { return "" }
        return (path as NSString).appendingPathComponent("PomodoroLog.md")
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
