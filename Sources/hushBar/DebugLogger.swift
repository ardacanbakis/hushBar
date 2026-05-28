import Foundation

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var timeLabel: String { Self.timeFormatter.string(from: timestamp) }
}

final class DebugLogger: ObservableObject {
    static let shared = DebugLogger()
    private let maxEntries = 1_000

    @Published private(set) var entries: [LogEntry] = []

    private init() {}

    func log(_ message: String) {
        let entry = LogEntry(timestamp: Date(), message: message)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
    }

    func clear() {
        DispatchQueue.main.async { self.entries.removeAll() }
    }

    func allText() -> String {
        entries.map { "[\($0.timeLabel)] \($0.message)" }.joined(separator: "\n")
    }
}

/// Logs to both the system log (Console.app) and the in-app debug panel.
func hushLog(_ message: String) {
    NSLog("hushBar: %@", message)
    DebugLogger.shared.log(message)
}
