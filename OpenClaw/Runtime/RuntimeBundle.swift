import Foundation

enum RuntimeError: LocalizedError {
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case let .missingResource(path):
            return "Missing bundled runtime resource: \(path)"
        }
    }
}

struct RuntimeBundle {
    var runtimeDirectory: URL {
        Bundle.main.resourceURL?.appendingPathComponent("runtime", isDirectory: true)
            ?? Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/runtime", isDirectory: true)
    }

    func nodeExecutableURL() throws -> URL {
        if !AppSettings.customNodePath.isEmpty {
            let custom = URL(fileURLWithPath: AppSettings.customNodePath)
            if FileManager.default.isExecutableFile(atPath: custom.path) {
                return custom
            }
        }

        let archNode = runtimeDirectory
            .appendingPathComponent("node-\(architectureName)", isDirectory: true)
            .appendingPathComponent("bin/node")
        if FileManager.default.isExecutableFile(atPath: archNode.path) {
            return archNode
        }

        let fallback = runtimeDirectory.appendingPathComponent("node/bin/node")
        if FileManager.default.isExecutableFile(atPath: fallback.path) {
            return fallback
        }

        throw RuntimeError.missingResource("runtime/node-\(architectureName)/bin/node")
    }

    func serverEntryPointURL() throws -> URL {
        let candidates = [
            runtimeDirectory.appendingPathComponent("server/dist/index.js"),
            runtimeDirectory.appendingPathComponent("server/index.js"),
            runtimeDirectory.appendingPathComponent("server/server.js")
        ]
        guard let entry = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw RuntimeError.missingResource("runtime/server/index.js")
        }
        return entry
    }

    func serverArguments(port: Int, dataDirectory: URL, tokenFile: URL) throws -> [String] {
        [
            try serverEntryPointURL().path,
            "--host=127.0.0.1",
            "--port=\(port)",
            "--data-dir=\(dataDirectory.path)",
            "--auth-token-file=\(tokenFile.path)"
        ]
    }

    func serverEnvironment(port: Int, token: String) -> [String: String] {
        var environment = AppSettings.environmentVariables
        let authEnvironment = AuthProviderCatalog.environmentVariables(
            store: KeychainStore(),
            enabledProviderIDs: AppSettings.enabledAuthProviderIDs
        )
        environment.merge(authEnvironment) { _, new in new }
        environment["OPENCLAW_HOST"] = "127.0.0.1"
        environment["OPENCLAW_PORT"] = "\(port)"
        environment["OPENCLAW_AUTH_TOKEN"] = token
        environment["OPENCLAW_CORS_ORIGIN"] = "http://localhost:\(port)"
        environment["NODE_ENV"] = "production"
        return environment
    }

    private var architectureName: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x64"
        #else
        return ProcessInfo.processInfo.machineHardwareName
        #endif
    }
}

extension ProcessInfo {
    var machineHardwareName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(String(UnicodeScalar(UInt8(value))))
        }
    }
}
