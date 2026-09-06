import Foundation

/// Appends completed sessions to a markdown note in the user's Obsidian vault,
/// as one plain line per session under a per-day heading:
///
///     ## 09/06/2026
///
///     - 14:32 — 25 min — Write Q3 report
///     - 15:05 — 25 min — Review PR #142
///
/// Writes are plain file edits rather than anything Obsidian-specific — Obsidian
/// picks up external changes to the vault on its own.
final class ObsidianLogger {
    static let shared = ObsidianLogger()
    private init() {}

    /// Both the day heading and the logged time come from when the session
    /// *started*, so a session running across midnight files under the day it
    /// belonged to rather than being split from its own heading.
    private static let headingFormatter = formatter(for: "MM/dd/yyyy")
    private static let timeFormatter = formatter(for: "HH:mm")

    private static func formatter(for format: String) -> DateFormatter {
        let formatter = DateFormatter()
        // Fixed locale so the log reads the same regardless of system region —
        // in particular 24-hour times, not a locale-dependent 12-hour clock.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    /// Returns whether the row was written. Never throws: a logging failure
    /// should never interrupt the timer.
    @discardableResult
    func append(_ record: SessionRecord, logPath: String) -> Bool {
        let path = (logPath as NSString).expandingTildeInPath
        guard !path.isEmpty else { return false }
        let url = URL(fileURLWithPath: path)

        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let updated = insert(row(for: record), forDay: Self.headingFormatter.string(from: record.startedAt), into: existing)

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try updated.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Obsidian log write failed: \(error)")
            return false
        }
    }

    private func row(for record: SessionRecord) -> String {
        let time = Self.timeFormatter.string(from: record.startedAt)
        let line = "- \(time) — \(record.durationMinutes) min"
        // Nothing typed for the session: leave the line at time and duration
        // rather than trailing a separator with nothing after it.
        guard let task = record.task, !task.isEmpty else { return line }
        return "\(line) — \(task)"
    }

    /// Adds the line to today's list, starting a new dated section if this is the
    /// day's first session. It goes at the end of that day's section rather than
    /// the end of the file, so anything written below a past day stays put.
    private func insert(_ row: String, forDay heading: String, into contents: String) -> String {
        var lines = contents.components(separatedBy: "\n")
        let headingLine = "## \(heading)"

        guard let headingIndex = lines.firstIndex(of: headingLine) else {
            var trimmed = contents
            while trimmed.hasSuffix("\n") {
                trimmed.removeLast()
            }
            let section = "\n\n\(headingLine)\n\n\(row)\n"
            return trimmed + section
        }

        // End of this day's section: the next heading of the same level, or EOF.
        let afterHeading = lines.index(after: headingIndex)
        let nextHeadingIndex = lines[afterHeading...].firstIndex { $0.hasPrefix("## ") } ?? lines.endIndex

        // Step back over blank lines so the row lands right under the last row of
        // the table rather than after the gap before the next section.
        var insertionIndex = nextHeadingIndex
        while insertionIndex > afterHeading, lines[lines.index(before: insertionIndex)].trimmingCharacters(in: .whitespaces).isEmpty {
            insertionIndex = lines.index(before: insertionIndex)
        }

        lines.insert(row, at: insertionIndex)
        return lines.joined(separator: "\n")
    }
}
