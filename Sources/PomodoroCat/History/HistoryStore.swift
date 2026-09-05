import Foundation

/// Append-only JSONL (one JSON object per line) session log, so writes are cheap
/// and a partial/corrupt trailing line can't take out the whole history.
final class HistoryStore {
    static let shared = HistoryStore()

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue = DispatchQueue(label: "com.local.pomodorocat.history")

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("PomodoroCat", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("history.json")

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        decoder = dec

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }

    func append(_ record: SessionRecord) {
        queue.async { [self] in
            guard let data = try? encoder.encode(record),
                  let handle = try? FileHandle(forWritingTo: fileURL) else { return }
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
            handle.write("\n".data(using: .utf8)!)
        }
    }

    /// Discord posting happens asynchronously after the record is already written,
    /// so once the result is known we patch that one record's flag in place.
    func updateDiscordStatus(id: UUID, posted: Bool) {
        queue.async { [self] in
            var records = loadAllUnsynchronized()
            guard let index = records.firstIndex(where: { $0.id == id }) else { return }
            records[index].discordPosted = posted
            let lines = records.compactMap { record -> String? in
                guard let data = try? encoder.encode(record) else { return nil }
                return String(data: data, encoding: .utf8)
            }
            let content = lines.joined(separator: "\n") + "\n"
            try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    func loadAll() -> [SessionRecord] {
        queue.sync { loadAllUnsynchronized() }
    }

    private func loadAllUnsynchronized() -> [SessionRecord] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        return content.split(separator: "\n").compactMap { line in
            guard let data = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(SessionRecord.self, from: data)
        }
    }
}
