import Foundation

public enum WindowsVersion: String, Codable, CaseIterable, Identifiable, Sendable {
    case win11, win10, win81, win7

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .win11: "Windows 11"
        case .win10: "Windows 10"
        case .win81: "Windows 8.1"
        case .win7: "Windows 7"
        }
    }
}

/// How Wine emulates Windows synchronization primitives. msync (Mach semaphores)
/// is fastest but only exists in patched builds; unsupported modes are ignored by Wine.
public enum SyncMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case msync, esync, none

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .msync: "MSync"
        case .esync: "ESync"
        case .none: "Off"
        }
    }
}

public struct BottleSettings: Codable, Hashable, Sendable {
    public var syncMode: SyncMode = .msync
    public var metalHUD = false
    public var advertiseAVX = false
    public var retinaMode = false
    public var extraEnvironment: [String: String] = [:]

    public init() {}
}

/// A bottle is one isolated Windows install: its own C: drive, registry and settings.
/// The bottle directory doubles as the WINEPREFIX.
public struct Bottle: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var windowsVersion: WindowsVersion
    public var settings: BottleSettings
    public var created: Date
    /// Name of the Wine engine this bottle was created with. Bottles can't move to an older Wine.
    public var engineName: String?

    public init(
        id: UUID = UUID(),
        name: String,
        windowsVersion: WindowsVersion = .win10,
        settings: BottleSettings = BottleSettings(),
        created: Date = Date(),
        engineName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.windowsVersion = windowsVersion
        self.settings = settings
        self.created = created
        self.engineName = engineName
    }
}
