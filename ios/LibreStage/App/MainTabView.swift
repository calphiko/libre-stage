// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct MainTabView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var dashboardViewModel = DashboardViewModel()
    @State private var selectedTab = 0

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

            SongsView()
                .tabItem { Label("Songs", systemImage: "music.note") }
                .tag(3)

            SurveysView()
                .tabItem { Label("Umfragen", systemImage: "list.clipboard") }
                .tag(4)
                .badge(dashboardViewModel.surveyBadgeCount)

            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.circle") }
                .tag(5)
        }
        .environment(dashboardViewModel)
        .task {
            await dashboardViewModel.load()
        }
    }
}

