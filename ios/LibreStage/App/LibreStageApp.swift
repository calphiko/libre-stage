// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import UserNotifications

@main
struct LibreStageApp: App {
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentRoot()
                .environment(authManager)
        }
    }
}

struct ContentRoot: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onChange(of: authManager.isLoggedIn) { _, isLoggedIn in
            if !isLoggedIn {
                UIApplication.shared.applicationIconBadgeNumber = 0
                if #available(iOS 16.0, *) {
                    Task { try? await UNUserNotificationCenter.current().setBadgeCount(0) }
                }
            }
        }
        .task {
            if !authManager.isLoggedIn {
                UIApplication.shared.applicationIconBadgeNumber = 0
                if #available(iOS 16.0, *) {
                    try? await UNUserNotificationCenter.current().setBadgeCount(0)
                }
            }
        }
    }
}

#Preview {
    ContentRoot()
        .environment(AuthManager())
}
