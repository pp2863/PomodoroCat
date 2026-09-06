import Foundation

final class TimerEngine: ObservableObject {
    @Published private(set) var phase: TimerPhase = .idle
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var didJustComplete: Bool = false
    /// Free-text purpose for the upcoming focus session, typed on the cat while
    /// idle. Cleared once a focus session completes so each one is described fresh.
    @Published var taskDescription: String = ""

    private(set) var config: SessionConfig
    private var pendingConfig: SessionConfig?
    private var timer: Timer?
    private var currentSessionStart: Date?

    var onSessionCompleted: ((SessionRecord) -> Void)?

    init(config: SessionConfig) {
        self.config = config
        self.remainingSeconds = config.focusMinutes * 60
    }

    /// Applies immediately if idle; otherwise queues the change for the next session
    /// so an in-progress countdown is never corrupted.
    func updateConfig(_ newConfig: SessionConfig) {
        if case .idle = phase {
            config = newConfig
            remainingSeconds = newConfig.focusMinutes * 60
        } else {
            pendingConfig = newConfig
        }
    }

    func togglePrimary() {
        switch phase {
        case .idle:
            start(.focus)
        case .running(let type):
            pause(type)
        case .paused(let type):
            resume(type)
        }
    }

    func stop() {
        stopTicking()
        phase = .idle
        currentSessionStart = nil
        if let pending = pendingConfig {
            config = pending
            pendingConfig = nil
        }
        remainingSeconds = config.focusMinutes * 60
    }

    private func start(_ type: SessionType) {
        currentSessionStart = Date()
        remainingSeconds = duration(for: type) * 60
        phase = .running(type)
        startTicking()
    }

    private func pause(_ type: SessionType) {
        phase = .paused(type)
        stopTicking()
    }

    private func resume(_ type: SessionType) {
        phase = .running(type)
        startTicking()
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopTicking() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard remainingSeconds > 0 else { return }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            completeCurrentSession()
        }
    }

    private var trimmedTask: String? {
        let trimmed = taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func duration(for type: SessionType) -> Int {
        switch type {
        case .focus: return config.focusMinutes
        case .shortBreak, .longBreak: return config.shortBreakMinutes
        }
    }

    private func completeCurrentSession() {
        guard case .running(let type) = phase, let sessionStart = currentSessionStart else { return }
        stopTicking()

        let record = SessionRecord(
            id: UUID(),
            type: type,
            startedAt: sessionStart,
            completedAt: Date(),
            durationMinutes: duration(for: type),
            task: trimmedTask,
            obsidianLogged: nil
        )

        if type == .focus {
            taskDescription = ""
        }

        if let pending = pendingConfig {
            config = pending
            pendingConfig = nil
        }

        let next = nextSessionType(after: type)
        pulseCompletion()
        onSessionCompleted?(record)

        currentSessionStart = nil
        start(next)
    }

    private func nextSessionType(after type: SessionType) -> SessionType {
        switch type {
        case .focus: return .shortBreak
        case .shortBreak, .longBreak: return .focus
        }
    }

    private func pulseCompletion() {
        didJustComplete = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.didJustComplete = false
        }
    }
}
