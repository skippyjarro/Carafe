import Foundation

public enum WineEnvironment {
    /// Environment for a wine process running inside `bottle`. Pure, so it can be unit tested.
    public static func build(
        bottle: Bottle,
        prefix: URL,
        engine: WineEngine,
        base: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var env = base
        env["WINEPREFIX"] = prefix.path
        env["WINEDEBUG"] = "fixme-all"
        env["PATH"] = engine.binDirectory.path + ":" + (base["PATH"] ?? "/usr/bin:/bin")

        if let support = engine.support {
            // Gaming engines load their unix libraries (FreeType, GnuTLS, MoltenVK, D3DMetal) by bare name.
            var libraries = [support.path]
            if let d3dMetal = engine.d3dMetal {
                let external = d3dMetal.appendingPathComponent("external")
                libraries.append(external.path)
                env["WINEDLLPATH_PREPEND"] = d3dMetal.appendingPathComponent("wine").path
                // CrossOver's loader only enables its D3DMetal support when told where this library is.
                env["CX_APPLEGPTK_LIBD3DSHARED_PATH"] = external.appendingPathComponent("libd3dshared.dylib").path
            }
            env["DYLD_FALLBACK_LIBRARY_PATH"] = (libraries + ["/usr/lib"]).joined(separator: ":")
            if let shim = engine.shim { env["DYLD_INSERT_LIBRARIES"] = shim.path }
        }

        switch bottle.settings.syncMode {
        case .msync: env["WINEMSYNC"] = "1"
        case .esync: env["WINEESYNC"] = "1"
        case .none: break
        }
        if bottle.settings.metalHUD { env["MTL_HUD_ENABLED"] = "1" }
        if bottle.settings.advertiseAVX { env["ROSETTA_ADVERTISE_AVX"] = "1" }

        env.merge(bottle.settings.extraEnvironment) { _, user in user }
        return env
    }
}

public struct WineRunner: Sendable {
    public let engine: WineEngine
    public let repository: BottleRepository

    public init(engine: WineEngine, repository: BottleRepository = BottleRepository()) {
        self.engine = engine
        self.repository = repository
    }

    public func logFile(for bottle: Bottle) -> URL {
        BottleLogs.file(for: bottle.id)
    }

    /// Arguments that open any Windows file (.exe, .msi, .bat, .lnk) given its macOS path.
    public static func openArguments(for file: URL) -> [String] {
        ["start", "/unix", file.path]
    }

    func makeProcess(bottle: Bottle, executable: URL, arguments: [String]) throws -> Process {
        let fm = FileManager.default
        let prefix = repository.prefix(for: bottle)
        try fm.createDirectory(at: prefix, withIntermediateDirectories: true)
        CompatibilityFixes.apply(driveC: repository.driveC(for: bottle))

        let log = logFile(for: bottle)
        try fm.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        BottleLogs.rotateIfNeeded(log)
        if !fm.fileExists(atPath: log.path) { fm.createFile(atPath: log.path, contents: nil) }
        let handle = try FileHandle(forWritingTo: log)
        try handle.seekToEnd()
        let header = "\n--- \(Date()) \(executable.lastPathComponent) \(arguments.joined(separator: " "))\n"
        try handle.write(contentsOf: Data(header.utf8))

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = WineEnvironment.build(bottle: bottle, prefix: prefix, engine: engine)
        process.currentDirectoryURL = prefix
        process.standardOutput = handle
        process.standardError = handle
        return process
    }

    /// Starts wine and returns immediately; used for launching programs.
    @discardableResult
    public func launch(_ arguments: [String], in bottle: Bottle) throws -> Process {
        let process = try makeProcess(bottle: bottle, executable: engine.wine, arguments: arguments)
        try process.run()
        return process
    }

    /// Runs wine to completion; used for setup steps that must finish in order.
    public func run(_ arguments: [String], in bottle: Bottle) async throws {
        let status = try await wait(makeProcess(bottle: bottle, executable: engine.wine, arguments: arguments))
        guard status == 0 else {
            throw WineError.commandFailed(command: arguments.joined(separator: " "), status: status)
        }
    }

    /// Stops every Windows process in the bottle and waits until the session has fully shut down.
    /// Launching into a session that is still tearing down can leave programs without a display driver.
    /// Processes that ignore the polite request are force-killed; if even that doesn't end the session
    /// within `forceTimeout`, this throws rather than waiting forever.
    public func killAll(in bottle: Bottle, timeout: TimeInterval = 15, forceTimeout: TimeInterval = 10) async throws {
        // Each signal gets its own bounded wait; `wineserver -k` exits non-zero when nothing is running.
        for (signal, limit) in [("-k", timeout), ("-k9", forceTimeout)] {
            try await wait(makeProcess(bottle: bottle, executable: engine.wineserver, arguments: [signal]))
            let waiter = try makeProcess(bottle: bottle, executable: engine.wineserver, arguments: ["-w"])
            if try await wait(waiter, timeout: limit) != nil { return }
        }
        throw WineError.shutdownTimedOut
    }

    @discardableResult
    private func wait(_ process: Process) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    /// Like `wait`, but stops the process and returns nil if it outlives `timeout`.
    private func wait(_ process: Process, timeout: TimeInterval) async throws -> Int32? {
        let deadline = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: deadline)
        defer { deadline.cancel() }
        let status = try await wait(process)
        return process.terminationReason == .uncaughtSignal ? nil : status
    }
}

public enum WineError: LocalizedError, Equatable {
    case commandFailed(command: String, status: Int32)
    case shutdownTimedOut

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let command, let status):
            "“\(command)” failed (exit code \(status)). Use Show Log for details."
        case .shutdownTimedOut:
            "The bottle's programs did not quit. Try Quit All Programs again, or restart your Mac."
        }
    }
}
