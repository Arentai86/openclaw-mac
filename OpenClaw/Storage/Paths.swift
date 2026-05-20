import Foundation

enum Paths {
    static var isAppSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    static var openClawHomeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw", isDirectory: true)
    }

    static var defaultDataDirectory: URL {
        isAppSandboxed ? applicationSupportDirectory : openClawHomeDirectory
    }

    static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenClaw", isDirectory: true)
    }

    static var cachesDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenClaw", isDirectory: true)
    }

    static var logsDirectory: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/OpenClaw", isDirectory: true)
    }

    static var skillsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("skills", isDirectory: true)
    }

    static var preferencesFile: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Preferences/com.openclaw.app.plist")
    }

    static func ensureBaseDirectories() throws {
        var directories = [
            applicationSupportDirectory,
            applicationSupportDirectory.appendingPathComponent("data", isDirectory: true),
            applicationSupportDirectory.appendingPathComponent("config", isDirectory: true),
            skillsDirectory,
            applicationSupportDirectory.appendingPathComponent("cache", isDirectory: true),
            cachesDirectory,
            logsDirectory
        ]
        if !isAppSandboxed {
            directories.append(contentsOf: [
                openClawHomeDirectory,
                openClawHomeDirectory.appendingPathComponent("agents/main/agent", isDirectory: true),
                openClawHomeDirectory.appendingPathComponent("agents/main/sessions", isDirectory: true),
                openClawHomeDirectory.appendingPathComponent("devices", isDirectory: true),
                openClawHomeDirectory.appendingPathComponent("identity", isDirectory: true),
                openClawHomeDirectory.appendingPathComponent("logs", isDirectory: true),
                openClawHomeDirectory.appendingPathComponent("tasks", isDirectory: true)
            ])
        }
        for directory in directories {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
