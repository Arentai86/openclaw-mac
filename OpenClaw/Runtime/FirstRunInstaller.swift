import Foundation

struct FirstRunInstaller {
    func installOrMigrateIfNeeded() throws -> Bool {
        try Paths.ensureBaseDirectories()

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let marker = Paths.applicationSupportDirectory.appendingPathComponent(".installed")
        let isFirstRun = !FileManager.default.fileExists(atPath: marker.path)

        if isFirstRun {
            try copyDefaultRuntimeDataIfPresent()
        }

        let record = InstallationRecord(version: version, installedAt: Date())
        let data = try JSONEncoder.installRecordEncoder.encode(record)
        try data.write(to: marker, options: .atomic)
        return isFirstRun
    }

    private func copyDefaultRuntimeDataIfPresent() throws {
        let defaults = Bundle.main.resourceURL?
            .appendingPathComponent("runtime/server/defaults", isDirectory: true)
        guard let defaults, FileManager.default.fileExists(atPath: defaults.path) else { return }

        let target = Paths.applicationSupportDirectory.appendingPathComponent("data", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let children = try FileManager.default.contentsOfDirectory(at: defaults, includingPropertiesForKeys: nil)
        for item in children {
            let destination = target.appendingPathComponent(item.lastPathComponent)
            if !FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.copyItem(at: item, to: destination)
            }
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

