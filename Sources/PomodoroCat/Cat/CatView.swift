import SwiftUI

/// Pixel-art cat rendered from CatPixelArt's grid data. The art itself is purely
/// decorative — hit-testing for it is handled by PanelContentView (AppKit)
/// sitting behind this — with the one exception of the task text, which has to
/// take clicks itself so it can be typed into.
struct CatView: View {
    @ObservedObject var engine: TimerEngine
    /// Called when the user clicks the task text: the panel has to be allowed to
    /// take key focus before a text field on it can accept typing.
    var onBeginEditingTask: () -> Void = {}
    var onEndEditingTask: () -> Void = {}

    static let frameSize: CGFloat = 240
    private let cellSize: CGFloat = 8
    private let ringDiameter: CGFloat = 210
    private let taskCharacterLimit = 60

    @State private var isBlinking = false
    @State private var breathingScale: CGFloat = 1.0
    @State private var tailAngle: Double = -8
    @State private var celebrateBounce: CGFloat = 1.0
    @State private var blinkTimer: Timer?
    @State private var isEditingTask = false
    @FocusState private var isTaskFocused: Bool

    private var mood: CatMood {
        if engine.didJustComplete { return .celebrating }
        switch engine.phase {
        case .idle: return .idle
        case .running(.focus), .paused(.focus): return .focusing
        case .running, .paused: return .onBreak
        }
    }

    private var totalSeconds: Int {
        switch engine.phase {
        case .running(let type), .paused(let type):
            switch type {
            case .focus: return engine.config.focusMinutes * 60
            case .shortBreak, .longBreak: return engine.config.shortBreakMinutes * 60
            }
        case .idle:
            return max(engine.config.focusMinutes * 60, 1)
        }
    }

    private var progress: Double {
        1 - Double(engine.remainingSeconds) / Double(totalSeconds)
    }

    private var isIdle: Bool { engine.phase == .idle }

    private var label: String {
        let m = engine.remainingSeconds / 60
        let s = engine.remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var currentGrid: [[PixelColor]] {
        var grid = CatPixelArt.baseGrid()
        if isBlinking {
            CatPixelArt.applyBlink(to: &grid)
        } else if mood == .focusing {
            CatPixelArt.applySquint(to: &grid)
        } else if mood == .onBreak {
            CatPixelArt.applyBlush(to: &grid)
        }
        return grid
    }

    var body: some View {
        ZStack {
            ZStack {
                if mood == .focusing {
                    Circle()
                        .trim(from: 0, to: max(0.001, progress))
                        .stroke(Color.orange.opacity(0.85), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: ringDiameter, height: ringDiameter)
                }

                ZStack {
                    pixelGrid(currentGrid, cellSize: cellSize)
                    pixelGrid(CatPixelArt.tailGrid(), cellSize: cellSize)
                        .rotationEffect(.degrees(tailAngle), anchor: .topLeading)
                        .offset(x: 58, y: 6)
                }
                .scaleEffect(breathingScale * celebrateBounce)

                timerLabel
                    .offset(y: isIdle ? 30 : 40)
            }
            .frame(width: Self.frameSize, height: Self.frameSize)
            .overlay(alignment: .topTrailing) { gearIcon }
            .allowsHitTesting(false)

            if isIdle {
                taskText
                    .offset(y: 60)
            }
        }
        .frame(width: Self.frameSize, height: Self.frameSize)
        .onAppear { startAnimations() }
        .onChange(of: mood) { _ in reactToMoodChange() }
        .onChange(of: isIdle) { idle in
            // Starting a session hides the field; make sure focus goes back to
            // whatever the user was working in.
            if !idle { finishEditingTask() }
        }
        .onDisappear { blinkTimer?.invalidate() }
    }

    private func pixelGrid(_ grid: [[PixelColor]], cellSize: CGFloat) -> some View {
        let rows = grid.count
        let cols = grid.first?.count ?? 0
        return Canvas { context, size in
            let cw = size.width / CGFloat(cols)
            let ch = size.height / CGFloat(rows)
            for (rowIndex, row) in grid.enumerated() {
                for (colIndex, pixel) in row.enumerated() {
                    guard pixel != .clear else { continue }
                    let rect = CGRect(
                        x: CGFloat(colIndex) * cw,
                        y: CGFloat(rowIndex) * ch,
                        width: cw + 0.5,
                        height: ch + 0.5
                    )
                    context.fill(Path(rect), with: .color(pixel.color))
                }
            }
        }
        .frame(width: CGFloat(cols) * cellSize, height: CGFloat(rows) * cellSize)
    }

    /// Shown only while idle: the countdown shrinks a little to make room, and
    /// the text sits bare on the cat's belly rather than in a capsule.
    private var taskText: some View {
        Group {
            if isEditingTask {
                TextField("(task)", text: $engine.taskDescription)
                    .textFieldStyle(.plain)
                    .focused($isTaskFocused)
                    .onSubmit { finishEditingTask() }
                    .onExitCommand { finishEditingTask() }
                    .onChange(of: engine.taskDescription) { newValue in
                        if newValue.count > taskCharacterLimit {
                            engine.taskDescription = String(newValue.prefix(taskCharacterLimit))
                        }
                    }
                    .onChange(of: isTaskFocused) { focused in
                        if !focused { finishEditingTask() }
                    }
            } else {
                Text(engine.taskDescription.isEmpty ? "(task)" : engine.taskDescription)
                    .opacity(engine.taskDescription.isEmpty ? 0.5 : 1)
                    .onTapGesture { beginEditingTask() }
            }
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .multilineTextAlignment(.center)
        .foregroundColor(PixelColor.outline.color)
        .lineLimit(1)
        .frame(width: 140)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    private var timerLabel: some View {
        Text(label)
            .font(.system(size: isIdle ? 20 : 26, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.black.opacity(0.6))
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }

    private var gearIcon: some View {
        Image(systemName: "gearshape.fill")
            .font(.system(size: 19))
            // The cat's own grey rather than a theme colour, so it stays visible
            // whatever the panel is floating over; the shadow keeps it legible
            // against light backgrounds too.
            .foregroundColor(PixelColor.gray.color)
            .shadow(color: .black.opacity(0.35), radius: 1.5, y: 0.5)
            .padding(13)
    }

    private func beginEditingTask() {
        onBeginEditingTask()
        isEditingTask = true
        // Focus has to wait until the field actually exists in the hierarchy.
        DispatchQueue.main.async { isTaskFocused = true }
    }

    private func finishEditingTask() {
        guard isEditingTask else { return }
        isTaskFocused = false
        isEditingTask = false
        engine.taskDescription = engine.taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        onEndEditingTask()
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            breathingScale = 1.04
        }
        scheduleBlinking()
        reactToMoodChange()
    }

    private func animateTail() {
        let duration = mood == .onBreak ? 0.6 : 1.6
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            tailAngle = (mood == .idle || mood == .onBreak) ? 12 : -8
        }
    }

    private func scheduleBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            isBlinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isBlinking = false
            }
        }
    }

    private func reactToMoodChange() {
        if mood == .celebrating {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                celebrateBounce = 1.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring()) { celebrateBounce = 1.0 }
            }
        }
        animateTail()
    }
}
