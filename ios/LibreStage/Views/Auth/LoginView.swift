// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var serverURL = SettingsStore.shared.backendURL
    @State private var username  = ""
    @State private var password  = ""
    @State private var isCheckingHealth = false
    @State private var healthError: String?
    @State private var fieldError: String?

    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        return "iOS App v\(version)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.shellGradient(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        VStack(spacing: 10) {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)

                            Text("libreStage")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.onShellPrimary(for: colorScheme))

                            Text("Band-Orga mit Groove statt Tabellenchaos")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.onShellSecondary(for: colorScheme))
                        }
                        .padding(.top, 32)

                        VStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Server")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                TextField("https://dein-server.tld", text: $serverURL)
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)

                                if let err = healthError {
                                    Text(err)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Benutzername")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                TextField("z. B. calle", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Passwort")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                SecureField("Passwort", text: $password)
                                    .textFieldStyle(.roundedBorder)
                            }

                            if let err = fieldError ?? authManager.loginError {
                                Text(err)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                Task { await connect() }
                            } label: {
                                HStack(spacing: 8) {
                                    if authManager.isLoading || isCheckingHealth {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                    Text((authManager.isLoading || isCheckingHealth) ? "Verbinde..." : "Verbinden")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .background(Color.cyan.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .disabled(serverURL.isEmpty  || username.isEmpty || password.isEmpty || authManager.isLoading || isCheckingHealth)
                            .opacity(serverURL.isEmpty || username.isEmpty || password.isEmpty ? 0.6 : 1)
                        }
                        .glassCardStyle()
                        .padding(.horizontal)

                        Text(appVersionLabel)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.onShellSecondary(for: colorScheme))
                            .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Actions

    private func connect() async {
        healthError  = nil
        fieldError   = nil

        // Normalize URL before using it
        let normalizedURL = APIClient.normalizeURL(serverURL)
        serverURL = normalizedURL

        // 1. Validate URL
        isCheckingHealth = true
        do {
            try await APIClient.shared.checkHealth(serverURL: normalizedURL)
        } catch {
            if let appError = error as? AppError {
                healthError = appError.localizedMessage
            } else {
                healthError = "Server nicht erreichbar: \(error.localizedDescription)"
            }
            isCheckingHealth = false
            return
        }
        isCheckingHealth = false

        // 2. Login
        guard !username.isEmpty, !password.isEmpty else {
            fieldError = "Benutzername und Passwort dürfen nicht leer sein."
            return
        }
        await authManager.login(serverURL: normalizedURL, username: username, password: password)
    }
}

#Preview {
    LoginView()
        .environment(AuthManager())
}
