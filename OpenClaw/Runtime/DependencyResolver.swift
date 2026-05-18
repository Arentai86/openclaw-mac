import Foundation

struct DependencyResolver {
    let runtime: RuntimeBundle

    func validate() throws {
        _ = try runtime.nodeExecutableURL()
        _ = try runtime.serverEntryPointURL()
    }

    func statusItems() -> [DependencyStatus] {
        [
            DependencyStatus(name: "Bundled Node", isAvailable: (try? runtime.nodeExecutableURL()) != nil),
            DependencyStatus(name: "OpenClaw server", isAvailable: (try? runtime.serverEntryPointURL()) != nil),
            DependencyStatus(name: "Application Support", isAvailable: FileManager.default.isWritableFile(atPath: Paths.applicationSupportDirectory.path))
        ]
    }
}

struct DependencyStatus: Identifiable {
    let id = UUID()
    let name: String
    let isAvailable: Bool
}

