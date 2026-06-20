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

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

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

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { await PushNotificationService.shared.handleDidRegisterRemote(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushNotificationService.shared.handleDidFailRemoteRegistration()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
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

        // Form/List-Eingabefelder an das weiche Kartenlayout anpassen.
        let tableTextField = UITextField.appearance(whenContainedInInstancesOf: [UITableView.self])
        tableTextField.backgroundColor = .clear
        tableTextField.borderStyle = .none

        let tableTextView = UITextView.appearance(whenContainedInInstancesOf: [UITableView.self])
        tableTextView.backgroundColor = .clear

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
            if isLoggedIn {
                Task { await PushNotificationService.shared.configureForActiveSession() }
            } else {
                Task {
                    await clearBadge()
                    PushNotificationService.shared.handleLogout()
                }
            }
        }
        .task {
            if authManager.isLoggedIn {
                await PushNotificationService.shared.configureForActiveSession()
            } else {
                await clearBadge()
                PushNotificationService.shared.handleLogout()
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
