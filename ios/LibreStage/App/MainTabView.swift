// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UserNotifications

struct MainTabView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var dashboardViewModel = DashboardViewModel()
    @State private var selectedTab = 0
    @State private var songVoteBadgeCount = 0
    @State private var requestedBadgePermission = false

    private var appIconBadgeCount: Int {
        dashboardViewModel.todoBadgeCount
        + dashboardViewModel.surveyBadgeCount
        + songVoteBadgeCount
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "checkmark.circle") }
                .tag(0)
                .badge(dashboardViewModel.totalBadgeCount)

            GigsView()
                .tabItem { Label("Gigs", systemImage: "music.mic") }
                .tag(1)

            RehearsalsView()
                .tabItem { Label("Proben", systemImage: "music.note.list") }
                .tag(2)

            SurveysView()
                .tabItem { Label("Umfragen", systemImage: "list.clipboard") }
                .tag(3)
                .badge(dashboardViewModel.surveyBadgeCount)

            SongsView()
                .tabItem { Label("Songs", systemImage: "music.note") }
                .tag(4)
                .badge(songVoteBadgeCount)

            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.circle") }
                .tag(5)
        }
        .environment(dashboardViewModel)
        .task {
            await requestBadgePermissionIfNeeded()
            await refreshAllBadges()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshAllBadges() }
        }
        .onChange(of: selectedTab) { _, _ in
            Task { await refreshAllBadges() }
        }
        .onChange(of: appIconBadgeCount) { _, newValue in
            Task { await setAppIconBadge(newValue) }
        }
    }

    @MainActor
    private func refreshAllBadges() async {
        await dashboardViewModel.load()
        await refreshSongVoteBadge()
        await setAppIconBadge(appIconBadgeCount)
    }

    @MainActor
    private func refreshSongVoteBadge() async {
        guard authManager.currentUser?.musician ?? false,
              let userId = authManager.currentUser?.id else {
            songVoteBadgeCount = 0
            return
        }

        do {
            let candidates: [SongCandidateOut] = try await APIClient.shared.get(path: "/songs/candidates/")
            songVoteBadgeCount = candidates.filter { song in
                !song.feedbacks.contains(where: { $0.user_id == userId })
            }.count
        } catch let appError as AppError {
            if case .notFound = appError {
                songVoteBadgeCount = 0
            } else {
                songVoteBadgeCount = 0
            }
        } catch {
            songVoteBadgeCount = 0
        }
    }

    @MainActor
    private func setAppIconBadge(_ value: Int) async {
        let count = max(0, value)
        try? await UNUserNotificationCenter.current().setBadgeCount(count)
    }

    @MainActor
    private func requestBadgePermissionIfNeeded() async {
        guard !requestedBadgePermission else { return }
        requestedBadgePermission = true
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.badge])
    }
}

