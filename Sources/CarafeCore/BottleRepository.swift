import Foundation

public enum AppPaths {
    public static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Carafe", isDirectory: true)
    }

    public static var bottles: URL { root.appendingPathComponent("Bottles", isDirectory: true) }
    public static var engines: URL { root.appendingPathComponent("Engines", isDirectory: true) }

    public static var logs: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Carafe", isDirectory: true)
    }
}

/// Persists bottle metadata as `carafe.json` inside each bottle's prefix directory.
public struct BottleRepository: Sendable {
    public static let metadataFile = "carafe.json"

    public let root: URL

    public init(root: URL = AppPaths.bottles) {
        self.root = root
    }

    public func prefix(for bottle: Bottle) -> URL {
        root.appendingPathComponent(bottle.id.uuidString, isDirectory: true)
    }

    public func driveC(for bottle: Bottle) -> URL {
        prefix(for: bottle).appendingPathComponent("drive_c", isDirectory: true)
    }

    public func loadAll() -> [Bottle] {
        let fm = FileManager.default
        let dirs = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        return dirs.compactMap { dir in
            guard let data = try? Data(contentsOf: dir.appendingPathComponent(Self.metadataFile)) else { return nil }
            return try? decoder.decode(Bottle.self, from: data)
        }
        .sorted { $0.created < $1.created }
    }

    public func save(_ bottle: Bottle) throws {
        let dir = prefix(for: bottle)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(bottle).write(to: dir.appendingPathComponent(Self.metadataFile), options: .atomic)
    }
}
