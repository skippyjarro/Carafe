import Foundation

public struct Program: Identifiable, Hashable, Sendable {
    public let name: String
    public let url: URL
    /// Added to the list by the user rather than found by scanning.
    public var isPinned = false

    public var id: URL { url }
}

/// Finds installed Windows programs in a bottle's C: drive.
public enum ProgramScanner {
    /// Substrings (lowercased) marking executables that aren't worth showing as a program.
    static let noise = ["unins", "setup", "install", "crash", "helper", "redist", "update", "report", "dxsetup"]

    /// Decides whether a discovered file should be listed as a launchable program.
    /// This is the heuristic to tune if the Programs list shows junk or hides something you want.
    public static func isLaunchable(_ file: URL) -> Bool {
        let name = file.deletingPathExtension().lastPathComponent.lowercased()
        return !noise.contains { name.contains($0) }
    }

    /// Resolves a pinned program's stored path, or nil if `file` isn't inside the C: drive.
    public static func relativePath(of file: URL, in driveC: URL) -> String? {
        let root = driveC.standardizedFileURL.path + "/"
        let path = file.standardizedFileURL.path
        return path.hasPrefix(root) ? String(path.dropFirst(root.count)) : nil
    }

    public static func scan(driveC: URL, pinned: [String] = []) -> [Program] {
        let pins = pinned
            .map { driveC.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map { Program(name: $0.deletingPathExtension().lastPathComponent, url: $0, isPinned: true) }

        let shortcuts = startMenuRoots(driveC: driveC).flatMap { files(in: $0, withExtension: "lnk", maxDepth: 6) }
        // Start Menu shortcuts are what installers consider "the app"; raw .exe scanning is the fallback.
        let found = shortcuts.isEmpty
            ? ["Program Files", "Program Files (x86)"].flatMap {
                files(in: driveC.appendingPathComponent($0), withExtension: "exe", maxDepth: 3)
            }
            : shortcuts

        // Pins come first so they win over a scanned program of the same name.
        var seen = Set<String>()
        let scanned = found
            .filter(isLaunchable)
            .map { Program(name: $0.deletingPathExtension().lastPathComponent, url: $0) }
        return (pins + scanned)
            .filter { seen.insert($0.name.lowercased()).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func startMenuRoots(driveC: URL) -> [URL] {
        var roots = [driveC.appendingPathComponent("ProgramData/Microsoft/Windows/Start Menu/Programs")]
        let users = (try? FileManager.default.contentsOfDirectory(
            at: driveC.appendingPathComponent("users"), includingPropertiesForKeys: nil)) ?? []
        roots += users.map { $0.appendingPathComponent("AppData/Roaming/Microsoft/Windows/Start Menu/Programs") }
        return roots
    }

    static func files(in root: URL, withExtension ext: String, maxDepth: Int) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
        ) else { return [] }

        var result: [URL] = []
        for case let url as URL in enumerator {
            if enumerator.level > maxDepth {
                enumerator.skipDescendants()
            } else if url.pathExtension.lowercased() == ext {
                result.append(url)
            }
        }
        return result
    }
}
