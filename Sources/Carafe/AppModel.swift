import AppKit
import CarafeCore
import Observation

enum WineTool: String, CaseIterable, Identifiable {
    case winecfg, regedit, control, taskmgr, explorer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .winecfg: "Wine Config"
        case .regedit: "Registry Editor"
        case .control: "Control Panel"
        case .taskmgr: "Task Manager"
        case .explorer: "File Explorer"
        }
    }
}

@MainActor
@Observable
final class AppModel {
    var engines: [WineEngine] = []
    var bottles: [Bottle] = []
    var selection: Bottle.ID?
    var busy: Set<Bottle.ID> = []
    var errorMessage: String?
    var installing = false
    var installLog = ""

    let repository = BottleRepository()

    init() {
        reload()
        selection = bottles.first?.id
        BottleLogs.removeOrphans(bottles: repository.root)
    }

    var selectedBottle: Bottle? { bottles.first { $0.id == selection } }

    /// The engine new bottles are created with.
    var engine: WineEngine? { engines.first }

    /// The engine a bottle was created with, falling back to the preferred one for bottles that don't record it.
    func engine(for bottle: Bottle) -> WineEngine? {
        guard let name = bottle.engineName else { return engine }
        return engines.first { $0.name == name }
    }

    func reload() {
        engines = WineLocator.locateAll()
        bottles = repository.loadAll()
    }

    func programs(in bottle: Bottle) -> [Program] {
        ProgramScanner.scan(driveC: repository.driveC(for: bottle))
    }

    // MARK: Bottles

    func createBottle(name: String, version: WindowsVersion) async {
        let bottle = Bottle(name: name, windowsVersion: version, engineName: engine?.name)
        await perform(on: bottle) { runner in
            try self.repository.save(bottle)
            self.bottles.append(bottle)
            self.selection = bottle.id
            try await runner.run(["wineboot", "--init"], in: bottle)
            try await runner.run(["winecfg", "/v", version.rawValue], in: bottle)
        }
    }

    func update(_ bottle: Bottle) {
        guard let index = bottles.firstIndex(where: { $0.id == bottle.id }) else { return }
        let old = bottles[index]
        bottles[index] = bottle
        Task {
            await perform(on: bottle) { runner in
                try self.repository.save(bottle)
                // Windows version and Retina mode live in the bottle's registry, not the environment.
                if old.windowsVersion != bottle.windowsVersion {
                    try await runner.run(["winecfg", "/v", bottle.windowsVersion.rawValue], in: bottle)
                }
                if old.settings.retinaMode != bottle.settings.retinaMode {
                    try await runner.run([
                        "reg", "add", #"HKCU\Software\Wine\Mac Driver"#, "/v", "RetinaMode",
                        "/t", "REG_SZ", "/d", bottle.settings.retinaMode ? "Y" : "N", "/f",
                    ], in: bottle)
                }
            }
        }
    }

    /// Stops the bottle's processes and moves it to the Trash.
    func delete(_ bottle: Bottle) async {
        busy.insert(bottle.id)
        defer { busy.remove(bottle.id) }
        // A bottle whose engine is gone has nothing running that we could stop, but must still be deletable.
        if let engine = engine(for: bottle) {
            try? await WineRunner(engine: engine, repository: repository).killAll(in: bottle)
        }
        do {
            try FileManager.default.trashItem(at: repository.prefix(for: bottle), resultingItemURL: nil)
            BottleLogs.remove(for: bottle.id)
            bottles.removeAll { $0.id == bottle.id }
            if selection == bottle.id { selection = bottles.first?.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Running things

    func open(_ file: URL, in bottle: Bottle) {
        launch(WineRunner.openArguments(for: file), in: bottle)
    }

    func runTool(_ tool: WineTool, in bottle: Bottle) {
        launch([tool.rawValue], in: bottle)
    }

    func killAll(in bottle: Bottle) {
        Task { await perform(on: bottle) { try await $0.killAll(in: bottle) } }
    }

    func showDriveC(of bottle: Bottle) {
        NSWorkspace.shared.open(repository.driveC(for: bottle))
    }

    func showLog(of bottle: Bottle) {
        guard let engine = engine(for: bottle) else { return }
        NSWorkspace.shared.open(WineRunner(engine: engine).logFile(for: bottle))
    }

    private func launch(_ arguments: [String], in bottle: Bottle) {
        guard let engine = engine(for: bottle) else {
            errorMessage = missingEngineMessage(for: bottle)
            return
        }
        do {
            try WineRunner(engine: engine, repository: repository).launch(arguments, in: bottle)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Runs a multi-step operation against a bottle, showing it as busy and surfacing any error.
    private func perform(on bottle: Bottle, _ work: (WineRunner) async throws -> Void) async {
        guard let engine = engine(for: bottle) else {
            errorMessage = missingEngineMessage(for: bottle)
            return
        }
        busy.insert(bottle.id)
        defer { busy.remove(bottle.id) }
        do {
            try await work(WineRunner(engine: engine, repository: repository))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func missingEngineMessage(for bottle: Bottle) -> String {
        "“\(bottle.name)” was created with \(bottle.engineName ?? "a Wine engine") which is no longer installed."
    }

    // MARK: Wine install

    private static var installScript: URL? {
        Bundle.main.url(forResource: "install-wine", withExtension: "sh")
    }

    func installWine() async {
        guard let script = Self.installScript else {
            errorMessage = "Installer script missing from the app bundle. Run Scripts/install-wine.sh manually."
            return
        }
        installing = true
        installLog = ""
        defer { installing = false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in self?.installLog += text }
        }

        let status: Int32 = await withCheckedContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(returning: -1)
            }
        }
        pipe.fileHandleForReading.readabilityHandler = nil

        reload()
        if status != 0 || engine == nil {
            errorMessage = "Wine install did not complete. See the output for details."
        }
    }
}
