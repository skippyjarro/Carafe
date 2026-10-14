import Foundation

/// Per-bottle log files: `<bottle id>.log`, plus one rotated `<bottle id>.old.log`.
public enum BottleLogs {
    /// A log past this size is set aside as `.old.log` the next time something launches.
    static let rotationSize = 5 * 1024 * 1024

    public static func file(for id: UUID, in directory: URL = AppPaths.logs) -> URL {
        directory.appendingPathComponent("\(id.uuidString).log")
    }

    static func rotated(_ log: URL) -> URL {
        log.deletingPathExtension().appendingPathExtension("old.log")
    }

    /// Keeps at most one previous log. Programs already running keep writing to the renamed file.
    static func rotateIfNeeded(_ log: URL, limit: Int = rotationSize) {
        let fm = FileManager.default
        guard let size = (try? fm.attributesOfItem(atPath: log.path))?[.size] as? Int, size > limit else { return }
        let old = rotated(log)
        try? fm.removeItem(at: old)
        try? fm.moveItem(at: log, to: old)
    }

    public static func remove(for id: UUID, in directory: URL = AppPaths.logs) {
        let log = file(for: id, in: directory)
        try? FileManager.default.removeItem(at: log)
        try? FileManager.default.removeItem(at: rotated(log))
    }

    /// Deletes logs left behind by bottles that no longer exist in `bottles`.
    public static func removeOrphans(bottles: URL, in directory: URL = AppPaths.logs) {
        let fm = FileManager.default
        for log in (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] {
            let stem = log.lastPathComponent.prefix { $0 != "." }
            guard log.pathExtension == "log", UUID(uuidString: String(stem)) != nil,
                  !fm.fileExists(atPath: bottles.appendingPathComponent(String(stem)).path)
            else { continue }
            try? fm.removeItem(at: log)
        }
    }
}
