import AppKit
import Foundation

struct Uninstaller {
    func uninstall() throws {
        try? LaunchAtLogin.setEnabled(false)

        let store = KeychainStore()
        store.removeAllKnownItems(keys: ["OPENAI_API_KEY", "ANTHROPIC_API_KEY"] + AuthProviderCatalog.allKeychainKeys)

        let urls = [
            Paths.applicationSupportDirectory,
            Paths.cachesDirectory,
            Paths.logsDirectory,
            Paths.preferencesFile
        ]

        for url in urls {
            try removeIfSafe(url)
        }

        NSWorkspace.shared.recycle([Bundle.main.bundleURL]) { _, error in
            if let error {
                NSLog("Failed to move app to Trash: \(error.localizedDescription)")
            }
            NSApp.terminate(nil)
        }
    }

    private func removeIfSafe(_ url: URL) throws {
        let standardized = url.standardizedFileURL
        guard FileManager.default.fileExists(atPath: standardized.path) else { return }
        guard isAllowedRemovalTarget(standardized) else {
            throw UninstallError.unsafePath(standardized.path)
        }
        try FileManager.default.removeItem(at: standardized)
    }

    private func isAllowedRemovalTarget(_ url: URL) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let path = url.path
        let allowedPrefixes = [
            home + "/Library/Application Support/OpenClaw",
            home + "/Library/Caches/OpenClaw",
            home + "/Library/Logs/OpenClaw",
            home + "/Library/Preferences/com.openclaw.app.plist"
        ]
        return allowedPrefixes.contains { path == $0 || path.hasPrefix($0 + "/") }
    }
}

enum UninstallError: LocalizedError {
    case unsafePath(String)

    var errorDescription: String? {
        switch self {
        case let .unsafePath(path):
            return "Refusing to remove unsafe path during uninstall: \(path)"
        }
    }
}
