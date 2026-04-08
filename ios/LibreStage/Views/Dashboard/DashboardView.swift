// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct DashboardView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(DashboardViewModel.self) private var vm
    @State private var showCandidatesSheet = false

    private var currentSeasonTitle: String {
        let year = Calendar.current.component(.year, from: Date())
        return "Aktuelle Saison \(year)"
    }

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            Group {
                if vm.isLoading && vm.todoList == nil {
                    SkeletonList()
                } else if let list = vm.todoList {
                    List {
                        // MARK: Current season stats
                        Section {
                            if let stats = vm.currentSeasonStatistics {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                    SeasonStatTile(
                                        title: "Gigs",
                                        value: String(stats.gig_count),
                                        icon: "music.mic",
                                        tint: .blue
                                    )
                                    SeasonStatTile(
                                        title: "Songs",
                                        value: String(stats.total_songs),
                                        icon: "music.note.list",
                                        tint: .purple
                                    )
                                    SeasonStatTile(
                                        title: "Uebersprungen",
                                        value: String(stats.skipped_count),
                                        icon: "forward.fill",
                                        tint: .orange
                                    )
                                    SeasonStatTile(
                                        title: "Eingeschoben",
                                        value: String(stats.inserted_count),
                                        icon: "pin.fill",
                                        tint: .green
                                    )

                                    if let avg = stats.feedback_avg {
                                        SeasonStatTile(
                                            title: "Live-Bewertung",
                                            value: "\(feedbackEmoji(for: avg)) \(String(format: "%.2f", avg))",
                                            icon: "star.fill",
                                            tint: .yellow
                                        )
                                    }
                                }
                                .padding(.vertical, 2)
                            } else {
                                Text("Saisonstatistik wird geladen oder ist nicht verfuegbar.")
                                    .foregroundStyle(.secondary)
                            }
                        } header: {
                            Text(currentSeasonTitle)
                        }

                        // MARK: To-dos
                        Section("Proben-To-dos") {
                            let open = list.todo.filter { !$0.done }
                            if open.isEmpty {
                                Label("Alle erledigt 🎉", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                ForEach(open) { todo in
                                    TodoRow(todo: todo) {
                                        Task { await vm.markDone(todo) }
                                    }
                                }
                            }
                        }

                        // MARK: Song-Votes
                        Section("Ausstehende Song-Votes (\(list.songs_to_feedback.count))") {
                            if list.songs_to_feedback.isEmpty {
                                Text("Keine offenen Votes").foregroundStyle(.secondary)
                            } else {
                                Button("Kandidaten bewerten (\(list.songs_to_feedback.count))") {
                                    showCandidatesSheet = true
                                }
                            }
                        }

                        // MARK: Surveys
                        Section("Offene Umfragen (\(list.surveys_to_feedback.count))") {
                            if list.surveys_to_feedback.isEmpty {
                                Text("Keine offenen Umfragen").foregroundStyle(.secondary)
                            } else {
                                ForEach(list.surveys_to_feedback) { s in
                                    NavigationLink(s.rf_survey) {
                                        SurveyDetailView(surveyId: s.id, surveyType: s.kind_of_survey)
                                    }
                                }
                            }
                        }
                    }
                    .refreshable { await vm.load() }
                } else {
                    ContentUnavailableView("Nichts gefunden", systemImage: "tray")
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("Dashboard")
                            .font(.headline)
                    }
                }
            }
        }
        .sheet(isPresented: $showCandidatesSheet) {
            NavigationStack {
                CandidatesView(modalPresentation: true)
            }
        }
        .errorBanner($vm.error)
        .task { await vm.load() }
    }

    private func feedbackEmoji(for avg: Double) -> String {
        if avg >= 2.5 { return "😊" }
        if avg >= 1.5 { return "😐" }
        return "😞"
    }
}

private struct SeasonStatTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct TodoRow: View {
    let todo: UserTodo
    let onDone: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.todo).font(.body)
                Text("\(todo.song_title) – \(todo.song_interpret)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { onDone() } label: {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }
}

