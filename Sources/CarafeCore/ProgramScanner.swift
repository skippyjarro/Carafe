import Foundation

public struct Program: Identifiable, Hashable, Sendable {
    public let name: String
    public let url: URL

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

    public static func scan(driveC: URL) -> [Program] {
        let shortcuts = startMenuRoots(driveC: driveC).flatMap { files(in: $0, withExtension: "lnk", maxDepth: 6) }
        // Start Menu shortcuts are what installers consider "the app"; raw .exe scanning is the fallback.
        let found = shortcuts.isEmpty
            ? ["Program Files", "Program Files (x86)"].flatMap {
                files(in: driveC.appendingPathComponent($0), withExtension: "exe", maxDepth: 3)
            }
            : shortcuts

        var seen = Set<String>()
        return found
            .filter(isLaunchable)
            .map { Program(name: $0.deletingPathExtension().lastPathComponent, url: $0) }
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
