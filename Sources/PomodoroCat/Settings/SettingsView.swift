import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Plain VStack layout (not Form) with an explicit fixed label width: macOS's
/// Form auto-sizes its label column to the longest label in the section, which
/// pushed the segmented picker and webhook field past the window's edge on
/// both sides.
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    let timerEngine: TimerEngine

    @State private var selectedPreset: Preset = .classic

    enum Preset: String, CaseIterable, Identifiable {
        case classic = "Classic"
        case medium = "Medium"
        case long = "Long"
        case custom = "Custom"
        var id: String { rawValue }
    }

    static let windowWidth: CGFloat = 420
    private let labelWidth: CGFloat = 150

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("Durations")

                Picker("", selection: $selectedPreset) {
                    ForEach(Preset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: selectedPreset) { newValue in applyPreset(newValue) }

                durationRow(label: "Focus (min)", value: $settings.config.focusMinutes, range: 1...180)
                durationRow(label: "Break (min)", value: $settings.config.shortBreakMinutes, range: 1...60)

                Divider()

                sectionHeader("Obsidian")
                TextField("Path to log note", text: $settings.obsidianLogPath)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Choose…") { chooseLogFile() }
                    Text(logFileStatus)
                        .font(.caption)
                        .foregroundColor(logFileExists ? .secondary : .orange)
                    Spacer()
                }

                Divider()

                sectionHeader("General")
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Button("Reset Timer", role: .destructive) {
                    timerEngine.stop()
                }
            }
            .padding(20)
        }
        .frame(width: Self.windowWidth)
        .onAppear { selectedPreset = preset(matching: settings.config) }
        .onChange(of: settings.config) { newConfig in
            timerEngine.updateConfig(newConfig)
            // Keep the picker honest: editing the steppers by hand flips it to
            // Custom, rather than leaving a preset highlighted that no longer
            // matches (which also made re-picking that preset a no-op).
            selectedPreset = preset(matching: newConfig)
        }
    }

    private func preset(matching config: SessionConfig) -> Preset {
        if config == .classic { return .classic }
        if config == .medium { return .medium }
        if config == .long { return .long }
        return .custom
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(.headline)
    }

    private func durationRow(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .frame(width: labelWidth, alignment: .leading)
            Spacer()
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue)")
                    .monospacedDigit()
                    .frame(width: 28, alignment: .trailing)
            }
        }
    }

    private func applyPreset(_ preset: Preset) {
        switch preset {
        case .classic: settings.config = .classic
        case .medium: settings.config = .medium
        case .long: settings.config = .long
        case .custom: break
        }
    }

    private var logFileExists: Bool {
        let path = (settings.obsidianLogPath as NSString).expandingTildeInPath
        return !path.isEmpty && FileManager.default.fileExists(atPath: path)
    }

    private var logFileStatus: String {
        if settings.obsidianLogPath.isEmpty { return "No log note set — sessions won't be logged" }
        return logFileExists ? "Note found" : "Note doesn't exist yet — it'll be created"
    }

    private func chooseLogFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.init(filenameExtension: "md") ?? .plainText]
        panel.message = "Choose the note in your vault to log sessions to"
        if panel.runModal() == .OK, let url = panel.url {
            settings.obsidianLogPath = url.path
        }
    }
}
