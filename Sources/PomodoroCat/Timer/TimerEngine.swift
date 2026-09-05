import Foundation

final class TimerEngine: ObservableObject {
    @Published private(set) var phase: TimerPhase = .idle
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var completedFocusSessions: Int = 0
    @Published private(set) var didJustComplete: Bool = false

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
        completedFocusSessions = 0
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

    private func duration(for type: SessionType) -> Int {
        switch type {
        case .focus: return config.focusMinutes
        case .shortBreak: return config.shortBreakMinutes
        case .longBreak: return config.longBreakMinutes
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
            discordPosted: nil
        )

        if type == .focus {
            completedFocusSessions += 1
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
        case .focus:
            return completedFocusSessions >= config.sessionsUntilLongBreak ? .longBreak : .shortBreak
        case .shortBreak:
            return .focus
        case .longBreak:
            completedFocusSessions = 0
            return .focus
        }
    }

    private func pulseCompletion() {
        didJustComplete = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.didJustComplete = false
        }
    }
}
