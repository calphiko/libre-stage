// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// MARK: - AppError

enum AppError: Error {
    case unauthorized
    case notFound
    case serverError(statusCode: Int, detail: String)
    case networkError(Error)
    case decodingError(Error)
    case invalidURL

    var localizedMessage: String {
        switch self {
        case .unauthorized:            return "Nicht autorisiert. Bitte erneut einloggen."
        case .notFound:                return "Ressource nicht gefunden."
        case .serverError(let c, let d): return "Serverfehler \(c): \(d)"
        case .networkError(let e):     return "Netzwerkfehler: \(e.localizedDescription)"
        case .decodingError(let e):    return "Datenfehler: \(e.localizedDescription)"
        case .invalidURL:              return "Ungültige Server-URL."
        }
    }

    var isUnauthorized: Bool {
        if case .unauthorized = self { return true }
        return false
    }
}

// MARK: - BackendErrorBody

private struct BackendErrorBody: Decodable {
    let detail: String?
}

// MARK: - APIClient

/// Central URLSession wrapper with automatic token refresh on HTTP 401.
@Observable
final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let encoder = JSONEncoder()

    #if DEBUG
    private static let debugNetworkLogging = true
    #else
    private static let debugNetworkLogging = false
    #endif

    // Coalesces concurrent refresh calls into one running task.
    private actor RefreshCoordinator {
        private var runningTask: Task<Void, Error>?

        func refresh(using action: @escaping () async throws -> Void) async throws {
            if let runningTask {
                return try await runningTask.value
            }

            let task = Task {
                try await action()
            }
            runningTask = task
            defer { runningTask = nil }
            try await task.value
        }
    }

    private let refreshCoordinator = RefreshCoordinator()

    // MARK: - Base URL

    private var baseURL: String {
        Self.normalizeURL(SettingsStore.shared.backendURL)
    }

    /// Ensures the URL has a scheme (defaults to https) and no trailing slash.
    static func normalizeURL(_ raw: String) -> String {
        var url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://\(url)"
        }
        return url
    }

    // MARK: - Public API

    func get<T: Decodable>(path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        try await perform(method: "GET", path: path, queryItems: queryItems, body: nil as EmptyBody?)
    }

    @discardableResult
    func post<Body: Encodable, T: Decodable>(path: String, body: Body, requiresAuth: Bool = true) async throws -> T {
        try await perform(method: "POST", path: path, body: body, requiresAuth: requiresAuth)
    }

    @discardableResult
    func put<Body: Encodable, T: Decodable>(path: String, body: Body) async throws -> T {
        try await perform(method: "PUT", path: path, body: body)
    }

    @discardableResult
    func patch<Body: Encodable, T: Decodable>(path: String, body: Body) async throws -> T {
        try await perform(method: "PATCH", path: path, body: body)
    }

    @discardableResult
    func delete<T: Decodable>(path: String) async throws -> T {
        try await perform(method: "DELETE", path: path, body: nil as EmptyBody?)
    }

    func delete(path: String) async throws {
        let _: EmptyResponse = try await perform(method: "DELETE", path: path, body: nil as EmptyBody?)
    }

    struct DownloadedFile {
        let data: Data
        let suggestedFilename: String?
    }

    func download(path: String, queryItems: [URLQueryItem] = []) async throws -> DownloadedFile {
        let request = try buildRequest(
            method: "GET",
            path: path,
            queryItems: queryItems,
            body: nil as EmptyBody?,
            requiresAuth: true
        )

        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkError(URLError(.badServerResponse))
        }

        try validateStatus(http.statusCode, data: data)
        let filename = Self.parseFilename(from: http.value(forHTTPHeaderField: "Content-Disposition"))
        return DownloadedFile(data: data, suggestedFilename: filename)
    }

    // MARK: - Health

    func checkHealth(serverURL: String) async throws {
        let clean = Self.normalizeURL(serverURL)
        guard let url = URL(string: "\(clean)/health") else { throw AppError.invalidURL }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "GET"
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AppError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, detail: "Health-Check fehlgeschlagen")
        }
    }

    // MARK: - Private

    private struct EmptyBody: Encodable {}
    private struct EmptyResponse: Decodable {}

    private func perform<Body: Encodable, T: Decodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: Body?,
        requiresAuth: Bool = true
    ) async throws -> T {
        let data = try await execute(method: method, path: path, queryItems: queryItems, body: body, requiresAuth: requiresAuth)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AppError.decodingError(error)
        }
    }

    private func execute<Body: Encodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem],
        body: Body?,
        requiresAuth: Bool
    ) async throws -> Data {
        let request = try buildRequest(method: method, path: path, queryItems: queryItems, body: body, requiresAuth: requiresAuth)

        let (data, response) = try await performRequest(request)

        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkError(URLError(.badServerResponse))
        }

        // Auto-refresh on 401. Parallel callers await the same refresh task.
        if http.statusCode == 401 && requiresAuth {
            try await refreshCoordinator.refresh { [self] in
                try await refreshAccessToken()
            }

            // Retry with new token
            let retryRequest = try buildRequest(method: method, path: path, queryItems: queryItems, body: body, requiresAuth: requiresAuth)
            let (retryData, retryResponse) = try await performRequest(retryRequest)

            guard let retryHttp = retryResponse as? HTTPURLResponse else {
                throw AppError.networkError(URLError(.badServerResponse))
            }
            try validateStatus(retryHttp.statusCode, data: retryData)
            return retryData
        }

        try validateStatus(http.statusCode, data: data)
        return data
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        if Self.debugNetworkLogging {
            let url = request.url?.absoluteString ?? "<invalid-url>"
            print("[API] \(request.httpMethod ?? "?") \(url)")
        }
        do {
            let result = try await session.data(for: request)
            if Self.debugNetworkLogging, let http = result.1 as? HTTPURLResponse {
                print("[API] <- \(http.statusCode) \(request.url?.path ?? "")")
            }
            return result
        } catch {
            if Self.debugNetworkLogging {
                print("[API] !! \(request.url?.path ?? "") \(error.localizedDescription)")
            }
            throw AppError.networkError(error)
        }
    }

    private func buildRequest<Body: Encodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem],
        body: Body?,
        requiresAuth: Bool
    ) throws -> URLRequest {
        var components = URLComponents(string: "\(baseURL)\(path)")
        if !queryItems.isEmpty { components?.queryItems = queryItems }
        guard let url = components?.url else { throw AppError.invalidURL }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth,
           let token = KeychainHelper.load(service: "de.librestage.app", account: "access_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body, !(body is EmptyBody) {
            request.httpBody = try encoder.encode(body)
        }
        return request
    }

    private func validateStatus(_ statusCode: Int, data: Data) throws {
        switch statusCode {
        case 200...299: return
        case 401: throw AppError.unauthorized
        case 404: throw AppError.notFound
        default:
            let detail = (try? decoder.decode(BackendErrorBody.self, from: data))?.detail ?? HTTPURLResponse.localizedString(forStatusCode: statusCode)
            throw AppError.serverError(statusCode: statusCode, detail: detail)
        }
    }

    private func refreshAccessToken() async throws {
        guard let refresh = KeychainHelper.load(service: "de.librestage.app", account: "refresh_token") else {
            throw AppError.unauthorized
        }
        struct RefreshBody: Encodable { let refresh_token: String }
        struct RefreshResponse: Decodable { let access_token: String; let refresh_token: String }

        guard let url = URL(string: "\(baseURL)/refresh") else { throw AppError.invalidURL }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(RefreshBody(refresh_token: refresh))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AppError.unauthorized
        }
        let refreshed = try decoder.decode(RefreshResponse.self, from: data)
        KeychainHelper.save(service: "de.librestage.app", account: "access_token", value: refreshed.access_token)
        KeychainHelper.save(service: "de.librestage.app", account: "refresh_token", value: refreshed.refresh_token)
    }

    private static func parseFilename(from contentDisposition: String?) -> String? {
        guard let contentDisposition else { return nil }

        if let quotedRange = contentDisposition.range(of: "filename=\""),
           let endQuote = contentDisposition[quotedRange.upperBound...].firstIndex(of: "\"") {
            return String(contentDisposition[quotedRange.upperBound..<endQuote])
        }

        if let plainRange = contentDisposition.range(of: "filename=") {
            let value = contentDisposition[plainRange.upperBound...]
            return value.split(separator: ";").first.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        return nil
    }
}
