// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var vm = ProfileViewModel()

    // Password change state
    @State private var showPasswordSheet = false
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    // Server URL change state
    @State private var showURLSheet = false
    @State private var newURL = ""

    // Logout confirmation
    @State private var showLogoutConfirm = false
    @State private var showAboutSheet = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: User Info
                if let user = authManager.currentUser {
                    Section("Mein Profil") {
                        LabeledContent("Name",        value: user.clear_name ?? "–")
                        LabeledContent("Benutzername",value: user.user_name)
                        LabeledContent("E-Mail",      value: user.email)
                        LabeledContent("Rolle",       value: user.user_group.rawValue.capitalized)
                        LabeledContent("Status",      value: user.status.rawValue.capitalized)
                    }
                }

                // MARK: Server
                Section("Server") {
                    LabeledContent("URL", value: SettingsStore.shared.backendURL)
                    Button("Server-URL ändern") {
                        newURL = SettingsStore.shared.backendURL
                        showURLSheet = true
                    }
                }

                // MARK: Security
                Section("Sicherheit") {
                    Button("Passwort ändern") {
                        oldPassword = ""
                        newPassword = ""
                        confirmPassword = ""
                        vm.passwordError = nil
                        vm.passwordSuccess = false
                        showPasswordSheet = true
                    }
                }

                Section("App") {
                    Button {
                        showAboutSheet = true
                    } label: {
                        Label("Über diese App", systemImage: "info.circle")
                    }
                }

                // MARK: Logout
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        Label("Abmelden", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Profil")
        }
        // MARK: - Password Sheet
        .sheet(isPresented: $showPasswordSheet) {
            NavigationStack {
                Form {
                    Section("Passwort ändern") {
                        SecureField("Aktuelles Passwort", text: $oldPassword)
                        SecureField("Neues Passwort",     text: $newPassword)
                        SecureField("Neues Passwort (Wiederholung)", text: $confirmPassword)
                    }
                    if let err = vm.passwordError {
                        Section {
                            Text(err).foregroundStyle(.red).font(.caption)
                        }
                    }
                    if vm.passwordSuccess {
                        Section {
                            Label("Passwort erfolgreich geändert", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    Section {
                        Button("Speichern") {
                            Task { await changePassword() }
                        }
                        .disabled(vm.isChangingPassword || newPassword.isEmpty || oldPassword.isEmpty)
                        Button("Abbrechen", role: .cancel) { showPasswordSheet = false }
                    }
                }
                .navigationTitle("Passwort")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        // MARK: - URL Sheet
        .sheet(isPresented: $showURLSheet) {
            NavigationStack {
                Form {
                    Section("Neue Server-URL") {
                        TextField("https://…", text: $newURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Section {
                        Button("Speichern & neu einloggen") {
                            authManager.changeServerURL(newURL)
                            showURLSheet = false
                        }
                        .foregroundStyle(.red)
                        Button("Abbrechen", role: .cancel) { showURLSheet = false }
                    }
                }
                .navigationTitle("Server-URL")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAboutSheet) {
            NavigationStack {
                AboutAppView(modalPresentation: true)
            }
        }
        // MARK: - Logout Confirmation
        .confirmationDialog("Wirklich abmelden?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Abmelden", role: .destructive) {
                Task { await authManager.logout() }
            }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    private func changePassword() async {
        guard newPassword == confirmPassword else {
            vm.passwordError = "Die neuen Passwörter stimmen nicht überein."
            return
        }
        guard let userId = authManager.currentUser?.id else { return }
        await vm.changePassword(userId: userId, old: oldPassword, new: newPassword)
        if vm.passwordSuccess {
            try? await Task.sleep(for: .seconds(1.5))
            showPasswordSheet = false
        }
    }
}

