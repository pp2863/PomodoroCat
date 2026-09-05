import SwiftUI

/// Plain VStack layout (not Form) with an explicit fixed label width: macOS's
/// Form auto-sizes its label column to the longest label in the section, and
/// "Sessions until long break" was wide enough to push the segmented picker
/// and webhook field past the window's edge on both sides.
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    let timerEngine: TimerEngine

    @State private var selectedPreset: Preset = .classic
    @State private var testStatus: String = ""
    @State private var isTestingWebhook = false

    enum Preset: String, CaseIterable, Identifiable {
        case classic = "Classic"
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
                durationRow(label: "Short break (min)", value: $settings.config.shortBreakMinutes, range: 1...60)
                durationRow(label: "Long break (min)", value: $settings.config.longBreakMinutes, range: 1...120)
                durationRow(label: "Sessions/long break", value: $settings.config.sessionsUntilLongBreak, range: 1...12)

                Divider()

                sectionHeader("Discord")
                TextField("Webhook URL", text: $settings.webhookURLString)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button(isTestingWebhook ? "Testing…" : "Test Webhook") {
                        testWebhook()
                    }
                    .disabled(settings.webhookURLString.isEmpty || isTestingWebhook)
                    Text(testStatus)
                        .font(.caption)
                        .foregroundColor(testStatus.hasPrefix("✅") ? .green : .red)
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
        .onChange(of: settings.config) { newConfig in
            timerEngine.updateConfig(newConfig)
        }
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
        case .long: settings.config = .long
        case .custom: break
        }
    }

    private func testWebhook() {
        guard let url = URL(string: settings.webhookURLString) else {
            testStatus = "❌ Invalid URL"
            return
        }
        isTestingWebhook = true
        testStatus = ""
        DiscordLogger.shared.sendTestMessage(to: url) { success in
            DispatchQueue.main.async {
                isTestingWebhook = false
                testStatus = success ? "✅ Sent!" : "❌ Failed"
            }
        }
    }
}
