import Foundation

#if canImport(Sparkle)
import Sparkle
#endif

final class UpdateManager: NSObject {
    #if canImport(Sparkle)
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    #endif

    func checkForUpdates() {
        #if canImport(Sparkle)
        updaterController.checkForUpdates(nil)
        #else
        NSLog("Sparkle is not linked. Resolve Swift Package dependencies to enable updates.")
        #endif
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            #if canImport(Sparkle)
            return updaterController.updater.automaticallyChecksForUpdates
            #else
            return false
            #endif
        }
        set {
            #if canImport(Sparkle)
            updaterController.updater.automaticallyChecksForUpdates = newValue
            #endif
        }
    }
}

