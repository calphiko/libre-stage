// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import UserNotifications

// MARK: - AppDelegate (UIWindowScene.ActivationRequestOptions, iOS 17+)

/// Stellt sicher, dass die LibreStage-Scene beim URL-Open aus der Share Extension
/// zuverlässig in den Vordergrund geholt wird – auch auf iPadOS mit mehreren Scenes.
final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Wird aufgerufen, wenn iOS die App per URL-Scheme öffnet (u. a. aus Share Extensions).
    /// Ab iOS 17 aktivieren wir die vorderste inaktive/hintergründige Scene
    /// explizit über UIWindowScene.ActivationRequestOptions.
    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if #available(iOS 17.0, *) {
            activateForegroundScene(in: application)
        }
        // Eigentliches URL-Routing übernimmt SwiftUI via onOpenURL.
        return true
    }

    @available(iOS 17.0, *)
    private func activateForegroundScene(in application: UIApplication) {
        // Bevorzuge eine bereits halbaktive Scene; falle auf die erste verfügbare zurück.
        let targetSession = application.openSessions.first(where: {
            ($0.scene?.activationState == .foregroundInactive ||
             $0.scene?.activationState == .background)
        }) ?? application.openSessions.first

        guard let session = targetSession else { return }

        let activationOptions = UIWindowScene.ActivationRequestOptions()
        // requestingScene bleibt nil – keine andere Scene stellt die Anfrage.
        application.requestSceneSessionActivation(
            session,
            userActivity: nil,
            options: activationOptions,
            errorHandler: nil
        )
    }
}

// MARK: - App

@main
struct LibreStageApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var authManager = AuthManager()
    @State private var incomingSongRouteStore = IncomingSongRouteStore()

    init() {
        applyGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentRoot()
                .environment(authManager)
                .environment(incomingSongRouteStore)
                .onOpenURL { url in
                    incomingSongRouteStore.handleIncomingURL(url)
                }
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
