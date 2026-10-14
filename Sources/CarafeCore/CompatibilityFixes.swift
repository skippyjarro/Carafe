import Foundation

/// Per-application workarounds applied to a bottle's C: drive before anything launches in it.
public enum CompatibilityFixes {
    /// Options added to a program's command line whenever it starts, keyed by executable name.
    /// Launchers built on Chromium can't draw through a separate GPU process on macOS; these make
    /// them render in-process in software. CrossOver 24 carries the same table inside Wine, and
    /// engines built with Carafe's patch (Scripts/engine/patches) read it from WINE_CMDLINE_APPEND.
    public static let launchOptions = [
        "Battle.net.exe": "--in-process-gpu --use-gl=swiftshader",
        "steamwebhelper.exe": "--no-sandbox --in-process-gpu --disable-gpu",
    ]

    /// `launchOptions` in the form Wine reads: "program.exe=options;program.exe=options".
    public static var launchOptionsVariable: String {
        launchOptions.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
    }

    public static func apply(driveC: URL) {
        linkBattleNetExecutable(driveC: driveC)
    }

    /// Battle.net's Agent only trusts the launcher after checking the signature of its executable,
    /// and Wine 9 hands the Agent the bare name "Battle.net.exe" instead of a full path. The Agent
    /// runs from the versioned folder, so a link there to the real executable lets the check succeed.
    /// Without it the launcher shows error BLZBNTBNA00000005 and no games.
    static func linkBattleNetExecutable(driveC: URL) {
        let fm = FileManager.default
        let install = driveC.appendingPathComponent("Program Files (x86)/Battle.net")
        guard fm.fileExists(atPath: install.appendingPathComponent("Battle.net.exe").path) else { return }

        let children = (try? fm.contentsOfDirectory(at: install, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        for dir in children where dir.lastPathComponent.hasPrefix("Battle.net.") {
            guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            let link = dir.appendingPathComponent("Battle.net.exe")
            // attributesOfItem doesn't follow links, so this also sees a dangling one.
            if (try? fm.attributesOfItem(atPath: link.path)) != nil { continue }
            try? fm.createSymbolicLink(atPath: link.path, withDestinationPath: "../Battle.net.exe")
        }
    }
}
