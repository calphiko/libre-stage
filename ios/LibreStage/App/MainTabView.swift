// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UserNotifications

struct AppMenuButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
                .font(.headline.weight(.semibold))
        }
        .accessibilityLabel("Navigation oeffnen")
    }
}

private enum AppSection: Int, CaseIterable, Identifiable {
    case dashboard
    case gigs
    case rehearsals
    case surveys
    case songs
    case profile

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .gigs: return "Gigs"
        case .rehearsals: return "Proben"
        case .surveys: return "Umfragen"
        case .songs: return "Songs"
        case .profile: return "Profil"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "checkmark.circle"
        case .gigs: return "music.mic"
        case .rehearsals: return "music.note.list"
        case .surveys: return "list.clipboard"
        case .songs: return "music.note"
        case .profile: return "person.circle"
        }
    }
}

struct MainTabView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(IncomingSongRouteStore.self) private var incomingSongRouteStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var dashboardViewModel = DashboardViewModel()
    @State private var selectedSection: AppSection = .dashboard
    @State private var isMenuOpen = false
    @State private var songVoteBadgeCount = 0
    @State private var requestedBadgePermission = false
    @State private var deepLinkSongPrefill: AddSongPrefillRequest?

    private var appIconBadgeCount: Int {
        dashboardViewModel.todoBadgeCount
        + dashboardViewModel.surveyBadgeCount
        + songVoteBadgeCount
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                activeSectionView
                    .tint(.cyan)
                    .background(AppTheme.shellGradient(for: colorScheme).ignoresSafeArea())
                    .environment(dashboardViewModel)
                    .disabled(isMenuOpen)
                    .overlay {
                        if isMenuOpen {
                            Color.black.opacity(0.24)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isMenuOpen = false
                                    }
                                }
                        }
                    }

                if isMenuOpen {
                    sideMenu(width: min(proxy.size.width * 0.78, 320))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isMenuOpen)
        }
        .task {
            await requestBadgePermissionIfNeeded()
            await refreshAllBadges()
            incomingSongRouteStore.importSharedHandoverIfAvailable()
            adoptIncomingSongPrefillIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            incomingSongRouteStore.importSharedHandoverIfAvailable()
            adoptIncomingSongPrefillIfNeeded()
            Task { await refreshAllBadges() }
        }
        .onChange(of: selectedSection) { _, _ in
            Task { await refreshAllBadges() }
        }
        .onChange(of: incomingSongRouteStore.pendingAddSongPrefill?.id) { _, newValue in
            guard newValue != nil else { return }
            adoptIncomingSongPrefillIfNeeded()
        }
        .onChange(of: appIconBadgeCount) { _, newValue in
            Task { await setAppIconBadge(newValue) }
        }
    }

    @ViewBuilder
    private var activeSectionView: some View {
        switch selectedSection {
        case .dashboard:
            DashboardView(onMenuTap: openMenu)
        case .gigs:
            GigsView(onMenuTap: openMenu)
        case .rehearsals:
            RehearsalsView(onMenuTap: openMenu)
        case .surveys:
            SurveysView(onMenuTap: openMenu)
        case .songs:
            NavigationStack {
                SongsView(externalAddSongPrefill: $deepLinkSongPrefill, onMenuTap: openMenu)
            }
        case .profile:
            ProfileView(onMenuTap: openMenu)
        }
    }

    private func openMenu() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isMenuOpen = true
        }
    }

    private func sideMenu(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Navigation")
                    .font(.headline)
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 6)

            ForEach(AppSection.allCases) { section in
                Button {
                    selectedSection = section
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isMenuOpen = false
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: section.icon)
                            .frame(width: 20)

                        Text(section.title)
                            .font(.body.weight(selectedSection == section ? .semibold : .regular))

                        Spacer()

                        let badge = badgeCount(for: section)
                        if badge > 0 {
                            Text("\(badge)")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .background(
                        selectedSection == section
                        ? AppTheme.cardBackground(for: colorScheme)
                        : Color.clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .trailing) {
            Divider()
        }
    }

    private func badgeCount(for section: AppSection) -> Int {
        switch section {
        case .dashboard:
            return dashboardViewModel.totalBadgeCount
        case .surveys:
            return dashboardViewModel.surveyBadgeCount
        case .songs:
            return songVoteBadgeCount
        default:
            return 0
        }
    }

    private func adoptIncomingSongPrefillIfNeeded() {
        guard let pending = incomingSongRouteStore.pendingAddSongPrefill else { return }
        deepLinkSongPrefill = pending
        incomingSongRouteStore.pendingAddSongPrefill = nil
        selectedSection = .songs
    }

    @MainActor
    private func refreshAllBadges() async {
        await dashboardViewModel.load()
        await PushNotificationService.shared.refreshOpenSurveyReminder()
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
