// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Persists the backend base URL in the Keychain using the native Security framework.
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    private let service = "de.librestage.app"
    private let urlKey  = "backend_url"
    private let pushNotificationsKey = "push_notifications_enabled"

    var backendURL: String {
        get { KeychainHelper.load(service: service, account: urlKey) ?? "" }
        set { KeychainHelper.save(service: service, account: urlKey, value: newValue) }
    }

    var pushNotificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: pushNotificationsKey) }
        set { UserDefaults.standard.set(newValue, forKey: pushNotificationsKey) }
    }

    private init() {}
}
