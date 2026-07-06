// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct ProfileView: View {
    let onMenuTap: (() -> Void)?
    @Environment(AuthManager.self) private var authManager
    @Environment(\.colorScheme) private var colorScheme
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
    @State private var showShareDebugSheet = false

    private var pushNotificationsBinding: Binding<Bool> {
        Binding(
            get: { SettingsStore.shared.pushNotificationsEnabled },
            set: { newValue in
                Task { await PushNotificationService.shared.applyUserPreference(enabled: newValue) }
            }
        )
    }

    init(onMenuTap: (() -> Void)? = nil) {
        self.onMenuTap = onMenuTap
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            NavigationStack {
            Form {
                Section {
                    Label("Account, Sicherheit und App-Einstellungen", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(AppTheme.rowBackground(for: colorScheme))

                // MARK: User Info
                if let user = authManager.currentUser {
                    Section("Mein Profil") {
                        LabeledContent("Name",        value: user.clear_name ?? "–")
                        LabeledContent("Benutzername",value: user.user_name)
                        LabeledContent("E-Mail",      value: user.email)
                        LabeledContent("Rolle",       value: user.user_group.rawValue.capitalized)
                        LabeledContent("Status",      value: user.status.rawValue.capitalized)
                    }
                    .listRowBackground(AppTheme.rowBackground(for: colorScheme))
                }

                // MARK: Server
                Section("Server") {
                    LabeledContent("URL", value: SettingsStore.shared.backendURL)
                    Button("Server-URL ändern") {
                        newURL = SettingsStore.shared.backendURL
                        showURLSheet = true
                    }
                }
                .listRowBackground(AppTheme.rowBackground(for: colorScheme))

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
                .listRowBackground(AppTheme.rowBackground(for: colorScheme))

                Section("App") {
                    Toggle(isOn: pushNotificationsBinding) {
                        Label("Push-Benachrichtigungen", systemImage: "bell.badge")
                    }
                    .disabled(true)

                    Text("Bald verfuegbar")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        showAboutSheet = true
                    } label: {
                        Label("Über diese App", systemImage: "info.circle")
                    }

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Datenschutz", systemImage: "hand.raised")
                    }

                    Button {
                        showShareDebugSheet = true
                    } label: {
                        Label("Share-Diagnose (Shazam)", systemImage: "ladybug")
                    }
                }
                .listRowBackground(AppTheme.rowBackground(for: colorScheme))

                // MARK: Logout
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        Label("Abmelden", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                .listRowBackground(AppTheme.rowBackground(for: colorScheme))
            }
            .softCardContainer()
            .appShellBackground()
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Profil")
                        .font(.headline)
                        .foregroundStyle(AppTheme.onShellPrimary(for: colorScheme))
                }
            }
            .headerBodyBlend()
        // MARK: - Password Sheet
        .fullScreenCover(isPresented: $showPasswordSheet) {
            AppModalContainer {
                NavigationStack {
                Form {
                    Section {
                        Label("Passwort sicher aktualisieren", systemImage: "lock.shield")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(AppTheme.rowBackground(for: colorScheme))

                    Section("Passwort ändern") {
                        SecureField("Aktuelles Passwort", text: $oldPassword)
                            .formFieldSurface()
                        SecureField("Neues Passwort",     text: $newPassword)
                            .formFieldSurface()
                        SecureField("Neues Passwort (Wiederholung)", text: $confirmPassword)
                            .formFieldSurface()
                    }
                    .listRowBackground(AppTheme.rowBackground(for: colorScheme))

                    if let err = vm.passwordError {
                        Section {
                            Text(err).foregroundStyle(.red).font(.caption)
                        }
                        .listRowBackground(AppTheme.rowBackground(for: colorScheme))
                    }

                    if vm.passwordSuccess {
                        Section {
                            Label("Passwort erfolgreich geändert", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .listRowBackground(AppTheme.rowBackground(for: colorScheme))
                    }

                    Section {
                        Button("Speichern") {
                            Task { await changePassword() }
                        }
                        .disabled(vm.isChangingPassword || newPassword.isEmpty || oldPassword.isEmpty)

                        Button("Abbrechen", role: .cancel) { showPasswordSheet = false }
                    }
                    .listRowBackground(AppTheme.rowBackground(for: colorScheme))
                }
                .softCardContainer()
                .appShellBackground()
                .navigationTitle("Passwort")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 8) {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Text("Passwort")
                                .font(.headline)
                                .foregroundStyle(AppTheme.onShellPrimary(for: colorScheme))
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Fertig") {
                            showPasswordSheet = false
                        }
                    }
                }
                .headerBodyBlend()
            }
            }
        }
        // MARK: - URL Sheet
        .fullScreenCover(isPresented: $showURLSheet) {
            AppModalContainer {
                NavigationStack {
                Form {
                    Section("Neue Server-URL") {
                        TextField("https://…", text: $newURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .formFieldSurface()
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
                .softCardContainer()
                .appShellBackground()
                .navigationTitle("Server-URL")
                .navigationBarTitleDisplayMode(.inline)
            }
            }
        }
        .fullScreenCover(isPresented: $showAboutSheet) {
            AppModalContainer {
                NavigationStack {
                    AboutAppView(modalPresentation: true)
                }
            }
        }
        .fullScreenCover(isPresented: $showShareDebugSheet) {
            AppModalContainer {
                ShareDebugView(modalPresentation: true)
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

        if let onMenuTap {
            AppMenuButton(action: onMenuTap)
                .padding(.leading, 12)
                .padding(.top, 0)
        }
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
