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

/// What translates a program's DirectX calls into something macOS can draw.
public enum GraphicsBackend: String, Codable, CaseIterable, Identifiable, Sendable {
    case d3dMetal, dxmt, dxvk, wined3d

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .d3dMetal: "D3DMetal (DirectX 11–12)"
        case .dxmt: "DXMT (DirectX 10–11)"
        case .dxvk: "DXVK (DirectX 9–11)"
        case .wined3d: "Wine Built-in"
        }
    }
}

public struct BottleSettings: Codable, Hashable, Sendable {
    public var syncMode: SyncMode = .msync
    public var graphics: GraphicsBackend = .d3dMetal
    public var metalHUD = false
    public var advertiseAVX = false
    public var retinaMode = false
    public var extraEnvironment: [String: String] = [:]

    public init() {}

    /// Every key is optional so bottles saved by older versions of Carafe keep loading as settings are added.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        syncMode = try values.decodeIfPresent(SyncMode.self, forKey: .syncMode) ?? syncMode
        graphics = try values.decodeIfPresent(GraphicsBackend.self, forKey: .graphics) ?? graphics
        metalHUD = try values.decodeIfPresent(Bool.self, forKey: .metalHUD) ?? metalHUD
        advertiseAVX = try values.decodeIfPresent(Bool.self, forKey: .advertiseAVX) ?? advertiseAVX
        retinaMode = try values.decodeIfPresent(Bool.self, forKey: .retinaMode) ?? retinaMode
        extraEnvironment = try values.decodeIfPresent([String: String].self, forKey: .extraEnvironment) ?? extraEnvironment
    }
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
    /// Programs the user added to the list by hand, as paths relative to the C: drive.
    public var pinnedPrograms: [String]?

    public init(
        id: UUID = UUID(),
        name: String,
        windowsVersion: WindowsVersion = .win10,
        settings: BottleSettings = BottleSettings(),
        created: Date = Date(),
        engineName: String? = nil,
        pinnedPrograms: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.windowsVersion = windowsVersion
        self.settings = settings
        self.created = created
        self.engineName = engineName
        self.pinnedPrograms = pinnedPrograms
    }
}
