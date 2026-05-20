import Darwin
import Foundation

struct FirstRunInstaller {
    func installOrMigrateIfNeeded() throws -> Bool {
        try Paths.ensureBaseDirectories()
        try normalizeDataLocation()
        try migrateLegacyStateIfPresent()

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let marker = Paths.applicationSupportDirectory.appendingPathComponent(".installed")
        let isFreshInstall = !FileManager.default.fileExists(atPath: marker.path)

        if isFreshInstall {
            try copyDefaultRuntimeDataIfPresent()
        }

        let record = InstallationRecord(version: version, installedAt: Date())
        let data = try JSONEncoder.installRecordEncoder.encode(record)
        try data.write(to: marker, options: .atomic)

        // The wizard "first run" flag is independent of the install marker so the wizard
        // re-appears if the user closed it without finishing.
        let wizardCompleted = UserDefaults.standard.bool(forKey: AppSettingKeys.wizardCompleted)
        return !wizardCompleted
    }

    func markWizardCompleted() {
        UserDefaults.standard.set(true, forKey: AppSettingKeys.wizardCompleted)
    }

    private func copyDefaultRuntimeDataIfPresent() throws {
        let defaults = Bundle.main.resourceURL?
            .appendingPathComponent("runtime/server/defaults", isDirectory: true)
        guard let defaults, FileManager.default.fileExists(atPath: defaults.path) else { return }

        let target = Paths.defaultDataDirectory
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let children = try FileManager.default.contentsOfDirectory(at: defaults, includingPropertiesForKeys: nil)
        for item in children {
            let destination = target.appendingPathComponent(item.lastPathComponent)
            if !FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.copyItem(at: item, to: destination)
            }
        }
    }

    private func normalizeDataLocation() throws {
        let defaults = UserDefaults.standard
        let stored = defaults.string(forKey: AppSettingKeys.dataLocation)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let legacyDefault = Paths.applicationSupportDirectory.path
        if stored == nil || stored == "" || stored == legacyDefault {
            defaults.set(Paths.defaultDataDirectory.path, forKey: AppSettingKeys.dataLocation)
        }
        try FileManager.default.createDirectory(at: AppSettings.dataLocationURL, withIntermediateDirectories: true)
    }

    private func migrateLegacyStateIfPresent() throws {
        guard !Paths.isAppSandboxed else { return }

        let legacyState = Paths.applicationSupportDirectory.appendingPathComponent("state", isDirectory: true)
        guard FileManager.default.fileExists(atPath: legacyState.path) else { return }

        let destinationRoot = Paths.defaultDataDirectory
        try FileManager.default.createDirectory(at: destinationRoot, withIntermediateDirectories: true)

        let fileCopies = [
            ("openclaw.json", "openclaw.json"),
            ("agents/main/agent/auth-profiles.json", "agents/main/agent/auth-profiles.json"),
            ("agents/main/agent/auth-state.json", "agents/main/agent/auth-state.json"),
            ("tasks/runs.sqlite", "tasks/runs.sqlite")
        ]

        for (sourceRelativePath, destinationRelativePath) in fileCopies {
            let source = legacyState.appendingPathComponent(sourceRelativePath)
            let destination = destinationRoot.appendingPathComponent(destinationRelativePath)
            try copyItemIfMissing(from: source, to: destination, secure: source.pathExtension == "json")
        }

        try copyDirectoryContentsIfPresent(
            from: legacyState.appendingPathComponent("agents/main/sessions", isDirectory: true),
            to: destinationRoot.appendingPathComponent("agents/main/sessions", isDirectory: true)
        )
    }

    private func copyDirectoryContentsIfPresent(from source: URL, to destination: URL) throws {
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let children = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        for child in children {
            let target = destination.appendingPathComponent(child.lastPathComponent)
            try copyItemIfMissing(from: child, to: target, secure: child.pathExtension == "json")
        }
    }

    private func copyItemIfMissing(from source: URL, to destination: URL, secure: Bool) throws {
        guard FileManager.default.fileExists(atPath: source.path),
              !FileManager.default.fileExists(atPath: destination.path) else {
            return
        }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: source, to: destination)
        if secure {
            chmod(destination.path, S_IRUSR | S_IWUSR)
        }
    }
}

struct InstallationRecord: Codable {
    let version: String
    let installedAt: Date
}

extension JSONEncoder {
    static var installRecordEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
