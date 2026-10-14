import Foundation

/// Per-application workarounds applied to a bottle's C: drive before anything launches in it.
public enum CompatibilityFixes {
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
