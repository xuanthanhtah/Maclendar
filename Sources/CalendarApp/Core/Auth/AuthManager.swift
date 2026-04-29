import Foundation
import AppKit

@MainActor
class AuthManager: ObservableObject, GoogleAuthDelegate {
    static let shared = AuthManager()

    private static let clientIDEnvKey = "GOOGLE_CLIENT_ID"
    private static let clientSecretEnvKey = "GOOGLE_CLIENT_SECRET"
    let redirectURI = "http://127.0.0.1"
    let tokenEndpoint = "https://oauth2.googleapis.com/token"
    
    @Published var isAuthenticated: Bool = false
    
    private var authContinuation: CheckedContinuation<Void, Error>?
    
    private init() {
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        if let _ = getAccessToken() {
            isAuthenticated = true
        } else if let _ = getRefreshToken() {
            isAuthenticated = true
        }
    }
    
    func login() async throws {
        let oauthConfig = try readOAuthConfig()

        let scopes = [
            "https://www.googleapis.com/auth/calendar.events",
            "https://www.googleapis.com/auth/tasks"
        ].joined(separator: " ")

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: oauthConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "include_granted_scopes", value: "true")
        ]

        guard let authURL = components?.url else { return }
        
        let authVC = GoogleAuthViewController()
        authVC.authURL = authURL
        authVC.delegate = self
        
        let window = NSWindow(contentViewController: authVC)
        window.title = "Google Sign In"
        window.styleMask = [.titled, .closable]
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            self.authContinuation = continuation
        }
    }
    
    nonisolated func didCompleteAuth(withCode code: String) {
        Task { @MainActor in
            do {
                try await self.exchangeCodeForTokens(code: code)
                self.isAuthenticated = true
                self.authContinuation?.resume()
                self.authContinuation = nil
            } catch {
                self.authContinuation?.resume(throwing: error)
                self.authContinuation = nil
            }
        }
    }
    
    nonisolated func didFailAuth(withError error: Error) {
        Task { @MainActor in
            self.authContinuation?.resume(throwing: error)
            self.authContinuation = nil
        }
    }
    
    private func exchangeCodeForTokens(code: String) async throws {
        let oauthConfig = try readOAuthConfig()

        guard let url = URL(string: tokenEndpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = "code=\(code)&client_id=\(oauthConfig.clientID)&client_secret=\(oauthConfig.clientSecret)&redirect_uri=\(redirectURI)&grant_type=authorization_code"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "AuthError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to exchange code"])
        }
        
        try handleTokenResponse(data)
    }
    
    func refreshAccessToken() async throws -> String {
        let oauthConfig = try readOAuthConfig()

        guard let refreshToken = getRefreshToken() else {
            throw NSError(domain: "AuthError", code: 3, userInfo: [NSLocalizedDescriptionKey: "No refresh token"])
        }
        
        guard let url = URL(string: tokenEndpoint) else { throw NSError(domain: "AuthError", code: 4) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = "client_id=\(oauthConfig.clientID)&client_secret=\(oauthConfig.clientSecret)&refresh_token=\(refreshToken)&grant_type=refresh_token"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            logout()
            throw NSError(domain: "AuthError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to refresh token"])
        }
        
        try handleTokenResponse(data)
        
        if let newAccess = getAccessToken() {
            return newAccess
        } else {
            throw NSError(domain: "AuthError", code: 6)
        }
    }
    
    private func handleTokenResponse(_ data: Data) throws {
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let accessToken = json["access_token"] as? String {
                KeychainHelper.shared.save(accessToken.data(using: .utf8)!, service: "com.calendarapp.token", account: "access_token")
            }
            if let refreshToken = json["refresh_token"] as? String {
                KeychainHelper.shared.save(refreshToken.data(using: .utf8)!, service: "com.calendarapp.token", account: "refresh_token")
            }
        }
    }
    
    func logout() {
        KeychainHelper.shared.delete(service: "com.calendarapp.token", account: "access_token")
        KeychainHelper.shared.delete(service: "com.calendarapp.token", account: "refresh_token")
        isAuthenticated = false
    }
    
    func getAccessToken() -> String? {
        if let data = KeychainHelper.shared.read(service: "com.calendarapp.token", account: "access_token") {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    private func getRefreshToken() -> String? {
        if let data = KeychainHelper.shared.read(service: "com.calendarapp.token", account: "refresh_token") {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    private func readOAuthConfig() throws -> (clientID: String, clientSecret: String) {
        let env = ProcessInfo.processInfo.environment
        let dotenv = readDotEnvFile()
        let clientID = (env[Self.clientIDEnvKey] ?? dotenv[Self.clientIDEnvKey] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = (env[Self.clientSecretEnvKey] ?? dotenv[Self.clientSecretEnvKey] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clientID.isEmpty, !clientSecret.isEmpty else {
            throw NSError(
                domain: "AuthError",
                code: 7,
                userInfo: [
                    NSLocalizedDescriptionKey: "Missing OAuth credentials. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in environment variables or .env file."
                ]
            )
        }

        return (clientID, clientSecret)
    }

    private func readDotEnvFile() -> [String: String] {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".env")
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return [:]
        }

        var values: [String: String] = [:]
        let lines = content.split(whereSeparator: \Character.isNewline)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }

            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            values[key] = value
        }

        return values
    }
}
