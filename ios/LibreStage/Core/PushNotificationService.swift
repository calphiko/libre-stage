// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class PushNotificationService {
    static let shared = PushNotificationService()

    private enum Keys {
        static let didAskPermission = "push.didAskPermission"
        static let pendingDeviceToken = "push.pendingDeviceToken"
        static let seenGigIds = "push.seenGigIds"
        static let seenRehearsalIds = "push.seenRehearsalIds"
        static let seenSurveyIds = "push.seenSurveyIds"
    }

    private let reminderNotificationId = "push.open-surveys.reminder"
    private let userDefaults = UserDefaults.standard

    private init() {}

    func configureForActiveSession() async {
        await requestAuthorizationIfNeeded()
        await registerForRemoteNotificationsIfPossible()
        await syncPendingDeviceTokenIfPossible()
        await refreshOpenSurveyReminder()
    }

    func handleLogout() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderNotificationId])
    }

    func handleDidRegisterRemote(deviceToken: Data) async {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        userDefaults.set(token, forKey: Keys.pendingDeviceToken)
        await syncPendingDeviceTokenIfPossible()
    }

    func handleDidFailRemoteRegistration() {
        // Keep this intentionally quiet; local reminders continue to work without APNs.
    }

    func observeGigs(_ gigs: [GigOut]) {
        notifyForNewEntityIDs(
            incomingIDs: gigs.map(\.id),
            storeKey: Keys.seenGigIds,
            title: "Neue Gigs",
            bodyForCount: { count in
                count == 1 ? "Ein neues Gig wurde hinzugefuegt." : "\(count) neue Gigs wurden hinzugefuegt."
            }
        )
    }

    func observeRehearsals(_ rehearsals: [RehListElem]) {
        notifyForNewEntityIDs(
            incomingIDs: rehearsals.map(\.id),
            storeKey: Keys.seenRehearsalIds,
            title: "Neue Proben",
            bodyForCount: { count in
                count == 1 ? "Eine neue Probe wurde erstellt." : "\(count) neue Proben wurden erstellt."
            }
        )
    }

    func observeSurveys(_ surveys: [SurveyList]) {
        notifyForNewEntityIDs(
            incomingIDs: surveys.map(\.id),
            storeKey: Keys.seenSurveyIds,
            title: "Neue Umfragen",
            bodyForCount: { count in
                count == 1 ? "Eine neue Umfrage ist verfuegbar." : "\(count) neue Umfragen sind verfuegbar."
            }
        )
    }

    func markGigsAsSeen(_ gigs: [GigOut]) {
        mergeSeenEntityIDs(gigs.map(\.id), storeKey: Keys.seenGigIds)
    }

    func markRehearsalsAsSeen(_ rehearsals: [RehListElem]) {
        mergeSeenEntityIDs(rehearsals.map(\.id), storeKey: Keys.seenRehearsalIds)
    }

    func markSurveysAsSeen(_ surveys: [SurveyList]) {
        mergeSeenEntityIDs(surveys.map(\.id), storeKey: Keys.seenSurveyIds)
    }

    func refreshOpenSurveyReminder() async {
        do {
            let todoList: UserTodoList = try await APIClient.shared.get(path: "/user_todos")
            let openCount = todoList.surveys_to_feedback.count
            if openCount > 0 {
                await scheduleOpenSurveyReminder(openCount: openCount)
            } else {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderNotificationId])
            }
        } catch {
            // Keep existing schedule if the network is temporarily unavailable.
        }
    }

    func applyUserPreference(enabled: Bool) async {
        SettingsStore.shared.pushNotificationsEnabled = enabled

        if enabled {
            let isGranted = await ensureAuthorizationForUserToggle()
            guard isGranted else {
                SettingsStore.shared.pushNotificationsEnabled = false
                return
            }
            await registerForRemoteNotificationsIfPossible()
            await syncPendingDeviceTokenIfPossible()
            await refreshOpenSurveyReminder()
            return
        }

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderNotificationId])
        #if canImport(UIKit)
        await MainActor.run {
            UIApplication.shared.unregisterForRemoteNotifications()
        }
        #endif
    }

    private func requestAuthorizationIfNeeded() async {
        guard !userDefaults.bool(forKey: Keys.didAskPermission) else { return }
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            userDefaults.set(true, forKey: Keys.didAskPermission)
        } catch {
            userDefaults.set(true, forKey: Keys.didAskPermission)
        }
    }

    private func registerForRemoteNotificationsIfPossible() async {
        #if canImport(UIKit)
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        #endif
    }

    private func syncPendingDeviceTokenIfPossible() async {
        guard let token = userDefaults.string(forKey: Keys.pendingDeviceToken),
              !token.isEmpty else {
            return
        }

        struct PushRegistrationRequest: Encodable {
            let token: String
            let platform: String
        }

        do {
            struct EmptyResponse: Decodable {}
            let _: EmptyResponse = try await APIClient.shared.post(
                path: "/push/register",
                body: PushRegistrationRequest(token: token, platform: "ios")
            )
            userDefaults.removeObject(forKey: Keys.pendingDeviceToken)
        } catch let appError as AppError {
            if case .notFound = appError {
                // Backend endpoint not deployed yet; retry automatically on next login/start.
            }
        } catch {
            // Keep token and retry later.
        }
    }

    private func scheduleOpenSurveyReminder(openCount: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Offene Abstimmungen"
        content.body = openCount == 1
            ? "Du hast noch 1 offene Umfrage. Bitte gib dein Feedback ab."
            : "Du hast noch \(openCount) offene Umfragen. Bitte gib dein Feedback ab."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2 * 24 * 60 * 60, repeats: true)
        let request = UNNotificationRequest(identifier: reminderNotificationId, content: content, trigger: trigger)

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderNotificationId])
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Notification permission missing or schedule failed.
        }
    }

    private func notifyForNewEntityIDs(
        incomingIDs: [Int],
        storeKey: String,
        title: String,
        bodyForCount: (Int) -> String
    ) {
        let incomingSet = Set(incomingIDs)
        let storedSet = Set(userDefaults.array(forKey: storeKey) as? [Int] ?? [])

        if storedSet.isEmpty {
            userDefaults.set(Array(incomingSet), forKey: storeKey)
            return
        }

        let newIDs = incomingSet.subtracting(storedSet)
        if newIDs.isEmpty {
            return
        }

        userDefaults.set(Array(storedSet.union(incomingSet)), forKey: storeKey)
        postLocalNotification(title: title, body: bodyForCount(newIDs.count))
    }

    private func mergeSeenEntityIDs(_ ids: [Int], storeKey: String) {
        let storedSet = Set(userDefaults.array(forKey: storeKey) as? [Int] ?? [])
        let merged = storedSet.union(Set(ids))
        userDefaults.set(Array(merged), forKey: storeKey)
    }

    private func postLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func ensureAuthorizationForUserToggle() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            userDefaults.set(true, forKey: Keys.didAskPermission)
            return true
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                userDefaults.set(true, forKey: Keys.didAskPermission)
                return granted
            } catch {
                userDefaults.set(true, forKey: Keys.didAskPermission)
                return false
            }
        case .denied:
            userDefaults.set(true, forKey: Keys.didAskPermission)
            return false
        @unknown default:
            return false
        }
    }
}
