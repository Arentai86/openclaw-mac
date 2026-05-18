import Foundation

struct HealthCheck {
    func ping(port: Int, token: String?) async -> Bool {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = port
        components.path = "/health"

        guard let url = components.url else { return false }

        var request = URLRequest(url: url, timeoutInterval: 1.5)
        if let token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

