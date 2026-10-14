import Foundation

/// A Wine installation Carafe can drive.
public struct WineEngine: Hashable, Sendable {
    public let name: String
    public let binDirectory: URL
    public let wine: URL
    /// Folder of bundled libraries and graphics translation layers that ships with gaming engines.
    public let support: URL?

    public init(name: String, binDirectory: URL, wine: URL, support: URL? = nil) {
        self.name = name
        self.binDirectory = binDirectory
        self.wine = wine
        self.support = support
    }

    public var wineserver: URL { binDirectory.appendingPathComponent("wineserver") }

    /// Library injected into Wine processes to work around engine bugs (see Scripts/sysctl-shim.c).
    public var shim: URL? {
        guard let url = support?.deletingLastPathComponent().appendingPathComponent("carafe-shim.dylib"),
              FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return url
    }

    /// Apple's D3DMetal (DirectX 11/12 → Metal), which modern games need.
    public var d3dMetal: URL? {
        guard let dir = support?.appendingPathComponent("renderer/d3dmetal"),
              FileManager.default.fileExists(atPath: dir.appendingPathComponent("external/D3DMetal.framework").path)
        else { return nil }
        return dir
    }

    /// True for engines built from CodeWeavers' source with Carafe's plugin (Scripts/engine/cxcompatdb.c),
    /// which accepts a list of graphics-layer folders rather than a single one.
    public var hasGraphicsPlugin: Bool {
        FileManager.default.fileExists(
            atPath: binDirectory.appendingPathComponent("../lib/wine/x86_64-unix/cxcompatdb.so").standardizedFileURL.path)
    }

    /// Folder of replacement DirectX libraries for a graphics layer, or nil if this engine doesn't ship it.
    public func renderer(_ backend: GraphicsBackend) -> URL? {
        switch backend {
        case .d3dMetal:
            return d3dMetal?.appendingPathComponent("wine")
        case .dxmt, .dxvk:
            guard let dir = support?.appendingPathComponent("renderer/\(backend.rawValue)/wine"),
                  FileManager.default.fileExists(atPath: dir.path)
            else { return nil }
            return dir
        case .wined3d:
            return nil
        }
    }

    /// The graphics layers a bottle on this engine can choose from. Wine's own is always there.
    public var graphicsBackends: [GraphicsBackend] {
        GraphicsBackend.allCases.filter { $0 == .wined3d || renderer($0) != nil }
    }
}

public struct EngineCandidate {
    public var name: String
    public var binDirectory: URL
    public var support: URL?

    public init(name: String, binDirectory: URL, support: URL? = nil) {
        self.name = name
        self.binDirectory = binDirectory
        self.support = support
    }
}

public enum WineLocator {
    static let binaryNames = ["wine64", "wine"]

    /// Places that may contain a wine binary, best first.
    public static func candidates(
        engines: URL = AppPaths.engines,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [EngineCandidate] {
        var gaming: [EngineCandidate] = []
        var plain: [EngineCandidate] = []

        // Engines managed by Carafe. A gaming engine is a folder holding `wine/` next to `Frameworks/`;
        // otherwise it is a raw wine tree or a "Wine *.app" bundle.
        let managed = ((try? FileManager.default.contentsOfDirectory(at: engines, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for dir in managed {
            // Only strip ".app": a version like "CrossOver 24.0.7" would otherwise lose its ".7".
            let name = dir.pathExtension == "app" ? dir.deletingPathExtension().lastPathComponent : dir.lastPathComponent
            gaming.append(EngineCandidate(
                name: name,
                binDirectory: dir.appendingPathComponent("wine/bin"),
                support: dir.appendingPathComponent("Frameworks")))
            plain.append(EngineCandidate(name: name, binDirectory: dir.appendingPathComponent("Contents/Resources/wine/bin")))
            plain.append(EngineCandidate(name: name, binDirectory: dir.appendingPathComponent("bin")))
        }

        for app in ["Game Porting Toolkit", "Wine Staging", "Wine Stable", "Wine Devel"] {
            for base in ["/Applications", home.appendingPathComponent("Applications").path] {
                plain.append(EngineCandidate(
                    name: app, binDirectory: URL(fileURLWithPath: "\(base)/\(app).app/Contents/Resources/wine/bin")))
            }
        }

        plain.append(EngineCandidate(name: "Whisky Wine", binDirectory: home.appendingPathComponent(
            "Library/Application Support/com.isaacmarovitz.Whisky/Libraries/Wine/bin")))
        plain.append(EngineCandidate(name: "Homebrew Wine", binDirectory: URL(fileURLWithPath: "/opt/homebrew/bin")))
        plain.append(EngineCandidate(name: "Wine", binDirectory: URL(fileURLWithPath: "/usr/local/bin")))
        return gaming + plain
    }

    /// Every installed engine, best first.
    public static func locateAll(
        in candidates: [EngineCandidate] = candidates(),
        isExecutable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)
    ) -> [WineEngine] {
        var seen = Set<String>()
        return candidates.compactMap { candidate in
            guard let binary = binaryNames.first(where: {
                isExecutable(candidate.binDirectory.appendingPathComponent($0).path)
            }), seen.insert(candidate.name).inserted else { return nil }
            return WineEngine(
                name: candidate.name,
                binDirectory: candidate.binDirectory,
                wine: candidate.binDirectory.appendingPathComponent(binary),
                support: candidate.support)
        }
    }
}
