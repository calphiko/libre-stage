// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct SurveysView: View {
    let onMenuTap: (() -> Void)?
    @State private var vm = SurveysViewModel()
    @Environment(AuthManager.self) private var authManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab      = 0
    @State private var closedSearchText = ""
    @State private var showNewSheet     = false
    @State private var showReminderAlert = false
    @State private var surveyToDelete:  SurveyList? = nil
    @State private var surveyToArchive: SurveyList? = nil

    init(onMenuTap: (() -> Void)? = nil) {
        self.onMenuTap = onMenuTap
    }

    // MARK: - Derived

    var filteredClosedSurveys: [SurveyList] {
        guard !closedSearchText.isEmpty else { return vm.closedSurveys }
        let q = closedSearchText.lowercased()
        return vm.closedSurveys.filter {
            $0.rf_survey.lowercased().contains(q) ||
            vm.userName(for: $0.user_created).lowercased().contains(q)
        }
    }

    // MARK: - Navigation destination helper

    @ViewBuilder
    private func surveyDestination(_ survey: SurveyList) -> some View {
        if survey.kind_of_survey == "Terminfindung" {
            TerminfindungDetailView(surveyId: survey.id,
                                    passedUser: authManager.currentUser,
                                    onFeedbackChanged: {
                                        Task { await vm.loadList() }
                                    })
        } else {
            MeinungsumfrageDetailView(surveyId: survey.id,
                                      passedUser: authManager.currentUser,
                                      onFeedbackChanged: {
                                          Task { await vm.loadList() }
                                      })
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            NavigationStack {
            // Always a VStack – stable root type, avoids navigation destination loss
            VStack(spacing: 0) {
                if vm.isLoading && vm.surveys.isEmpty {
                    SkeletonList()
                } else {
                    Picker("Tab", selection: $selectedTab) {
                        Text("Laufend (\(vm.activeSurveys.count))").tag(0)
                        Text("Abgeschlossen (\(vm.closedSurveys.count))").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if selectedTab == 0 {
                        activeSurveysList
                    } else {
                        closedSurveysList
                    }
                }
            }
            .appShellBackground()
            .navigationTitle("Umfragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Umfragen")
                        .font(.headline)
                        .foregroundStyle(AppTheme.onShellPrimary(for: colorScheme))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showNewSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .headerBodyBlend()
            .fullScreenCover(isPresented: $showNewSheet) {
                AppModalContainer {
                    NewSurveySheet { newSurvey in
                        await vm.createSurvey(newSurvey)
                    }
                }
            }
        }
        .confirmationDialog(
            "Umfrage l\u{F6}schen?",
            isPresented: Binding(get: { surveyToDelete != nil },
                                 set: { if !$0 { surveyToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("L\u{F6}schen", role: .destructive) {
                guard let s = surveyToDelete else { return }
                Task { await vm.deleteSurvey(id: s.id) }
                surveyToDelete = nil
            }
            Button("Abbrechen", role: .cancel) { surveyToDelete = nil }
        } message: {
            if let s = surveyToDelete {
                Text("\u{201E}\(s.rf_survey)\u{201C} l\u{F6}schen?\nNur m\u{F6}glich, wenn noch kein Feedback vorhanden ist.")
            }
        }
        .confirmationDialog(
            "Umfrage archivieren?",
            isPresented: Binding(get: { surveyToArchive != nil },
                                 set: { if !$0 { surveyToArchive = nil } }),
            titleVisibility: .visible
        ) {
            Button("Archivieren", role: .destructive) {
                guard let s = surveyToArchive else { return }
                Task { await vm.archiveSurvey(id: s.id) }
                surveyToArchive = nil
            }
            Button("Abbrechen", role: .cancel) { surveyToArchive = nil }
        } message: {
            if let s = surveyToArchive {
                Text("\u{201E}\(s.rf_survey)\u{201C} archivieren?\nArchivierte Umfragen k\u{F6}nnen nicht mehr bearbeitet werden.")
            }
        }
        .alert("Erinnerung gesendet",
               isPresented: $showReminderAlert,
               presenting: vm.reminderResult) { _ in
            Button("OK") { vm.reminderResult = nil }
        } message: { result in
            Text(reminderMessage(result))
        }
        .errorBanner(
            $vm.error,
            actionTitle: vm.error?.isUnauthorized == true ? "Erneut einloggen" : nil,
            onAction: vm.error?.isUnauthorized == true ? { Task { await authManager.logout() } } : nil
        )
        .task { await vm.loadList() }
        .onChange(of: vm.reminderResult) { _, new in
            if new != nil { showReminderAlert = true }
        }

        if let onMenuTap {
            AppMenuButton(action: onMenuTap)
                .padding(.leading, 12)
                .padding(.top, 0)
        }
        }
    }

    private func reminderMessage(_ result: ReminderResponse) -> String {
        if result.details.isEmpty {
            return "Alle haben bereits abgestimmt \u{2013} niemand muss erinnert werden."
        }
        let sent   = result.details.filter { $0.channel != "Failed" }.map(\.user).joined(separator: ", ")
        let failed = result.details.filter { $0.channel == "Failed"  }.map(\.user).joined(separator: ", ")
        var msg = sent.isEmpty ? "" : "Gesendet an: \(sent)"
        if !failed.isEmpty { msg += "\nFehlgeschlagen: \(failed)" }
        return msg
    }

    // MARK: - Active Surveys Tab

    private var activeSurveysList: some View {
        Group {
            if vm.activeSurveys.isEmpty {
                ContentUnavailableView(
                    "Keine laufenden Umfragen",
                    systemImage: "list.clipboard",
                    description: Text("Erstelle eine neue Abstimmung mit +")
                )
            } else {
                List {
                    ForEach(vm.activeSurveys) { survey in
                        Section {
                            NavigationLink(value: survey) {
                                SurveyRow(survey: survey, vm: vm, highlightNeedsVote: needsVote(survey))
                            }

                            if canManage(survey) {
                                HStack(spacing: 6) {
                                    Button {
                                        Task { await vm.sendReminder(surveyId: survey.id) }
                                    } label: {
                                        Label("Erinnern", systemImage: "bell.fill")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.orange)

                                    Button { surveyToArchive = survey } label: {
                                        Label("Archivieren", systemImage: "archivebox.fill")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.yellow)

                                    Button(role: .destructive) {
                                        surveyToDelete = survey
                                    } label: {
                                        Image(systemName: "trash.fill")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .listRowBackground(AppTheme.rowBackground(for: colorScheme))
                    }
                }
                .listSectionSpacing(.custom(0))
                .softCardContainer()
                // navigationDestination direkt auf der List – stabile Registrierung
                .navigationDestination(for: SurveyList.self) { survey in
                    surveyDestination(survey)
                }
                .refreshable { await vm.loadList() }
            }
        }
    }

    // MARK: - Closed Surveys Tab

    private var closedSurveysList: some View {
        Group {
            if vm.closedSurveys.isEmpty {
                ContentUnavailableView("Keine abgeschlossenen Umfragen", systemImage: "archivebox")
            } else {
                List {
                    if filteredClosedSurveys.isEmpty && !closedSearchText.isEmpty {
                        ContentUnavailableView.search(text: closedSearchText)
                    } else {
                        ForEach(filteredClosedSurveys) { survey in
                            Section {
                                NavigationLink(value: survey) {
                                    SurveyRow(survey: survey, vm: vm, highlightNeedsVote: false)
                                }
                                if isOwner(survey) || authManager.userRole == .admin {
                                    Button(role: .destructive) {
                                        surveyToDelete = survey
                                    } label: {
                                        Label("L\u{F6}schen", systemImage: "trash.fill")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                }
                            }
                            .listRowBackground(AppTheme.rowBackground(for: colorScheme))
                        }
                    }
                }
                .listSectionSpacing(.custom(0))
                .softCardContainer()
                // navigationDestination direkt auf der List – stabile Registrierung
                .navigationDestination(for: SurveyList.self) { survey in
                    surveyDestination(survey)
                }
                .searchable(text: $closedSearchText, prompt: "Titel oder Ersteller suchen")
                .refreshable { await vm.loadList() }
            }
        }
    }

    // MARK: - Helpers

    private func isOwner(_ s: SurveyList) -> Bool { s.user_created == authManager.currentUser?.id }
    private func canManage(_ s: SurveyList) -> Bool { isOwner(s) || authManager.userRole == .admin }
    private func needsVote(_ s: SurveyList) -> Bool { vm.pendingSurveyIds.contains(s.id) }
}

// MARK: - SurveyRow

struct SurveyRow: View {
    let survey: SurveyList
    let vm: SurveysViewModel
    let highlightNeedsVote: Bool

    private var statusLabel: String {
        if survey.closed   { return "Archiviert" }
        if survey.released { return "Offen" }
        return "Entwurf"
    }
    private var statusColor: Color {
        if survey.closed   { return .secondary }
        if survey.released { return .green }
        return .orange
    }
    private var formattedDate: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
                    "yyyy-MM-dd'T'HH:mm:ss'Z'",
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"] {
            df.dateFormat = fmt
            if let d = df.date(from: survey.release_date) {
                df.dateFormat = "dd.MM.yy"
                return df.string(from: d)
            }
        }
        return String(survey.release_date.prefix(10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(survey.rf_survey).font(.headline)
                Spacer()
                Text(statusLabel)
                    .font(.caption2).bold()
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(statusColor.opacity(0.15))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }
            if highlightNeedsVote {
                Label("Deine Abstimmung fehlt", systemImage: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            HStack {
                Label(
                    survey.kind_of_survey == "Terminfindung" ? "Terminfindung" : "Meinungsumfrage",
                    systemImage: survey.kind_of_survey == "Terminfindung" ? "calendar" : "chart.bar.fill"
                )
                .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(vm.userName(for: survey.user_created)) · \(formattedDate)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(highlightNeedsVote ? Color.orange.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
