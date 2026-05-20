import Darwin
import Foundation

enum RuntimeError: LocalizedError {
    case missingResource(String)
    case placeholderRuntime

    var errorDescription: String? {
        switch self {
        case let .missingResource(path):
            return "Missing bundled runtime resource: \(path)"
        case .placeholderRuntime:
            return "OpenClaw runtime is not installed yet. Choose a real runtime before starting the server."
        }
    }
}

struct RuntimeManifest: Decodable {
    let version: String?
    let node: String?
    let source: String?
    let kind: String?
    let runtime: String?
    let fallback: Bool?
    let placeholder: Bool?
}

struct RuntimeBundle {
    /// Application Support is checked first so a user-installed runtime overrides the .app bundle.
    var userInstalledRuntimeDirectory: URL {
        Paths.applicationSupportDirectory.appendingPathComponent("runtime", isDirectory: true)
    }

    var bundledRuntimeDirectory: URL {
        Bundle.main.resourceURL?.appendingPathComponent("runtime", isDirectory: true)
            ?? Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/runtime", isDirectory: true)
    }

    /// Returns the directory that actually contains the runtime to use, preferring the
    /// user-installed copy when it is not the smoke-test placeholder.
    var runtimeDirectory: URL {
        if userInstalledRuntimeIsUsable {
            return userInstalledRuntimeDirectory
        }
        return bundledRuntimeDirectory
    }

    var requiresRuntimeSetup: Bool {
        !isUsableRuntime(at: runtimeDirectory)
    }

    var bundledRuntimeIsUsable: Bool {
        isUsableRuntime(at: bundledRuntimeDirectory)
    }

    var bundledNodeIsAvailable: Bool {
        hasNode(in: bundledRuntimeDirectory)
    }

    var userInstalledRuntimeIsUsable: Bool {
        isUsableRuntime(at: userInstalledRuntimeDirectory)
    }

    func nodeExecutableURL() throws -> URL {
        if !AppSettings.customNodePath.isEmpty {
            let custom = URL(fileURLWithPath: AppSettings.customNodePath)
            if FileManager.default.isExecutableFile(atPath: custom.path) {
                return custom
            }
        }

        // Try user-installed first, then bundled.
        for base in [userInstalledRuntimeDirectory, bundledRuntimeDirectory] {
            let archNode = base
                .appendingPathComponent("node-\(architectureName)", isDirectory: true)
                .appendingPathComponent("bin/node")
            if FileManager.default.isExecutableFile(atPath: archNode.path) {
                return archNode
            }
            let fallback = base.appendingPathComponent("node/bin/node")
            if FileManager.default.isExecutableFile(atPath: fallback.path) {
                return fallback
            }
        }

        throw RuntimeError.missingResource("runtime/node-\(architectureName)/bin/node")
    }

    func serverEntryPointURL() throws -> URL {
        if let entry = serverEntryPointURL(in: runtimeDirectory) {
            return entry
        }
        throw RuntimeError.missingResource("runtime/server/index.js")
    }

    func serverArguments(port: Int, dataDirectory: URL, tokenFile: URL, token: String) throws -> [String] {
        let entry = try serverEntryPointURL()
        if isOpenClawPackageEntry(entry) {
            return [
                entry.path,
                "gateway",
                "--port", "\(port)",
                "--bind", "loopback",
                "--auth", "none",
                "--allow-unconfigured"
            ]
        }

        return [
            entry.path,
            "--host=127.0.0.1",
            "--port=\(port)",
            "--data-dir=\(dataDirectory.path)",
            "--auth-token-file=\(tokenFile.path)"
        ]
    }

    func prepareRuntimeConfiguration(port: Int, token: String, dataDirectory: URL) throws {
        let entry = try serverEntryPointURL()
        guard isOpenClawPackageEntry(entry) else { return }

        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)

        let configURL = dataDirectory.appendingPathComponent("openclaw.json")
        var root = readJSONDictionary(at: configURL) ?? [:]
        var gateway = root["gateway"] as? [String: Any] ?? [:]
        gateway["mode"] = "local"
        gateway["port"] = port
        gateway["bind"] = "loopback"
        gateway["auth"] = [
            "mode": "none"
        ]

        var controlUi = gateway["controlUi"] as? [String: Any] ?? [:]
        controlUi["allowInsecureAuth"] = true
        controlUi["dangerouslyDisableDeviceAuth"] = true
        gateway["controlUi"] = controlUi

        var nodes = gateway["nodes"] as? [String: Any] ?? [:]
        var pairing = nodes["pairing"] as? [String: Any] ?? [:]
        pairing["autoApproveCidrs"] = ["127.0.0.1/32", "::1/128"]
        nodes["pairing"] = pairing
        gateway["nodes"] = nodes

        root["gateway"] = gateway
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: configURL, options: .atomic)
        chmod(configURL.path, S_IRUSR | S_IWUSR)
    }

    func browserURL(port: Int, token: String) -> URL? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = port
        components.path = "/"

        if (try? serverEntryPointURL()).map(isOpenClawPackageEntry) != true {
            components.queryItems = [URLQueryItem(name: "token", value: token)]
        }
        return components.url
    }

    func serverEnvironment(port: Int, token: String, dataDirectory: URL) -> [String: String] {
        var environment = AppSettings.environmentVariables
        let usesOpenClawPackage = (try? serverEntryPointURL()).map(isOpenClawPackageEntry) == true
        let authEnvironment = AuthProviderCatalog.environmentVariables(
            store: KeychainStore(),
            enabledProviderIDs: AppSettings.enabledAuthProviderIDs
        )
        environment.merge(authEnvironment) { _, new in new }
        environment["OPENCLAW_HOST"] = "127.0.0.1"
        environment["OPENCLAW_PORT"] = "\(port)"
        environment["OPENCLAW_CORS_ORIGIN"] = "http://localhost:\(port)"
        environment["OPENCLAW_DATA_DIR"] = dataDirectory.path
        environment["OPENCLAW_GATEWAY_PORT"] = "\(port)"
        if usesOpenClawPackage {
            environment["OPENCLAW_STATE_DIR"] = dataDirectory.path
            environment["OPENCLAW_CONFIG_PATH"] = dataDirectory
                .appendingPathComponent("openclaw.json")
                .path
        } else {
            environment["OPENCLAW_AUTH_TOKEN"] = token
            environment["OPENCLAW_GATEWAY_TOKEN"] = token
            environment["OPENCLAW_STATE_DIR"] = dataDirectory
                .appendingPathComponent("state", isDirectory: true)
                .path
            environment["OPENCLAW_CONFIG_PATH"] = dataDirectory
                .appendingPathComponent("state", isDirectory: true)
                .appendingPathComponent("openclaw.json")
                .path
        }
        environment["NODE_ENV"] = "production"
        return environment
    }

    func isFallbackRuntime(at directory: URL) -> Bool {
        if let manifest = manifest(in: directory) {
            if manifest.fallback == true || manifest.placeholder == true {
                return true
            }
            let markerValues = [manifest.version, manifest.source, manifest.kind, manifest.runtime]
                .compactMap { $0?.lowercased() }
            if markerValues.contains(where: { value in
                value.contains("fallback") || value.contains("placeholder") || value.contains("smoke-test")
            }) {
                return true
            }
        }

        guard let entry = serverEntryPointURL(in: directory) else {
            return false
        }
        guard let data = try? Data(contentsOf: entry, options: [.mappedIfSafe]),
              data.count < 2_000_000,
              let contents = String(data: data, encoding: .utf8) else {
            return false
        }
        return contents.contains("OpenClaw local runtime")
            || contents.contains("runtime: \"fallback\"")
            || contents.contains("bundled fallback runtime")
    }

    private func isUsableRuntime(at directory: URL) -> Bool {
        hasServer(in: directory)
            && hasNode(in: directory)
            && !isFallbackRuntime(at: directory)
            && hasCompletedInstallMarkerIfNeeded(at: directory)
    }

    private func hasServer(in directory: URL) -> Bool {
        serverEntryPointURL(in: directory) != nil
    }

    private func hasNode(in directory: URL) -> Bool {
        if !AppSettings.customNodePath.isEmpty,
           FileManager.default.isExecutableFile(atPath: AppSettings.customNodePath) {
            return true
        }
        return nodeExecutableURL(in: directory) != nil
    }

    private func manifest(in directory: URL) -> RuntimeManifest? {
        let url = directory.appendingPathComponent("version.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RuntimeManifest.self, from: data)
    }

    private func readJSONDictionary(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }

    private func hasCompletedInstallMarkerIfNeeded(at directory: URL) -> Bool {
        let installedPath = userInstalledRuntimeDirectory.standardizedFileURL.path
        let checkedPath = directory.standardizedFileURL.path
        guard installedPath == checkedPath else { return true }
        return manifest(in: directory) != nil
    }

    private func serverEntryPointURL(in directory: URL) -> URL? {
        let candidates = [
            directory.appendingPathComponent("server/openclaw.mjs"),
            directory.appendingPathComponent("server/dist/index.js"),
            directory.appendingPathComponent("server/dist/entry.js"),
            directory.appendingPathComponent("server/dist/entry.mjs"),
            directory.appendingPathComponent("server/index.js"),
            directory.appendingPathComponent("server/server.js")
        ]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }

    private func isOpenClawPackageEntry(_ url: URL) -> Bool {
        url.lastPathComponent == "openclaw.mjs"
    }

    private func nodeExecutableURL(in directory: URL) -> URL? {
        let archNode = directory
            .appendingPathComponent("node-\(architectureName)", isDirectory: true)
            .appendingPathComponent("bin/node")
        if FileManager.default.isExecutableFile(atPath: archNode.path) {
            return archNode
        }
        let fallback = directory.appendingPathComponent("node/bin/node")
        if FileManager.default.isExecutableFile(atPath: fallback.path) {
            return fallback
        }
        return nil
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
