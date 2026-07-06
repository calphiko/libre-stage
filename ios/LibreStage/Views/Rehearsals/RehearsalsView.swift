// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct RehearsalsView: View {
    let onMenuTap: (() -> Void)?
    @State private var vm = RehearsalsViewModel()
    @State private var showCreateSheet = false
    @State private var selectedTab = 0
    @State private var pastSearchQuery = ""
    @Environment(AuthManager.self) private var authManager
    @Environment(\.colorScheme) private var colorScheme

    init(onMenuTap: (() -> Void)? = nil) {
        self.onMenuTap = onMenuTap
    }

    var isEditor: Bool {
        authManager.userRole == .admin || authManager.userRole == .editor
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            NavigationStack {
            Group {
                if vm.isLoading && vm.rehearsals.isEmpty {
                    SkeletonList()
                } else if vm.rehearsals.isEmpty {
                    ContentUnavailableView("Keine Proben", systemImage: "music.note.list")
                } else {
                    VStack(spacing: 0) {
                        Picker("", selection: $selectedTab) {
                            Text("Aktuell (\(vm.upcomingRehearsals.count))").tag(0)
                            Text("Vergangen (\(vm.pastRehearsals.count))").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        if selectedTab == 0 {
                            upcomingList
                        } else {
                            pastList
                        }
                    }
                }
            }
            .appShellBackground()
            .navigationTitle("Proben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Proben")
                        .font(.headline)
                        .foregroundStyle(AppTheme.onShellPrimary(for: colorScheme))
                }
                if isEditor {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showCreateSheet = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .headerBodyBlend()
            .fullScreenCover(isPresented: $showCreateSheet) {
                AppModalContainer {
                    RehearsalCreateSheet { request in
                        await vm.create(request)
                    }
                }
            }
            .errorBanner($vm.error)
            .task { await vm.load() }
        }

        if let onMenuTap {
            AppMenuButton(action: onMenuTap)
                .padding(.leading, 12)
                .padding(.top, 0)
        }
    }
}

    // MARK: - Aktuelle Proben

    @ViewBuilder
    private var upcomingList: some View {
        if vm.upcomingRehearsals.isEmpty {
            ContentUnavailableView(
                "Keine bevorstehenden Proben",
                systemImage: "checkmark.circle",
                description: Text("Alle Proben liegen in der Vergangenheit.")
            )
        } else {
            List {
                Section("Aktuelle Proben") {
                    ForEach(vm.upcomingRehearsals) { reh in
                        NavigationLink {
                            RehearsalDetailView(rehearsal: reh, vm: vm)
                        } label: {
                            RehearsalRow(reh: reh, vm: vm, isPast: vm.isPast(reh))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if isEditor && !vm.isPast(reh) {
                                Button(role: .destructive) {
                                    Task { await vm.delete(reh) }
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listRowBackground(AppTheme.rowBackground(for: colorScheme))
            }
            .listStyle(.insetGrouped)
            .refreshable { await vm.load() }
        }
    }

    // MARK: - Vergangene Proben

    @ViewBuilder
    private var pastList: some View {
        if vm.pastRehearsals.isEmpty {
            ContentUnavailableView("Keine vergangenen Proben", systemImage: "clock")
        } else {
            List {
                let results = vm.filteredPastRehearsals(query: pastSearchQuery)
                if results.isEmpty {
                    Section("Vergangene Proben") {
                        Text("Keine Proben gefunden.")
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                    .listRowBackground(AppTheme.rowBackground(for: colorScheme))
                } else {
                    Section("Vergangene Proben") {
                        ForEach(results) { reh in
                            NavigationLink {
                                RehearsalDetailView(rehearsal: reh, vm: vm)
                            } label: {
                                RehearsalRow(reh: reh, vm: vm, isPast: vm.isPast(reh))
                            }
                        }
                    }
                    .listRowBackground(AppTheme.rowBackground(for: colorScheme))
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $pastSearchQuery, prompt: "Datum, Song oder Kommentar suchen")
            .refreshable { await vm.load() }
        }
    }
}

// MARK: - RehearsalRow

struct RehearsalRow: View {
    let reh: RehListElem
    let vm: RehearsalsViewModel
    var isPast: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(vm.formatDate(reh.begin)).font(.headline)
                if isPast {
                    Text("Protokoll")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            HStack(spacing: 6) {
                Label(vm.formatTime(reh.begin), systemImage: "clock")
                    .font(.caption).foregroundStyle(.secondary)
                if let end = reh.end {
                    Text("– \(vm.formatTime(end)) Uhr")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("·").foregroundStyle(.tertiary)
                Text("\(reh.songs.count) Songs")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let comment = reh.comment, !comment.isEmpty {
                Text(comment)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
