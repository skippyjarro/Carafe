import XCTest
@testable import CarafeCore

final class CarafeCoreTests: XCTestCase {
    private var temp: URL!

    override func setUpWithError() throws {
        temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: temp)
    }

    private func touch(_ path: String) throws {
        let url = temp.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: url)
    }

    private let engine = WineEngine(
        name: "Test",
        binDirectory: URL(fileURLWithPath: "/engine/bin"),
        wine: URL(fileURLWithPath: "/engine/bin/wine"))

    func testEnvironmentReflectsBottleSettings() {
        var bottle = Bottle(name: "Games")
        bottle.settings.syncMode = .esync
        bottle.settings.metalHUD = true
        bottle.settings.extraEnvironment = ["WINEDEBUG": "-all"]

        let env = WineEnvironment.build(
            bottle: bottle, prefix: URL(fileURLWithPath: "/p"), engine: engine, base: ["PATH": "/usr/bin"])

        XCTAssertEqual(env["WINEPREFIX"], "/p")
        XCTAssertEqual(env["PATH"], "/engine/bin:/usr/bin")
        XCTAssertEqual(env["WINEESYNC"], "1")
        XCTAssertNil(env["WINEMSYNC"])
        XCTAssertEqual(env["MTL_HUD_ENABLED"], "1")
        XCTAssertNil(env["ROSETTA_ADVERTISE_AVX"])
        XCTAssertEqual(env["WINEDEBUG"], "-all", "user-supplied variables win")
    }

    func testLocatorListsInstalledEnginesBestFirst() {
        let candidates = [
            EngineCandidate(name: "Missing", binDirectory: URL(fileURLWithPath: "/a/bin")),
            EngineCandidate(
                name: "Gaming", binDirectory: URL(fileURLWithPath: "/b/wine/bin"),
                support: URL(fileURLWithPath: "/b/Frameworks")),
            EngineCandidate(name: "Plain", binDirectory: URL(fileURLWithPath: "/c/bin")),
        ]
        let found = WineLocator.locateAll(in: candidates) { $0 == "/b/wine/bin/wine" || $0 == "/c/bin/wine64" }
        XCTAssertEqual(found.map(\.name), ["Gaming", "Plain"])
        XCTAssertEqual(found.first?.wine.path, "/b/wine/bin/wine")
        XCTAssertEqual(found.first?.support?.path, "/b/Frameworks")
        XCTAssertEqual(found.last?.wine.path, "/c/bin/wine64")
        XCTAssertTrue(WineLocator.locateAll(in: candidates) { _ in false }.isEmpty)
    }

    func testManagedEngineNamesKeepVersionDots() throws {
        try touch("Engines/CrossOver 24.0.7/wine/bin/wine")
        try touch("Engines/Wine Staging.app/Contents/Resources/wine/bin/wine")
        let names = Set(WineLocator.candidates(engines: temp.appendingPathComponent("Engines"), home: temp).map(\.name))
        XCTAssertTrue(names.contains("CrossOver 24.0.7"))
        XCTAssertTrue(names.contains("Wine Staging"))
    }

    func testGamingEngineEnvironmentPointsAtBundledLibraries() {
        let gaming = WineEngine(
            name: "Gaming", binDirectory: URL(fileURLWithPath: "/b/wine/bin"),
            wine: URL(fileURLWithPath: "/b/wine/bin/wine"), support: URL(fileURLWithPath: "/b/Frameworks"))
        let env = WineEnvironment.build(
            bottle: Bottle(name: "Games"), prefix: URL(fileURLWithPath: "/p"), engine: gaming, base: [:])
        XCTAssertEqual(env["DYLD_FALLBACK_LIBRARY_PATH"], "/b/Frameworks:/usr/lib")
        XCTAssertNil(env["WINEDLLPATH_PREPEND"], "no D3DMetal on disk at this fake path")

        let plain = WineEnvironment.build(
            bottle: Bottle(name: "Games"), prefix: URL(fileURLWithPath: "/p"), engine: engine, base: [:])
        XCTAssertNil(plain["DYLD_FALLBACK_LIBRARY_PATH"])
    }

    func testGraphicsSettingChoosesTheRenderer() throws {
        try touch("Frameworks/renderer/d3dmetal/external/D3DMetal.framework/D3DMetal")
        try touch("Frameworks/renderer/d3dmetal/wine/x86_64-windows/d3d11.dll")
        try touch("Frameworks/renderer/dxmt/wine/x86_64-windows/d3d11.dll")
        let support = temp.appendingPathComponent("Frameworks")
        let gaming = WineEngine(
            name: "Gaming", binDirectory: URL(fileURLWithPath: "/b/wine/bin"),
            wine: URL(fileURLWithPath: "/b/wine/bin/wine"), support: support)
        XCTAssertEqual(gaming.graphicsBackends, [.d3dMetal, .dxmt, .wined3d], "DXVK isn't on disk")

        func env(_ graphics: GraphicsBackend) -> [String: String] {
            var bottle = Bottle(name: "Games")
            bottle.settings.graphics = graphics
            return WineEnvironment.build(bottle: bottle, prefix: URL(fileURLWithPath: "/p"), engine: gaming, base: [:])
        }
        XCTAssertEqual(env(.d3dMetal)["WINEDLLPATH_PREPEND"], support.appendingPathComponent("renderer/d3dmetal/wine").path)
        XCTAssertNotNil(env(.d3dMetal)["CX_APPLEGPTK_LIBD3DSHARED_PATH"])
        XCTAssertEqual(env(.dxmt)["WINEDLLPATH_PREPEND"], support.appendingPathComponent("renderer/dxmt/wine").path)
        XCTAssertNil(env(.dxmt)["CX_APPLEGPTK_LIBD3DSHARED_PATH"])
        XCTAssertNil(env(.dxvk)["WINEDLLPATH_PREPEND"], "a missing layer falls back to Wine's own")
        XCTAssertNil(env(.wined3d)["WINEDLLPATH_PREPEND"])
        XCTAssertNil(env(.d3dMetal)["WINE_SIMULATE_WRITECOPY"], "only engines with Carafe's plugin")
    }

    func testPluginEngineGetsThirtyTwoBitFallbackAndWriteCopy() throws {
        try touch("E/wine/bin/wine")
        try touch("E/wine/lib/wine/x86_64-unix/cxcompatdb.so")
        try touch("E/Frameworks/renderer/d3dmetal/external/D3DMetal.framework/D3DMetal")
        try touch("E/Frameworks/renderer/d3dmetal/wine/x86_64-windows/d3d11.dll")
        try touch("E/Frameworks/renderer/dxmt/wine/i386-windows/d3d11.dll")
        let root = temp.appendingPathComponent("E")
        let engine = WineEngine(
            name: "Plugin", binDirectory: root.appendingPathComponent("wine/bin"),
            wine: root.appendingPathComponent("wine/bin/wine"), support: root.appendingPathComponent("Frameworks"))
        XCTAssertTrue(engine.hasGraphicsPlugin)

        func env(_ graphics: GraphicsBackend) -> [String: String] {
            var bottle = Bottle(name: "Games")
            bottle.settings.graphics = graphics
            return WineEnvironment.build(bottle: bottle, prefix: URL(fileURLWithPath: "/p"), engine: engine, base: [:])
        }
        let renderers = root.appendingPathComponent("Frameworks/renderer")
        let d3dMetal = renderers.appendingPathComponent("d3dmetal/wine").path
        let dxmt = renderers.appendingPathComponent("dxmt/wine").path
        XCTAssertEqual(env(.d3dMetal)["WINEDLLPATH_PREPEND"], d3dMetal + ":" + dxmt)
        XCTAssertEqual(env(.dxmt)["WINEDLLPATH_PREPEND"], dxmt)
        XCTAssertEqual(env(.d3dMetal)["WINE_SIMULATE_WRITECOPY"], "1")
    }

    func testPinnedProgramsJoinTheScan() throws {
        try touch("ProgramData/Microsoft/Windows/Start Menu/Programs/Steam/Steam.lnk")
        try touch("Games/Kakarot/AT.exe")
        let pinned = try XCTUnwrap(ProgramScanner.relativePath(
            of: temp.appendingPathComponent("Games/Kakarot/AT.exe"), in: temp))
        XCTAssertEqual(pinned, "Games/Kakarot/AT.exe")
        XCTAssertNil(ProgramScanner.relativePath(of: URL(fileURLWithPath: "/Applications/x.exe"), in: temp))

        let programs = ProgramScanner.scan(driveC: temp, pinned: [pinned, "Games/Gone/missing.exe"])
        XCTAssertEqual(programs.map(\.name), ["AT", "Steam"])
        XCTAssertEqual(programs.map(\.isPinned), [true, false])
    }

    func testIdleBottleIsNotRunning() {
        XCTAssertFalse(BottleStatus.isRunning(prefix: temp))
        XCTAssertFalse(BottleStatus.isRunning(prefix: temp.appendingPathComponent("missing")))
    }

    func testBottleWithoutEngineNameStillDecodes() throws {
        let json = #"{"created":0,"id":"E7DA844D-1A7A-4DB4-8C7B-12B3A15C545C","name":"Old","settings":{"advertiseAVX":false,"extraEnvironment":{},"metalHUD":false,"retinaMode":false,"syncMode":"msync"},"windowsVersion":"win11"}"#
        let bottle = try JSONDecoder().decode(Bottle.self, from: Data(json.utf8))
        XCTAssertNil(bottle.engineName)
        XCTAssertNil(bottle.pinnedPrograms)

        let older = #"{"created":0,"id":"E7DA844D-1A7A-4DB4-8C7B-12B3A15C545C","name":"Old","settings":{"syncMode":"esync"},"windowsVersion":"win11"}"#
        let settings = try JSONDecoder().decode(Bottle.self, from: Data(older.utf8)).settings
        XCTAssertEqual(settings.syncMode, .esync)
        XCTAssertEqual(settings.graphics, .d3dMetal, "settings added later take their defaults")
    }

    func testBattleNetFixLinksExecutableIntoVersionFolders() throws {
        try touch("Program Files (x86)/Battle.net/Battle.net.exe")
        try touch("Program Files (x86)/Battle.net/Battle.net.17896/battle.net.dll")
        try touch("Program Files (x86)/Battle.net/Battle.net.18000/battle.net.dll")
        try touch("Program Files (x86)/Battle.net/Launcher.db")

        CompatibilityFixes.apply(driveC: temp)
        CompatibilityFixes.apply(driveC: temp)  // safe to repeat

        let install = temp.appendingPathComponent("Program Files (x86)/Battle.net")
        for version in ["Battle.net.17896", "Battle.net.18000"] {
            let link = install.appendingPathComponent(version).appendingPathComponent("Battle.net.exe").path
            XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link), "../Battle.net.exe")
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: install.path).count, 4)
    }

    func testBattleNetFixDoesNothingWithoutBattleNet() throws {
        try touch("Program Files/Game/game.exe")
        CompatibilityFixes.apply(driveC: temp)
        XCTAssertFalse(FileManager.default.fileExists(atPath: temp.appendingPathComponent("Program Files (x86)").path))
    }

    func testRepositoryRoundTrip() throws {
        let repo = BottleRepository(root: temp)
        var bottle = Bottle(name: "Office", windowsVersion: .win11)
        bottle.settings.retinaMode = true
        try repo.save(bottle)
        XCTAssertEqual(repo.loadAll(), [bottle])
    }

    func testScannerPrefersShortcutsAndDropsNoise() throws {
        try touch("ProgramData/Microsoft/Windows/Start Menu/Programs/Notepad++/Notepad++.lnk")
        try touch("ProgramData/Microsoft/Windows/Start Menu/Programs/Notepad++/Uninstall Notepad++.lnk")
        try touch("Program Files/Notepad++/notepad++.exe")
        XCTAssertEqual(ProgramScanner.scan(driveC: temp).map(\.name), ["Notepad++"])
        XCTAssertEqual(ProgramScanner.scan(driveC: temp).first?.url.pathExtension, "lnk")
    }

    func testScannerFallsBackToExecutables() throws {
        try touch("Program Files/Game/game.exe")
        try touch("Program Files/Game/unins000.exe")
        try touch("Program Files (x86)/Tool/bin/tool.exe")
        try touch("Program Files/Game/a/b/c/d/deep.exe")
        XCTAssertEqual(ProgramScanner.scan(driveC: temp).map(\.name), ["game", "tool"])
    }

    func testLogsRotateAndOrphansAreRemoved() throws {
        let logs = temp.appendingPathComponent("Logs")
        let bottles = temp.appendingPathComponent("Bottles")
        let kept = UUID(), gone = UUID()
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: bottles.appendingPathComponent(kept.uuidString), withIntermediateDirectories: true)

        let log = BottleLogs.file(for: kept, in: logs)
        try Data(count: 100).write(to: log)
        BottleLogs.rotateIfNeeded(log, limit: 200)
        XCTAssertTrue(FileManager.default.fileExists(atPath: log.path), "small logs stay put")
        BottleLogs.rotateIfNeeded(log, limit: 50)
        try Data(count: 60).write(to: log)
        BottleLogs.rotateIfNeeded(log, limit: 50)  // replaces the previous .old.log

        try Data().write(to: BottleLogs.file(for: gone, in: logs))
        try Data().write(to: BottleLogs.rotated(BottleLogs.file(for: gone, in: logs)))
        try Data().write(to: logs.appendingPathComponent("notes.log"))
        BottleLogs.removeOrphans(bottles: bottles, in: logs)

        XCTAssertEqual(
            Set(try FileManager.default.contentsOfDirectory(atPath: logs.path)),
            ["\(kept.uuidString).old.log", "notes.log"])

        BottleLogs.remove(for: kept, in: logs)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: logs.path), ["notes.log"])
    }
}
