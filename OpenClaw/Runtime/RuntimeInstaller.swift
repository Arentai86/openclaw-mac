import Foundation

/// Installs the OpenClaw runtime (bundled Node + server) into Application Support so the
/// launcher can run without relying on whatever was baked into the .app at build time.
/// Four sources are supported: the .app bundle (no install needed), the latest internet
/// package, a direct server archive URL, or a user-picked local archive / folder.
struct RuntimeInstaller {
    enum Source: Equatable {
        case bundled
        case download
        case url(URL)
        case local(node: URL?, server: URL)
    }

    enum InstallError: LocalizedError {
        case missingServer
        case missingNode
        case unsupportedArchive(URL)
        case missingServerEntryPoint
        case extractionFailed(String)
        case downloadFailed(String)
        case writeFailed(String)
        case placeholderBundledRuntime

        var errorDescription: String? {
            switch self {
            case .missingServer: return L("OpenClaw server location is required.")
            case .missingNode: return L("Node.js distribution is required (or use the bundled Node).")
            case .unsupportedArchive(let url): return LF("Unsupported archive format: %@", url.lastPathComponent)
            case .missingServerEntryPoint:
                return L("OpenClaw server package did not contain a runnable entry point.")
            case .extractionFailed(let text): return LF("Extraction failed: %@", text)
            case .downloadFailed(let text): return LF("Download failed: %@", text)
            case .writeFailed(let text): return LF("Could not write runtime: %@", text)
            case .placeholderBundledRuntime:
                return L("This build contains only a launcher test runtime, not the real OpenClaw server.")
            }
        }
    }

    struct Progress {
        let fraction: Double
        let stage: String
    }

    /// Default Node version downloaded from nodejs.org when the user picks "Internet".
    /// OpenClaw currently requires Node >= 22.19.0.
    static let defaultNodeVersion = "22.19.0"
    static let defaultServerPackage = "openclaw"
    static let defaultServerRepo = "https://github.com/openclaw/openclaw.git"
    static let defaultServerRef = "latest"

    var installedRuntimeURL: URL {
        Paths.applicationSupportDirectory.appendingPathComponent("runtime", isDirectory: true)
    }

    var manifestURL: URL {
        installedRuntimeURL.appendingPathComponent("version.json")
    }

    var isInstalled: Bool {
        RuntimeBundle().userInstalledRuntimeIsUsable
    }

    var nodeBinaryURL: URL {
        installedRuntimeURL
            .appendingPathComponent("node-\(currentArchSlug)", isDirectory: true)
            .appendingPathComponent("bin/node")
    }

    var npmBinaryURL: URL {
        installedRuntimeURL
            .appendingPathComponent("node-\(currentArchSlug)", isDirectory: true)
            .appendingPathComponent("bin/npm")
    }

    var serverFolderURL: URL {
        installedRuntimeURL.appendingPathComponent("server", isDirectory: true)
    }

    var serverEntryURL: URL {
        // The server may ship "index.js", "server.js", or "dist/index.js" — match RuntimeBundle.
        let candidates = [
            serverFolderURL.appendingPathComponent("openclaw.mjs"),
            serverFolderURL.appendingPathComponent("dist/index.js"),
            serverFolderURL.appendingPathComponent("dist/entry.js"),
            serverFolderURL.appendingPathComponent("dist/entry.mjs"),
            serverFolderURL.appendingPathComponent("index.js"),
            serverFolderURL.appendingPathComponent("server.js")
        ]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
            ?? serverFolderURL.appendingPathComponent("index.js")
    }

    private var packageJSONURL: URL {
        serverFolderURL.appendingPathComponent("package.json")
    }

    private var packageLockURL: URL {
        serverFolderURL.appendingPathComponent("package-lock.json")
    }

    private var bundledNpmBinaryURL: URL {
        RuntimeBundle().bundledRuntimeDirectory
            .appendingPathComponent("node-\(currentArchSlug)", isDirectory: true)
            .appendingPathComponent("bin/npm")
    }

    /// Performs the install. `progress` is invoked on the main actor with [0...1] fraction
    /// and a short localized stage label.
    func install(
        source: Source,
        nodeVersion: String = RuntimeInstaller.defaultNodeVersion,
        serverRef: String = RuntimeInstaller.defaultServerRef,
        progress: @escaping @MainActor (Progress) -> Void
    ) async throws {
        await MainActor.run { progress(Progress(fraction: 0.02, stage: L("Preparing"))) }

        switch source {
        case .bundled:
            guard RuntimeBundle().bundledRuntimeIsUsable else {
                throw InstallError.placeholderBundledRuntime
            }
            // Nothing to copy — RuntimeBundle will resolve the bundled runtime.
            try removeUserInstalledMarker()
            await MainActor.run { progress(Progress(fraction: 1.0, stage: L("Using bundled runtime"))) }
            return

        case .download:
            try resetInstallDirectory()
            try await downloadNode(version: nodeVersion, progress: progress)
            try await downloadServer(ref: serverRef, progress: progress)

        case let .url(url):
            try resetInstallDirectory()
            try await downloadNode(version: nodeVersion, progress: progress)
            try await downloadServer(from: url, progress: progress)

        case let .local(node, server):
            try resetInstallDirectory()
            if let nodeURL = node {
                try await installLocalNode(from: nodeURL, progress: progress)
            } else if !FileManager.default.isExecutableFile(atPath: nodeBinaryURL.path),
                      !RuntimeBundle().bundledNodeIsAvailable {
                throw InstallError.missingNode
            }
            try await installLocalServer(from: server, progress: progress)
        }

        try await installServerDependenciesIfNeeded(progress: progress)
        try validateInstalledRuntime()
        try writeManifest(source: source, nodeVersion: nodeVersion, serverRef: serverRef)
        await MainActor.run { progress(Progress(fraction: 1.0, stage: L("Runtime ready"))) }
    }

    // MARK: - Internet install

    private func downloadNode(version: String, progress: @escaping @MainActor (Progress) -> Void) async throws {
        let arch = currentArchSlug
        let archive = "node-v\(version)-darwin-\(arch).tar.gz"
        let urlString = "https://nodejs.org/dist/v\(version)/\(archive)"
        guard let url = URL(string: urlString) else {
            throw InstallError.downloadFailed("Bad Node URL: \(urlString)")
        }

        await MainActor.run { progress(Progress(fraction: 0.05, stage: LF("Downloading Node %@ (%@)", version, arch))) }

        let (tempFile, response) = try await URLSession.shared.download(from: url)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw InstallError.downloadFailed("HTTP \(http.statusCode) from nodejs.org")
        }

        await MainActor.run { progress(Progress(fraction: 0.35, stage: L("Extracting Node"))) }
        try extractNodeTar(tempFile, arch: arch)
        await MainActor.run { progress(Progress(fraction: 0.55, stage: L("Node ready"))) }
    }

    private func downloadServer(ref: String, progress: @escaping @MainActor (Progress) -> Void) async throws {
        await MainActor.run { progress(Progress(fraction: 0.6, stage: L("Downloading OpenClaw server package"))) }
        guard let npm = npmExecutableForInstall() else {
            throw InstallError.missingNode
        }
        let environment = try nodeToolEnvironment(for: npm)
        try await runProcess(nodeExecutableFor(npm: npm), arguments: ["--version"], environment: environment)

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("openclaw-package-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let spec = serverPackageSpec(ref: ref)
        try await runProcess(
            npm,
            arguments: ["pack", spec, "--pack-destination", tempDirectory.path, "--silent"],
            environment: environment
        )
        guard let archive = try FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: nil
        ).first(where: { $0.pathExtension.lowercased() == "tgz" }) else {
            throw InstallError.downloadFailed(L("OpenClaw npm package was not downloaded."))
        }

        await MainActor.run { progress(Progress(fraction: 0.85, stage: L("Extracting server"))) }
        try extractServerArchive(archive, originalName: archive.lastPathComponent)
    }

    private func downloadServer(from url: URL, progress: @escaping @MainActor (Progress) -> Void) async throws {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            throw InstallError.downloadFailed(L("OpenClaw server link must start with http:// or https://."))
        }

        await MainActor.run { progress(Progress(fraction: 0.6, stage: L("Downloading OpenClaw server from link"))) }
        let (tempFile, response) = try await URLSession.shared.download(from: url)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw InstallError.downloadFailed("HTTP \(http.statusCode) from \(url.host ?? url.absoluteString)")
        }

        await MainActor.run { progress(Progress(fraction: 0.85, stage: L("Extracting server"))) }
        try extractServerArchive(tempFile, originalName: url.lastPathComponent)
    }

    private func serverPackageSpec(ref: String) -> String {
        let trimmed = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "\(RuntimeInstaller.defaultServerPackage)@\(RuntimeInstaller.defaultServerRef)"
        }
        if trimmed.contains("@") || trimmed.hasPrefix("file:") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        return "\(RuntimeInstaller.defaultServerPackage)@\(trimmed)"
    }

    private func extractNodeTar(_ archive: URL, arch: String) throws {
        let target = installedRuntimeURL.appendingPathComponent("node-\(arch)", isDirectory: true)
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try runTarSync(["-xzf", archive.path, "-C", target.path, "--strip-components=1"])
    }

    private func extractServerArchive(_ archive: URL, originalName: String) throws {
        if FileManager.default.fileExists(atPath: serverFolderURL.path) {
            try FileManager.default.removeItem(at: serverFolderURL)
        }

        let lowerName = originalName.lowercased()
        if lowerName.hasSuffix(".tar.gz") || lowerName.hasSuffix(".tgz") || lowerName.hasSuffix(".gz") {
            try FileManager.default.createDirectory(at: serverFolderURL, withIntermediateDirectories: true)
            try runTarSync(["-xzf", archive.path, "-C", serverFolderURL.path, "--strip-components=1"])
        } else if lowerName.hasSuffix(".tar") {
            try FileManager.default.createDirectory(at: serverFolderURL, withIntermediateDirectories: true)
            try runTarSync(["-xf", archive.path, "-C", serverFolderURL.path, "--strip-components=1"])
        } else if lowerName.hasSuffix(".zip") {
            try extractServerZip(archive)
        } else {
            throw InstallError.unsupportedArchive(URL(fileURLWithPath: originalName))
        }
    }

    private func extractServerZip(_ archive: URL) throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("openclaw-server-zip-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let unzip = URL(fileURLWithPath: "/usr/bin/unzip")
        try runSync(unzip, arguments: ["-q", archive.path, "-d", tempDirectory.path])

        let root = normalizedExtractionRoot(in: tempDirectory)
        try FileManager.default.createDirectory(at: serverFolderURL, withIntermediateDirectories: true)
        let children = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        for child in children {
            try FileManager.default.copyItem(
                at: child,
                to: serverFolderURL.appendingPathComponent(child.lastPathComponent)
            )
        }
    }

    private func normalizedExtractionRoot(in directory: URL) -> URL {
        let children = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        guard children.count == 1, let only = children.first else {
            return directory
        }
        let isDirectory = (try? only.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        return isDirectory ? only : directory
    }

    // MARK: - Local install

    private func installLocalNode(from url: URL, progress: @escaping @MainActor (Progress) -> Void) async throws {
        await MainActor.run { progress(Progress(fraction: 0.2, stage: L("Installing local Node"))) }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            throw InstallError.missingNode
        }
        let target = installedRuntimeURL.appendingPathComponent("node-\(currentArchSlug)", isDirectory: true)
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }

        if isDir.boolValue {
            // User pointed at an extracted Node distribution. Copy bin/, lib/, share/ into target.
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            let children = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
            for child in children {
                let dest = target.appendingPathComponent(child.lastPathComponent)
                try FileManager.default.copyItem(at: child, to: dest)
            }
        } else if url.pathExtension.lowercased() == "gz" || url.lastPathComponent.hasSuffix(".tar.gz") || url.pathExtension.lowercased() == "tgz" {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            try runTarSync(["-xzf", url.path, "-C", target.path, "--strip-components=1"])
        } else {
            throw InstallError.unsupportedArchive(url)
        }

        guard FileManager.default.isExecutableFile(atPath: nodeBinaryURL.path) else {
            throw InstallError.extractionFailed("Node binary not found at \(nodeBinaryURL.path) after install.")
        }
    }

    private func installLocalServer(from url: URL, progress: @escaping @MainActor (Progress) -> Void) async throws {
        await MainActor.run { progress(Progress(fraction: 0.7, stage: L("Installing local OpenClaw server"))) }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            throw InstallError.missingServer
        }
        if FileManager.default.fileExists(atPath: serverFolderURL.path) {
            try FileManager.default.removeItem(at: serverFolderURL)
        }
        if isDir.boolValue {
            try FileManager.default.copyItem(at: url, to: serverFolderURL)
        } else if isSupportedServerArchive(url) {
            try extractServerArchive(url, originalName: url.lastPathComponent)
        } else {
            throw InstallError.unsupportedArchive(url)
        }
    }

    private func isSupportedServerArchive(_ url: URL) -> Bool {
        let lowerName = url.lastPathComponent.lowercased()
        return lowerName.hasSuffix(".tar.gz")
            || lowerName.hasSuffix(".tgz")
            || lowerName.hasSuffix(".gz")
            || lowerName.hasSuffix(".tar")
            || lowerName.hasSuffix(".zip")
    }

    // MARK: - Server dependency install

    private func installServerDependenciesIfNeeded(progress: @escaping @MainActor (Progress) -> Void) async throws {
        guard FileManager.default.fileExists(atPath: packageJSONURL.path) else { return }
        guard let npm = npmExecutableForInstall() else {
            throw InstallError.missingNode
        }
        let environment = try nodeToolEnvironment(for: npm)
        try await runProcess(nodeExecutableFor(npm: npm), arguments: ["--version"], environment: environment)

        if FileManager.default.fileExists(atPath: packageLockURL.path) {
            await MainActor.run { progress(Progress(fraction: 0.92, stage: L("Installing server dependencies"))) }
            try await runProcess(npm, arguments: ["ci", "--omit=dev", "--prefix", serverFolderURL.path], environment: environment)
        } else {
            await MainActor.run { progress(Progress(fraction: 0.92, stage: L("Installing server dependencies"))) }
            try await runProcess(npm, arguments: ["install", "--omit=dev", "--prefix", serverFolderURL.path], environment: environment)
        }
    }

    private func validateInstalledRuntime() throws {
        guard FileManager.default.fileExists(atPath: serverEntryURL.path) else {
            throw InstallError.missingServerEntryPoint
        }
        guard FileManager.default.isExecutableFile(atPath: nodeBinaryURL.path)
                || RuntimeBundle().bundledNodeIsAvailable else {
            throw InstallError.missingNode
        }
    }

    private func npmExecutableForInstall() -> URL? {
        if FileManager.default.isExecutableFile(atPath: npmBinaryURL.path) {
            return npmBinaryURL
        }
        if FileManager.default.isExecutableFile(atPath: bundledNpmBinaryURL.path) {
            return bundledNpmBinaryURL
        }
        return nil
    }

    private func nodeExecutableFor(npm: URL) -> URL {
        npm.deletingLastPathComponent().appendingPathComponent("node")
    }

    private func nodeToolEnvironment(for npm: URL) throws -> [String: String] {
        let nodeBinDirectory = npm.deletingLastPathComponent()
        let node = nodeBinDirectory.appendingPathComponent("node")
        guard FileManager.default.isExecutableFile(atPath: node.path) else {
            throw InstallError.extractionFailed("Node binary not found next to npm at \(node.path).")
        }

        let npmCache = Paths.cachesDirectory.appendingPathComponent("npm", isDirectory: true)
        try FileManager.default.createDirectory(at: npmCache, withIntermediateDirectories: true)

        let existingPath = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        return [
            "PATH": "\(nodeBinDirectory.path):\(existingPath)",
            "HOME": NSHomeDirectory(),
            "NODE_ENV": "production",
            "npm_config_cache": npmCache.path,
            "NPM_CONFIG_CACHE": npmCache.path
        ]
    }

    // MARK: - Manifest / cleanup

    private func resetInstallDirectory() throws {
        if FileManager.default.fileExists(atPath: installedRuntimeURL.path) {
            try FileManager.default.removeItem(at: installedRuntimeURL)
        }
        try FileManager.default.createDirectory(at: installedRuntimeURL, withIntermediateDirectories: true)
    }

    private func writeManifest(source: Source, nodeVersion: String, serverRef: String) throws {
        let sourceTag: String
        switch source {
        case .bundled: sourceTag = "bundled"
        case .download: sourceTag = "download"
        case .url: sourceTag = "url"
        case .local: sourceTag = "local"
        }
        var manifest: [String: Any] = [
            "version": serverRef,
            "node": nodeVersion,
            "source": sourceTag,
            "installedAt": ISO8601DateFormatter().string(from: Date())
        ]
        if case let .url(url) = source {
            manifest["serverURL"] = url.absoluteString
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: manifestURL, options: .atomic)
        } catch {
            throw InstallError.writeFailed(error.localizedDescription)
        }
    }

    private func removeUserInstalledMarker() throws {
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            try FileManager.default.removeItem(at: manifestURL)
        }
    }

    func uninstall() throws {
        if FileManager.default.fileExists(atPath: installedRuntimeURL.path) {
            try FileManager.default.removeItem(at: installedRuntimeURL)
        }
    }

    // MARK: - Process helpers

    private func runProcess(_ executable: URL, arguments: [String], environment: [String: String] = [:]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try runSync(executable, arguments: arguments, environment: environment)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func runTarSync(_ arguments: [String]) throws {
        try runSync(URL(fileURLWithPath: "/usr/bin/tar"), arguments: arguments)
    }

    private func runSync(_ executable: URL, arguments: [String], environment: [String: String] = [:]) throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        if !environment.isEmpty {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            throw InstallError.extractionFailed("Failed to launch \(executable.lastPathComponent): \(error.localizedDescription)")
        }
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data.prefix(400), encoding: .utf8) ?? ""
            throw InstallError.extractionFailed("\(executable.lastPathComponent) exited \(process.terminationStatus): \(output)")
        }
    }

    private var currentArchSlug: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x64"
        #else
        return "arm64"
        #endif
    }
}
