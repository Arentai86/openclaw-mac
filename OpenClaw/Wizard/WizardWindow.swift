import AppKit
import SwiftUI

@MainActor
final class WizardWindowController: NSWindowController {
    static let shared = WizardWindowController()

    private var coordinator: WizardCoordinator?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "OpenClaw Setup"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(appState: AppState) {
        let coordinator = WizardCoordinator(appState: appState)
        self.coordinator = coordinator
        window?.contentView = NSHostingView(rootView: WizardRootView(coordinator: coordinator))
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWizard() {
        close()
        coordinator = nil
    }
}

struct WizardRootView: View {
    @ObservedObject var coordinator: WizardCoordinator

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch coordinator.step {
                case .welcome:
                    WelcomeStep(coordinator: coordinator)
                case .systemCheck:
                    SystemCheckStep(coordinator: coordinator)
                case .dataLocation:
                    DataLocationStep(coordinator: coordinator)
                case .port:
                    PortStep(coordinator: coordinator)
                case .apiKeys:
                    APIKeysStep(coordinator: coordinator)
                case .finish:
                    FinishStep(coordinator: coordinator)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 480)
    }
}

