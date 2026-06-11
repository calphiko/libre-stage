// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

private let keychainService = "de.librestage.app"

/// Central authentication manager.
/// Holds auth/session state and the current user.
/// Legacy bearer tokens are persisted in Keychain; cookie sessions are handled by URLSession.
@Observable
final class AuthManager {
    private let accessTokenKey  = "access_token"
    private let refreshTokenKey = "refresh_token"

    // MARK: - State

    /// Drives the ContentRoot switch. Set to true as soon as an auth session exists.
    var isLoggedIn: Bool = false

    /// Role extracted directly from the JWT on login – available immediately without fetchMe().
    var userGroupFromToken: UserGroup = .user

    var currentUser: UserOut? = nil
    var isLoading = false
    var loginError: String? = nil
    var sessionError: AppError? = nil

    var isAuthenticated: Bool { isLoggedIn }

    var accessToken: String? {
        get { KeychainHelper.load(service: keychainService, account: accessTokenKey) }
        set {
            if let v = newValue {
                KeychainHelper.save(service: keychainService, account: accessTokenKey, value: v)
            } else {
                KeychainHelper.delete(service: keychainService, account: accessTokenKey)
            }
        }
    }

    var refreshToken: String? {
        get { KeychainHelper.load(service: keychainService, account: refreshTokenKey) }
        set {
            if let v = newValue {
                KeychainHelper.save(service: keychainService, account: refreshTokenKey, value: v)
            } else {
                KeychainHelper.delete(service: keychainService, account: refreshTokenKey)
            }
        }
    }

    var userRole: UserGroup {
        // Prefer currentUser once loaded, fall back to token-extracted role
        currentUser?.user_group ?? userGroupFromToken
    }

    // MARK: - Init

    init() {
        // Restore session if token-based or cookie-based auth state exists.
        if KeychainHelper.load(service: keychainService, account: accessTokenKey) != nil
            || APIClient.shared.hasAuthSessionCookie(serverURL: SettingsStore.shared.backendURL) {
            isLoggedIn = true
            // Try to restore role from keychain
            if let roleRaw = KeychainHelper.load(service: keychainService, account: "user_group"),
               let role = UserGroup(rawValue: roleRaw) {
                userGroupFromToken = role
            }
            Task { await fetchMe() }
        }
    }

    // MARK: - Login

    @MainActor
    func login(serverURL: String, username: String, password: String) async {
        isLoading = true
        loginError = nil
        sessionError = nil

        SettingsStore.shared.backendURL = serverURL

        let body = LoginRequest(username: username, password: password)
        do {
            let response: LoginResponse = try await APIClient.shared.post(
                path: "/login",
                body: body,
                requiresAuth: false
            )
            if let access = response.access_token {
                accessToken = access
            }
            if let refresh = response.refresh_token {
                refreshToken = refresh
            }
            // Decode role from JWT payload immediately if available.
            if let access = response.access_token,
               let role = Self.roleFromJWT(access) {
                userGroupFromToken = role
                KeychainHelper.save(service: keychainService, account: "user_group", value: role.rawValue)
            }
            isLoggedIn = true
            await fetchMe()
        } catch let error as AppError {
            loginError = error.localizedMessage
            isLoggedIn = false
        } catch {
            loginError = error.localizedDescription
            isLoggedIn = false
        }
        isLoading = false
    }

    // MARK: - Logout

    @MainActor
    func logout() async {
        let body = LogoutRequest(refresh_token: refreshToken)
        _ = try? await APIClient.shared.post(path: "/logout", body: body) as EmptyResponse
        clearSession()
    }

    // MARK: - Me

    @MainActor
    func fetchMe() async {
        do {
            let user: UserOut = try await APIClient.shared.get(path: "/me")
            currentUser = user
            sessionError = nil
        } catch let e as AppError {
            sessionError = e
            if e.isUnauthorized {
                loginError = e.localizedMessage
            }
        } catch {
            sessionError = .networkError(error)
        }
    }

    // MARK: - URL change

    @MainActor
    func changeServerURL(_ newURL: String) {
        clearSession()
        SettingsStore.shared.backendURL = newURL
    }

    // MARK: - Helpers

    func clearSession() {
        KeychainHelper.delete(service: keychainService, account: accessTokenKey)
        KeychainHelper.delete(service: keychainService, account: refreshTokenKey)
        KeychainHelper.delete(service: keychainService, account: "user_group")
        APIClient.shared.clearAuthCookies(serverURL: SettingsStore.shared.backendURL)
        currentUser = nil
        sessionError = nil
        isLoggedIn  = false
        userGroupFromToken = .user
    }

    // MARK: - JWT helpers

    /// Extracts the ``role`` claim from a JWT without verifying the signature.
    /// Verification is done server-side; we just need the value for the UI.
    private static func roleFromJWT(_ token: String) -> UserGroup? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Pad to multiple of 4
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let roleRaw = json["role"] as? String,
              let role = UserGroup(rawValue: roleRaw) else { return nil }
        return role
    }
}

// MARK: - Codable helpers for auth endpoints

private struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct LoginResponse: Decodable {
    let access_token: String?
    let refresh_token: String?
    let token_type: String
}

private struct LogoutRequest: Encodable {
    let refresh_token: String?
}

struct EmptyResponse: Decodable {}

