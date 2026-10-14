import Foundation

/// Tells whether a bottle has Windows programs running, without starting Wine to ask.
public enum BottleStatus {
    /// Where the bottle's wineserver keeps its socket and lock: Wine names the folder after the
    /// prefix directory's device and inode numbers.
    public static func serverDirectory(forPrefix prefix: URL) -> URL? {
        var info = stat()
        guard stat(prefix.path, &info) == 0 else { return nil }
        let name = "server-" + String(UInt64(bitPattern: Int64(info.st_dev)), radix: 16)
            + "-" + String(info.st_ino, radix: 16)
        return URL(fileURLWithPath: "/tmp/.wine-\(getuid())").appendingPathComponent(name)
    }

    /// A running wineserver holds a write lock on its `lock` file; the file itself outlives the server,
    /// so its existence alone proves nothing.
    public static func isRunning(prefix: URL) -> Bool {
        guard let lock = serverDirectory(forPrefix: prefix)?.appendingPathComponent("lock") else { return false }
        let fd = open(lock.path, O_RDONLY)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var query = flock(l_start: 0, l_len: 0, l_pid: 0, l_type: Int16(F_WRLCK), l_whence: Int16(SEEK_SET))
        return fcntl(fd, F_GETLK, &query) == 0 && query.l_type != Int16(F_UNLCK)
    }
}
