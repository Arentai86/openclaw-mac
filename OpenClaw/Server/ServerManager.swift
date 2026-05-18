import AppKit
import Foundation

final class ServerManager {
    var onStatusChange: ((ServerStatus) -> Void)?
    var onPortDetected: ((Int) -> Void)?
    var onError: ((String) -> Void)?

    private var process: ServerProcess?
    private var healthTimer: DispatchSourceTimer?
    private var activityToken: NSObjectProtocol?
    private var restartAttempt = 0
    private var shouldAutoRestart = true
    private var configuredPort = AppSettings.serverPort
    private var configuredDataDirectory = AppSettings.dataLocationURL
    private let runtime = RuntimeBundle()

    func start(preferredPort: Int, dataDirectory: URL, autoRestart: Bool) throws {
        stop()

        shouldAutoRestart = autoRestart
        configuredPort = preferredPort
        configuredDataDirectory = dataDirectory

        try DependencyResolver(runtime: runtime).validate()
        try FileManager.default.createDirectory(at: Paths.logsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)

        let token = try AuthToken.ensureToken(in: dataDirectory)
        let logURL = Paths.logsDirectory.appendingPathComponent("server.log")
        let process = try ServerProcess(
            executableURL: runtime.nodeExecutableURL(),
            arguments: runtime.serverArguments(
                port: preferredPort,
                dataDirectory: dataDirectory,
                tokenFile: dataDirectory.appendingPathComponent("auth_token")
            ),
            environment: runtime.serverEnvironment(port: preferredPort, token: token),
            logURL: logURL
        )

        process.onStdoutLine = { [weak self] line in
            self?.handleServerLine(line)
        }
        process.onStderrLine = { [weak self] line in
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self?.appendDiagnostic("stderr: \(line)")
            }
        }
        process.onTermination = { [weak self] terminationStatus in
            self?.handleTermination(status: terminationStatus)
        }

        self.process = process
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "OpenClaw local server is running"
        )
        onStatusChange?(.starting)
        try process.start()
        startHealthChecks(port: preferredPort, token: token)
    }

    func stop() {
        healthTimer?.cancel()
        healthTimer = nil
        shouldAutoRestart = false
        process?.terminate(gracePeriod: 5)
        process = nil
        endActivity()
        onStatusChange?(.stopped)
    }

    func stopForTermination() {
        healthTimer?.cancel()
        healthTimer = nil
        shouldAutoRestart = false
        process?.terminate(gracePeriod: 5)
        endActivity()
    }

    private func endActivity() {
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }

    private func handleServerLine(_ line: String) {
        appendDiagnostic("stdout: \(line)")
        if let port = parseListeningPort(from: line) {
            configuredPort = port
            onPortDetected?(port)
            onStatusChange?(.running)
        }
    }

    private func parseListeningPort(from line: String) -> Int? {
        guard let range = line.range(of: "LISTENING_ON:") else { return nil }
        let suffix = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(suffix)
    }

    private func handleTermination(status: Int32) {
        healthTimer?.cancel()
        healthTimer = nil
        process = nil

        guard shouldAutoRestart else {
            onStatusChange?(.stopped)
            return
        }

        let delay = min(pow(2.0, Double(restartAttempt)), 30.0)
        restartAttempt += 1
        onError?("Server exited with status \(status). Restarting in \(Int(delay))s.")

        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.shouldAutoRestart else { return }
            do {
                try self.start(
                    preferredPort: self.configuredPort,
                    dataDirectory: self.configuredDataDirectory,
                    autoRestart: self.shouldAutoRestart
                )
            } catch {
                self.onError?(error.localizedDescription)
            }
        }
    }

    private func startHealthChecks(port: Int, token: String) {
        healthTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + 1, repeating: .seconds(2))
        timer.setEventHandler { [weak self] in
            Task {
                let isHealthy = await HealthCheck().ping(port: port, token: token)
                if isHealthy {
                    self?.restartAttempt = 0
                    self?.onPortDetected?(port)
                    self?.onStatusChange?(.running)
                }
            }
        }
        timer.resume()
        healthTimer = timer
    }

    private func appendDiagnostic(_ line: String) {
        let message = "[\(Date())] \(line)\n"
        guard let data = message.data(using: .utf8) else { return }
        let url = Paths.logsDirectory.appendingPathComponent("launcher.log")
        try? FileManager.default.createDirectory(at: Paths.logsDirectory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                do {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.close()
                } catch {
                    try? handle.close()
                }
            }
        } else {
            try? data.write(to: url)
        }
    }
}
