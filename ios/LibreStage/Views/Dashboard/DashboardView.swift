// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct DashboardView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(DashboardViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            Group {
                if vm.isLoading && vm.todoList == nil {
                    SkeletonList()
                } else if let list = vm.todoList {
                    List {
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
                                NavigationLink("Kandidaten bewerten (\(list.songs_to_feedback.count))") {
                                    CandidatesView()
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
        }
        .errorBanner($vm.error)
        .task { await vm.load() }
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

