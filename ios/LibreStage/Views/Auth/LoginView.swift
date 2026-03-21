// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var serverURL = SettingsStore.shared.backendURL
    @State private var username  = ""
    @State private var password  = ""
    @State private var isCheckingHealth = false
    @State private var healthError: String?
    @State private var fieldError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Logo
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Text("libre-stage")
                    .font(.largeTitle.bold())

                // Form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Server-URL (z. B. https://band.example.com)", text: $serverURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        if let err = healthError {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                    }

                    TextField("Benutzername", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    SecureField("Passwort", text: $password)
                        .textFieldStyle(.roundedBorder)

                    if let err = fieldError ?? authManager.loginError {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                }
                .padding(.horizontal)

                // Button
                Button {
                    Task { await connect() }
                } label: {
                    if authManager.isLoading || isCheckingHealth {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Verbinden")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(serverURL.isEmpty || username.isEmpty || password.isEmpty || authManager.isLoading || isCheckingHealth)
            }
            .padding(.vertical, 40)
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
            healthError = "Server nicht erreichbar: \(error.localizedDescription)"
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
