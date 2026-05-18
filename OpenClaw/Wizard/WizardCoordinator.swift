import Foundation

@MainActor
final class WizardCoordinator: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome
        case systemCheck
        case dataLocation
        case port
        case apiKeys
        case finish
    }

    @Published var step: Step = .welcome
    @Published var canContinue = true
    @Published var isFinishing = false
    @Published var finishError: String?

    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func next() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
        canContinue = true
    }

    func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
        canContinue = true
    }

    func finish() async {
        isFinishing = true
        finishError = nil

        do {
            try LaunchAtLogin.setEnabled(AppSettings.launchAtLogin)
            await appState.startServer()
            if case let .error(message) = appState.serverStatus {
                throw NSError(domain: "OpenClaw", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
            }
            appState.openInBrowser()
            WizardWindowController.shared.closeWizard()
        } catch {
            finishError = error.localizedDescription
        }

        isFinishing = false
    }
}

