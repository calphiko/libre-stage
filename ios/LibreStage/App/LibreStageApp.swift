// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import UserNotifications

@main
struct LibreStageApp: App {
    @State private var authManager = AuthManager()

    init() {
        applyGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentRoot()
                .environment(authManager)
        }
    }

    private func applyGlobalAppearance() {
        #if canImport(UIKit)
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.86)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        #endif
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
                Task { await clearBadge() }
            }
        }
        .task {
            if !authManager.isLoggedIn {
                await clearBadge()
            }
        }
    }

    private func clearBadge() async {
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
    }
}

#Preview {
    ContentRoot()
        .environment(AuthManager())
}
