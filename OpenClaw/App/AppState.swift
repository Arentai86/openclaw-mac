import AppKit
import Foundation
import SwiftUI

func L(_ key: String) -> String {
    AppLocalization.shared.string(for: key)
}

func LF(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), locale: Locale.current, arguments: arguments)
}

struct AppLocalization {
    static let shared = AppLocalization()

    private var languageCode: String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("ru") { return "ru" }
        if preferred.hasPrefix("de") { return "de" }
        return "en"
    }

    func string(for key: String) -> String {
        translations[languageCode]?[key] ?? translations["en"]?[key] ?? key
    }

    private let translations: [String: [String: String]] = [
        "en": [:],
        "ru": [
            "OpenClaw is stopped": "OpenClaw остановлен",
            "OpenClaw is starting": "OpenClaw запускается",
            "OpenClaw is running": "OpenClaw работает",
            "OpenClaw is stopping": "OpenClaw останавливается",
            "OpenClaw error: %@": "Ошибка OpenClaw: %@",
            "Server did not pass health check within 20 seconds.": "Сервер не прошел health-check за 20 секунд.",
            "Health check failed.": "Health-check не прошел.",
            "Port: %d": "Порт: %d",
            "Open in Browser": "Открыть в браузере",
            "Restart Server": "Перезапустить сервер",
            "Stop Server": "Остановить сервер",
            "View Logs": "Посмотреть логи",
            "Preferences...": "Настройки...",
            "Check for Updates...": "Проверить обновления...",
            "Quit OpenClaw": "Выйти из OpenClaw",
            "General": "Основные",
            "Server": "Сервер",
            "Advanced": "Дополнительно",
            "About": "О приложении",
            "Start server when OpenClaw launches": "Запускать сервер вместе с OpenClaw",
            "Launch at login": "Запускать при входе в систему",
            "Check for updates automatically": "Проверять обновления автоматически",
            "Auto-restart on crash": "Перезапускать при сбое",
            "Data location": "Расположение данных",
            "Choose...": "Выбрать...",
            "Custom Node path": "Путь к Node",
            "Environment variables": "Переменные окружения",
            "Open Data Folder": "Открыть папку данных",
            "Open Logs Folder": "Открыть папку логов",
            "Export Diagnostics": "Экспорт диагностики",
            "Uninstall OpenClaw...": "Удалить OpenClaw...",
            "Uninstall OpenClaw?": "Удалить OpenClaw?",
            "This stops the server and removes OpenClaw data, logs, preferences, and stored credentials.": "Это остановит сервер и удалит данные OpenClaw, логи, настройки и сохраненные учетные данные.",
            "Uninstall": "Удалить",
            "Cancel": "Отмена",
            "Version %@ (%@)": "Версия %@ (%@)",
            "GitHub": "GitHub",
            "License": "Лицензия",
            "Check for Updates": "Проверить обновления",
            "Welcome to OpenClaw": "Добро пожаловать в OpenClaw",
            "OpenClaw runs the local server, keeps it healthy, and gives you one-click access from the macOS menu bar.": "OpenClaw запускает локальный сервер, следит за его состоянием и дает доступ в один клик из меню macOS.",
            "Back": "Назад",
            "Continue": "Продолжить",
            "System Check": "Проверка системы",
            "OpenClaw checks the parts it needs before creating your local workspace.": "OpenClaw проверяет необходимые компоненты перед созданием локального рабочего пространства.",
            "macOS 13 or newer": "macOS 13 или новее",
            "Checking OS version": "Проверка версии ОС",
            "Application Support writable": "Запись в Application Support",
            "Checking storage permissions": "Проверка прав на запись",
            "Free disk space": "Свободное место",
            "Checking available capacity": "Проверка свободного места",
            "Network path": "Сеть",
            "Checking network reachability": "Проверка доступности сети",
            "Ventura or newer is required.": "Требуется Ventura или новее.",
            "At least 2 GB is recommended.": "Рекомендуется минимум 2 ГБ.",
            "Network appears reachable.": "Сеть доступна.",
            "You can continue, but updates may fail.": "Можно продолжить, но обновления могут не работать.",
            "Data Location": "Расположение данных",
            "Choose where OpenClaw stores editable data, cache, skills, and configuration.": "Выберите, где OpenClaw будет хранить редактируемые данные, кэш, навыки и конфигурацию.",
            "Use Default": "Использовать по умолчанию",
            "Server Port": "Порт сервера",
            "OpenClaw binds only to 127.0.0.1 and never listens on external interfaces.": "OpenClaw слушает только 127.0.0.1 и никогда не открывает внешний интерфейс.",
            "Port": "Порт",
            "Auto-detect": "Автоопределение",
            "Enter a port between 1 and 65535.": "Введите порт от 1 до 65535.",
            "Port %d is already in use.": "Порт %d уже занят.",
            "Port is available.": "Порт свободен.",
            "All Set": "Все готово",
            "OpenClaw will start now and open in your browser once the local health check passes.": "OpenClaw запустится и откроется в браузере после успешного локального health-check.",
            "Starting...": "Запуск...",
            "Finish": "Готово",
            "Authorization": "Авторизация",
            "Choose how OpenClaw should sign in. Codex login/password is enabled by default, and you can add more providers now.": "Выберите способ входа. Codex login/password включен по умолчанию, дополнительные провайдеры можно добавить сразу.",
            "Choose a provider first, then choose Google, official website, API key, token, or login/password where supported.": "Сначала выберите провайдера, затем способ входа: Google, официальный сайт, API-ключ, токен или логин/пароль, если поддерживается.",
            "%d authorization options": "%d вариантов авторизации",
            "Authentication method": "Способ авторизации",
            "Enable this method": "Включить этот способ",
            "Primary method": "Основной способ",
            "At least one authorization method is required.": "Нужен хотя бы один способ авторизации.",
            "Fill required fields for enabled providers.": "Заполните обязательные поля для включенных провайдеров.",
            "Credentials are stored in macOS Keychain.": "Учетные данные сохраняются в macOS Keychain.",
            "No local secret is required for this method.": "Для этого способа локальный секрет не требуется.",
            "Sign in with Google": "Войти через Google",
            "Use Google sign-in on the provider's official website.": "Использовать вход через Google на официальном сайте провайдера.",
            "Open Google sign-in": "Открыть вход через Google",
            "Authorize on official website": "Авторизоваться на официальном сайте",
            "Open the provider's official website and complete authorization there.": "Откройте официальный сайт провайдера и завершите авторизацию там.",
            "Open official website": "Открыть официальный сайт",
            "Login and password": "Логин и пароль",
            "Store login and password in macOS Keychain.": "Сохранить логин и пароль в macOS Keychain.",
            "Email code": "Код по email",
            "Use an email-based sign-in flow.": "Использовать вход через код, отправленный на email.",
            "Open API key page": "Открыть страницу API-ключей",
            "Paste an API key generated by the provider.": "Вставьте API-ключ, созданный у провайдера.",
            "Access token": "Access token",
            "Paste an access token generated by the provider.": "Вставьте access token, созданный у провайдера.",
            "OAuth token": "OAuth token",
            "Paste an OAuth token or use a connected browser session.": "Вставьте OAuth token или используйте подключенную браузерную сессию.",
            "Service account": "Service account",
            "Use a cloud service account for server-to-server access.": "Использовать облачный service account для server-to-server доступа.",
            "Local host": "Локальный host",
            "Connect to a local service running on this Mac.": "Подключиться к локальному сервису на этом Mac.",
            "Login": "Логин",
            "Password": "Пароль",
            "API key": "API-ключ",
            "Endpoint URL": "Endpoint URL",
            "Organization ID": "ID организации",
            "Client ID": "Client ID",
            "Client secret": "Client secret",
            "Region": "Регион",
            "Host": "Host",
            "Callback URL": "Callback URL",
            "Codex account": "Аккаунт Codex",
            "Codex login/password for OpenClaw.": "Логин и пароль Codex для OpenClaw.",
            "API provider": "API-провайдер",
            "OAuth provider": "OAuth-провайдер",
            "Cloud provider": "Облачный провайдер",
            "Local provider": "Локальный провайдер",
            "Workspace provider": "Провайдер workspace",
            "Configure %@": "Настройка %@",
            "Required": "Обязательно",
            "Optional": "Опционально"
        ],
        "de": [
            "OpenClaw is stopped": "OpenClaw ist gestoppt",
            "OpenClaw is starting": "OpenClaw startet",
            "OpenClaw is running": "OpenClaw läuft",
            "OpenClaw is stopping": "OpenClaw wird gestoppt",
            "OpenClaw error: %@": "OpenClaw-Fehler: %@",
            "Server did not pass health check within 20 seconds.": "Der Server hat den Health-Check nicht innerhalb von 20 Sekunden bestanden.",
            "Health check failed.": "Health-Check fehlgeschlagen.",
            "Port: %d": "Port: %d",
            "Open in Browser": "Im Browser öffnen",
            "Restart Server": "Server neu starten",
            "Stop Server": "Server stoppen",
            "View Logs": "Logs anzeigen",
            "Preferences...": "Einstellungen...",
            "Check for Updates...": "Nach Updates suchen...",
            "Quit OpenClaw": "OpenClaw beenden",
            "General": "Allgemein",
            "Server": "Server",
            "Advanced": "Erweitert",
            "About": "Über",
            "Start server when OpenClaw launches": "Server beim Start von OpenClaw starten",
            "Launch at login": "Beim Anmelden starten",
            "Check for updates automatically": "Automatisch nach Updates suchen",
            "Auto-restart on crash": "Bei Absturz neu starten",
            "Data location": "Datenordner",
            "Choose...": "Auswählen...",
            "Custom Node path": "Node-Pfad",
            "Environment variables": "Umgebungsvariablen",
            "Open Data Folder": "Datenordner öffnen",
            "Open Logs Folder": "Logordner öffnen",
            "Export Diagnostics": "Diagnose exportieren",
            "Uninstall OpenClaw...": "OpenClaw deinstallieren...",
            "Uninstall OpenClaw?": "OpenClaw deinstallieren?",
            "This stops the server and removes OpenClaw data, logs, preferences, and stored credentials.": "Dies stoppt den Server und entfernt OpenClaw-Daten, Logs, Einstellungen und gespeicherte Zugangsdaten.",
            "Uninstall": "Deinstallieren",
            "Cancel": "Abbrechen",
            "Version %@ (%@)": "Version %@ (%@)",
            "License": "Lizenz",
            "Check for Updates": "Nach Updates suchen",
            "Welcome to OpenClaw": "Willkommen bei OpenClaw",
            "OpenClaw runs the local server, keeps it healthy, and gives you one-click access from the macOS menu bar.": "OpenClaw startet den lokalen Server, überwacht ihn und bietet Zugriff über die macOS-Menüleiste.",
            "Back": "Zurück",
            "Continue": "Weiter",
            "System Check": "Systemprüfung",
            "OpenClaw checks the parts it needs before creating your local workspace.": "OpenClaw prüft die benötigten Komponenten, bevor der lokale Arbeitsbereich erstellt wird.",
            "macOS 13 or newer": "macOS 13 oder neuer",
            "Checking OS version": "OS-Version wird geprüft",
            "Application Support writable": "Application Support beschreibbar",
            "Checking storage permissions": "Speicherrechte werden geprüft",
            "Free disk space": "Freier Speicherplatz",
            "Checking available capacity": "Verfügbarer Speicher wird geprüft",
            "Network path": "Netzwerk",
            "Checking network reachability": "Netzwerk wird geprüft",
            "Ventura or newer is required.": "Ventura oder neuer ist erforderlich.",
            "At least 2 GB is recommended.": "Mindestens 2 GB werden empfohlen.",
            "Network appears reachable.": "Netzwerk ist erreichbar.",
            "You can continue, but updates may fail.": "Du kannst fortfahren, aber Updates könnten fehlschlagen.",
            "Data Location": "Datenordner",
            "Choose where OpenClaw stores editable data, cache, skills, and configuration.": "Wähle, wo OpenClaw Daten, Cache, Skills und Konfiguration speichert.",
            "Use Default": "Standard verwenden",
            "Server Port": "Server-Port",
            "OpenClaw binds only to 127.0.0.1 and never listens on external interfaces.": "OpenClaw bindet nur an 127.0.0.1 und öffnet keine externen Schnittstellen.",
            "Port": "Port",
            "Auto-detect": "Automatisch",
            "Enter a port between 1 and 65535.": "Gib einen Port zwischen 1 und 65535 ein.",
            "Port %d is already in use.": "Port %d wird bereits verwendet.",
            "Port is available.": "Port ist verfügbar.",
            "All Set": "Alles bereit",
            "OpenClaw will start now and open in your browser once the local health check passes.": "OpenClaw startet jetzt und öffnet den Browser nach erfolgreichem Health-Check.",
            "Starting...": "Startet...",
            "Finish": "Fertig",
            "Authorization": "Autorisierung",
            "Choose how OpenClaw should sign in. Codex login/password is enabled by default, and you can add more providers now.": "Wähle, wie OpenClaw sich anmelden soll. Codex Login/Passwort ist standardmäßig aktiv, weitere Provider können hinzugefügt werden.",
            "Choose a provider first, then choose Google, official website, API key, token, or login/password where supported.": "Wähle zuerst den Provider und dann Google, offizielle Website, API-Schlüssel, Token oder Login/Passwort, falls unterstützt.",
            "%d authorization options": "%d Autorisierungsoptionen",
            "Authentication method": "Autorisierungsmethode",
            "Enable this method": "Diese Methode aktivieren",
            "Primary method": "Primäre Methode",
            "At least one authorization method is required.": "Mindestens eine Autorisierungsmethode ist erforderlich.",
            "Fill required fields for enabled providers.": "Fülle die Pflichtfelder für aktivierte Provider aus.",
            "Credentials are stored in macOS Keychain.": "Zugangsdaten werden im macOS-Schlüsselbund gespeichert.",
            "No local secret is required for this method.": "Für diese Methode ist kein lokales Geheimnis erforderlich.",
            "Sign in with Google": "Mit Google anmelden",
            "Use Google sign-in on the provider's official website.": "Google-Anmeldung auf der offiziellen Provider-Website verwenden.",
            "Open Google sign-in": "Google-Anmeldung öffnen",
            "Authorize on official website": "Auf offizieller Website autorisieren",
            "Open the provider's official website and complete authorization there.": "Öffne die offizielle Provider-Website und schließe die Autorisierung dort ab.",
            "Open official website": "Offizielle Website öffnen",
            "Login and password": "Login und Passwort",
            "Store login and password in macOS Keychain.": "Login und Passwort im macOS-Schlüsselbund speichern.",
            "Email code": "E-Mail-Code",
            "Use an email-based sign-in flow.": "E-Mail-basierten Anmeldefluss verwenden.",
            "Open API key page": "API-Schlüsselseite öffnen",
            "Paste an API key generated by the provider.": "Füge einen vom Provider erzeugten API-Schlüssel ein.",
            "Access token": "Access Token",
            "Paste an access token generated by the provider.": "Füge einen vom Provider erzeugten Access Token ein.",
            "OAuth token": "OAuth Token",
            "Paste an OAuth token or use a connected browser session.": "Füge einen OAuth Token ein oder nutze eine verbundene Browser-Sitzung.",
            "Service account": "Service Account",
            "Use a cloud service account for server-to-server access.": "Cloud Service Account für Server-zu-Server-Zugriff verwenden.",
            "Local host": "Lokaler Host",
            "Connect to a local service running on this Mac.": "Mit einem lokalen Dienst auf diesem Mac verbinden.",
            "Login": "Login",
            "Password": "Passwort",
            "API key": "API-Schlüssel",
            "Endpoint URL": "Endpoint URL",
            "Organization ID": "Organisations-ID",
            "Client ID": "Client ID",
            "Client secret": "Client Secret",
            "Region": "Region",
            "Host": "Host",
            "Callback URL": "Callback URL",
            "Codex account": "Codex-Konto",
            "Codex login/password for OpenClaw.": "Codex Login und Passwort für OpenClaw.",
            "API provider": "API-Provider",
            "OAuth provider": "OAuth-Provider",
            "Cloud provider": "Cloud-Provider",
            "Local provider": "Lokaler Provider",
            "Workspace provider": "Workspace-Provider",
            "Configure %@": "%@ konfigurieren",
            "Required": "Erforderlich",
            "Optional": "Optional"
        ]
    ]
}

enum ServerStatus: Equatable {
    case stopped
    case starting
    case running
    case stopping
    case error(String)

    var title: String {
        switch self {
        case .stopped:
            return L("OpenClaw is stopped")
        case .starting:
            return L("OpenClaw is starting")
        case .running:
            return L("OpenClaw is running")
        case .stopping:
            return L("OpenClaw is stopping")
        case let .error(message):
            return LF("OpenClaw error: %@", message)
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var serverStatus: ServerStatus = .stopped
    @Published var currentPort: Int = AppSettings.serverPort
    @Published var lastError: String?
    @Published var isFirstRun = false
    @Published var serverStartedAt: Date?

    var updateManager: UpdateManager?

    private let installer = FirstRunInstaller()
    private let serverManager = ServerManager()
    private var didBootstrap = false

    var serverUptime: TimeInterval? {
        guard let serverStartedAt else { return nil }
        return Date().timeIntervalSince(serverStartedAt)
    }

    private init() {
        serverManager.onStatusChange = { [weak self] status in
            Task { @MainActor in
                self?.serverStatus = status
                if status == .running {
                    self?.serverStartedAt = Date()
                }
            }
        }
        serverManager.onPortDetected = { [weak self] port in
            Task { @MainActor in
                self?.currentPort = port
            }
        }
        serverManager.onError = { [weak self] message in
            Task { @MainActor in
                self?.lastError = message
                self?.serverStatus = .error(message)
            }
        }
    }

    func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        do {
            isFirstRun = try installer.installOrMigrateIfNeeded()
            currentPort = AppSettings.serverPort
            if isFirstRun {
                WizardWindowController.shared.show(appState: self)
            } else if AppSettings.startServerOnLaunch {
                await startServer()
            }
        } catch {
            lastError = error.localizedDescription
            serverStatus = .error(error.localizedDescription)
        }
    }

    func startServer() async {
        serverStatus = .starting
        lastError = nil

        do {
            let port = PortManager().firstAvailablePort(startingAt: AppSettings.serverPort)
            currentPort = port
            let token = try AuthToken.ensureToken(in: AppSettings.dataLocationURL)
            try serverManager.start(
                preferredPort: port,
                dataDirectory: AppSettings.dataLocationURL,
                autoRestart: AppSettings.autoRestartServer
            )
            let isHealthy = await waitForHealthyServer(token: token, timeout: 20)
            if !isHealthy {
                lastError = L("Server did not pass health check within 20 seconds.")
                serverStatus = .error(lastError ?? L("Health check failed."))
            }
        } catch {
            lastError = error.localizedDescription
            serverStatus = .error(error.localizedDescription)
        }
    }

    func stopServer() {
        serverStatus = .stopping
        serverManager.stop()
        serverStartedAt = nil
        serverStatus = .stopped
    }

    func restartServer() async {
        stopServer()
        await startServer()
    }

    func openInBrowser() {
        guard currentPort > 0 else { return }
        let token = try? AuthToken.ensureToken(in: AppSettings.dataLocationURL)
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = currentPort
        components.path = "/"
        if let token {
            components.queryItems = [URLQueryItem(name: "token", value: token)]
        }
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func waitForHealthyServer(token: String, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await HealthCheck().ping(port: currentPort, token: token) {
                serverStatus = .running
                return true
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return false
    }

    func stopServerForTermination() {
        serverManager.stopForTermination()
    }
}
