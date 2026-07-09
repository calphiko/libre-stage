// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import Charts

struct DashboardView: View {
    let onMenuTap: (() -> Void)?
    @Environment(DashboardViewModel.self) private var vm
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCandidatesSheet = false
    @State private var expandedTabs: Set<DashboardTodoTab> = [.open]
    @State private var hasLoadedInitially = false
    @State private var isRefreshingDashboard = false
    @State private var isInSubpage = false

    init(onMenuTap: (() -> Void)? = nil) {
        self.onMenuTap = onMenuTap
    }

    private var currentSeasonTitle: String {
        let year = Calendar.current.component(.year, from: Date())
        return "Aktuelle Saison \(year)"
    }

    var body: some View {
        @Bindable var vm = vm
        ZStack(alignment: .topLeading) {
            NavigationStack {
            ZStack {
                AppTheme.shellGradient(for: colorScheme).ignoresSafeArea()

                Group {
                    if vm.isLoading && vm.todoList == nil {
                        SkeletonList()
                    } else if let list = vm.todoList {
                        List {
                            Section {
                                ForEach(DashboardTodoTab.allCases) { tab in
                                    let count = tab.count(in: list)
                                    DisclosureGroup(
                                        isExpanded: Binding(
                                            get: { expandedTabs.contains(tab) },
                                            set: { isOpen in
                                                withAnimation(.easeInOut(duration: 0.22)) {
                                                    expandedTabs = isOpen ? [tab] : []
                                                }
                                            }
                                        )
                                    ) {
                                        todoSectionContent(for: tab, list: list)
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: tab.systemImage)
                                                .font(.subheadline)
                                                .foregroundStyle(tab.tint)
                                                .frame(width: 22)
                                            Text(tab.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                            if tab != .done && count > 0 {
                                                Text("\(count)")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.red, in: Capsule())
                                            }
                                        }
                                    }
                                }
                            } header: {
                                dashboardSectionHeader("Deine Todos", systemImage: "checklist", tint: .blue)
                            }
                            .listRowBackground(AppTheme.dashboardRowBackground(for: colorScheme))

                            Section {
                                HStack(alignment: .top, spacing: 10) {
                                    DashboardEventCard(
                                        title: "Nächste Probe",
                                        icon: "music.quarternote.3",
                                        tint: .blue,
                                        primary: vm.nextRehearsal.map {
                                            formatDateTime($0.begin, dateStyle: .medium, timeStyle: .short)
                                        } ?? "Keine Probe geplant",
                                        secondary: vm.nextRehearsal?.comment
                                    )

                                    DashboardEventCard(
                                        title: "Nächster Auftritt",
                                        icon: "music.mic",
                                        tint: .purple,
                                        primary: vm.nextGig.map {
                                            formatDateTime($0.datum, dateStyle: .medium, timeStyle: .none)
                                        } ?? "Kein Auftritt geplant",
                                        secondary: vm.nextGig?.name
                                    )
                                }
                            } header: {
                                dashboardSectionHeader("Nächste Termine", systemImage: "calendar", tint: .purple)
                            }
                            .listRowBackground(AppTheme.dashboardRowBackground(for: colorScheme))

                            Section {
                                if let stats = vm.currentSeasonStatistics {
                                    DashboardSeasonPlots(stats: stats)
                                } else {
                                    Text("Saisonstatistik wird geladen oder ist nicht verfügbar.")
                                        .foregroundStyle(.secondary)
                                }
                            } header: {
                                dashboardSectionHeader(currentSeasonTitle, systemImage: "chart.bar.xaxis", tint: .teal)
                            }
                            .listRowBackground(AppTheme.dashboardRowBackground(for: colorScheme))
                        }
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .listStyle(.insetGrouped)
                        .listSectionSpacing(14)
                        .refreshable {
                            await refreshDashboard()
                        }
                    } else {
                        ContentUnavailableView("Nichts gefunden", systemImage: "tray")
                    }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Dashboard")
                        .font(.headline)
                        .foregroundStyle(AppTheme.onShellPrimary(for: colorScheme))
                }
            }
            .headerBodyBlend()
            .fullScreenCover(isPresented: $showCandidatesSheet) {
                NavigationStack {
                    CandidatesView(modalPresentation: true)
                }
            }
            .errorBanner($vm.error)
            .task {
                guard !hasLoadedInitially else { return }
                hasLoadedInitially = true
                await refreshDashboard()
            }
            .onAppear {
                guard hasLoadedInitially else { return }
                Task { await refreshDashboard() }
            }
            .onChange(of: showCandidatesSheet) { _, isPresented in
                guard !isPresented else { return }
                Task { await refreshDashboard() }
            }
        }
        .onPreferenceChange(NavigationSubpagePreferenceKey.self) { isInSubpage = $0 }

        if let onMenuTap, !isInSubpage {
            AppMenuButton(action: onMenuTap)
                .padding(.leading, 12)
                .padding(.top, 0)
        }
    }
}

    @ViewBuilder
    private func todoSectionContent(for tab: DashboardTodoTab, list: UserTodoList) -> some View {
        switch tab {
        case .open:
            let openTodos = list.todo.filter { !$0.done }
            if openTodos.isEmpty {
                Label("Alle offenen To-dos erledigt", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                ForEach(openTodos) { todo in
                    TodoRow(todo: todo) {
                        Task { await vm.markDone(todo) }
                    }
                }
            }

        case .gigChecklist:
            if list.gig_checklist_todos.isEmpty {
                Text("Keine offenen Checklisten-Aufgaben.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(list.gig_checklist_todos) { item in
                    GigChecklistTodoRow(item: item) {
                        Task { await vm.markChecklistItemDone(gigId: item.gig_id, itemId: item.id) }
                    }
                }
            }

        case .songs:
            if list.songs_to_feedback.isEmpty {
                Text("Keine offenen Song-Votes")
                    .foregroundStyle(.secondary)
            } else {
                Button("Kandidaten bewerten (\(list.songs_to_feedback.count))") {
                    showCandidatesSheet = true
                }
                .buttonStyle(.borderedProminent)

                ForEach(list.songs_to_feedback.prefix(4)) { song in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title).font(.body)
                            Text(song.interpret).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

        case .surveys:
            if list.surveys_to_feedback.isEmpty {
                Text("Keine offenen Umfragen")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(list.surveys_to_feedback) { survey in
                    NavigationLink(survey.rf_survey) {
                        SurveyDetailView(surveyId: survey.id, surveyType: survey.kind_of_survey)
                            .onDisappear {
                                Task { await refreshDashboard() }
                            }
                    }
                }
            }

        case .pendingGigs:
            if list.pending_gigs.isEmpty {
                Text("Alle Auftritte haben eine Rueckmeldung von dir.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(list.pending_gigs) { gig in
                    PendingGigRow(gig: gig)
                }
            }

        case .done:
            let doneTodos = list.todo.filter { $0.done }
            if doneTodos.isEmpty {
                Text("Noch keine erledigten To-dos")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(doneTodos) { todo in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(todo.todo).font(.body)
                        Text("\(todo.song_title) – \(todo.song_interpret)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func dashboardSectionHeader(_ title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.onShellPrimary(for: colorScheme))

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.dashboardTileBackground(for: colorScheme))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.tileBorder(for: colorScheme), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
    }

    private func refreshDashboard() async {
        guard !isRefreshingDashboard else { return }
        isRefreshingDashboard = true
        defer { isRefreshingDashboard = false }

        await vm.load()
        withAnimation { expandedTabs = [.open] }
    }

    private func formatDateTime(
        _ raw: String?,
        dateStyle: DateFormatter.Style,
        timeStyle: DateFormatter.Style
    ) -> String {
        guard let parsed = parseDateSafe(raw) else { return "Unbekanntes Datum" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: parsed)
    }

    private func parseDateSafe(_ value: String?) -> Date? {
        guard let value else { return nil }

        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoWithFraction.date(from: value) {
            return date
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) {
            return date
        }

        let fullDate = ISO8601DateFormatter()
        fullDate.formatOptions = [.withFullDate]
        if let date = fullDate.date(from: value) {
            return date
        }

        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.dateFormat = "yyyy-MM-dd"
        return fallback.date(from: value)
    }
}

private enum DashboardTodoTab: String, CaseIterable, Identifiable {
    case open
    case gigChecklist
    case songs
    case surveys
    case pendingGigs
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open:         return "Offen"
        case .gigChecklist: return "Checkliste"
        case .songs:        return "Songvotes"
        case .surveys:      return "Umfragen"
        case .pendingGigs:  return "Auftritte"
        case .done:         return "Erledigt"
        }
    }

    var systemImage: String {
        switch self {
        case .open:         return "checkmark.circle"
        case .gigChecklist: return "list.bullet.clipboard"
        case .songs:        return "music.note.list"
        case .surveys:      return "chart.bar.doc.horizontal"
        case .pendingGigs:  return "music.mic"
        case .done:         return "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .open:         return .blue
        case .gigChecklist: return .orange
        case .songs:        return .pink
        case .surveys:      return .teal
        case .pendingGigs:  return .purple
        case .done:         return .green
        }
    }

    func count(in list: UserTodoList) -> Int {
        switch self {
        case .open:
            list.todo.filter { !$0.done }.count
        case .gigChecklist:
            list.gig_checklist_todos.count
        case .songs:
            list.songs_to_feedback.count
        case .surveys:
            list.surveys_to_feedback.count
        case .pendingGigs:
            list.pending_gigs.count
        case .done:
            list.todo.filter { $0.done }.count
        }
    }
}


private struct DashboardEventCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let icon: String
    let tint: Color
    let primary: String
    let secondary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(primary)
                .font(.subheadline.bold())
                .foregroundStyle(tint)

            if let secondary, !secondary.isEmpty {
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.dashboardTileBackground(for: colorScheme))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.tileBorder(for: colorScheme), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct DashboardSeasonPlots: View {
    let stats: SeasonStatistics

    private var topGenres: [(genre: String, count: Int)] {
        stats.genre_distribution
            .map { (genre: $0.key, count: $0.value) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 12) {
            DashboardPlotCard(title: "Gigs gespielt") {
                DashboardGigProgressPlot(playedGigCount: stats.played_gig_count, gigCount: stats.gig_count)
            }

            DashboardPlotCard(title: "Songs gesamt vs. Unique") {
                DashboardSongMixPlot(totalSongs: stats.total_songs, uniqueSongs: stats.unique_songs)
            }

            DashboardPlotCard(title: "Feedback-Durchschnitt") {
                DashboardFeedbackPlot(avg: stats.feedback_avg, count: stats.feedback_count)
            }

            DashboardPlotCard(title: "Genres in dieser Saison") {
                DashboardGenrePlot(entries: topGenres)
            }
        }
    }
}

private struct DashboardPlotCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            content
        }
        .padding(10)
        .background(AppTheme.dashboardTileBackground(for: colorScheme))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.tileBorder(for: colorScheme), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct DashboardGigProgressPlot: View {
    let playedGigCount: Int
    let gigCount: Int

    private var total: Int { max(gigCount, playedGigCount) }

    private var data: [(label: String, value: Int)] {
        [
            ("Gespielt", max(0, playedGigCount)),
            ("Offen", max(0, total - playedGigCount))
        ]
    }

    var body: some View {
        if total == 0 {
            Text("Keine Gigs vorhanden")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 160)
        } else {
            Chart(data, id: \.label) { item in
                SectorMark(
                    angle: .value("Anzahl", item.value),
                    innerRadius: .ratio(0.58),
                    angularInset: 2
                )
                .foregroundStyle(by: .value("Status", item.label))
            }
            .chartForegroundStyleScale([
                "Gespielt": Color.blue,
                "Offen": Color.gray.opacity(0.3)
            ])
            .frame(height: 170)
            .overlay {
                VStack(spacing: 2) {
                    Text("\(playedGigCount)/\(total)")
                        .font(.headline)
                    Text("\(Int((Double(playedGigCount) / Double(total)) * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct DashboardSongMixPlot: View {
    let totalSongs: Int
    let uniqueSongs: Int

    private var unique: Int { max(0, uniqueSongs) }
    private var repeated: Int { max(0, totalSongs - unique) }
    private var maxValue: Int { max(1, totalSongs, uniqueSongs) }

    var body: some View {
        if totalSongs == 0 && uniqueSongs == 0 {
            Text("Keine Songs vorhanden")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            Chart {
                BarMark(
                    xStart: .value("Von", 0),
                    xEnd: .value("Bis", unique),
                    y: .value("Kategorie", "Songs gesamt")
                )
                .foregroundStyle(.teal)

                BarMark(
                    xStart: .value("Von", unique),
                    xEnd: .value("Bis", unique + repeated),
                    y: .value("Kategorie", "Songs gesamt")
                )
                .foregroundStyle(.purple)
            }
            .frame(height: 130)
            .chartXScale(domain: 0...maxValue)

            HStack(spacing: 12) {
                Label("Unique: \(unique)", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.teal)
                Label("Wiederholt: \(repeated)", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.purple)
            }
        }
    }
}

private struct DashboardFeedbackPlot: View {
    let avg: Double?
    let count: Int

    var body: some View {
        if let avg, count > 0 {
            Chart {
                RectangleMark(
                    xStart: .value("Start", 1.0),
                    xEnd: .value("Ende", 2.0),
                    y: .value("Skala", "Feedback")
                )
                .foregroundStyle(.red.opacity(0.25))

                RectangleMark(
                    xStart: .value("Start", 2.0),
                    xEnd: .value("Ende", 2.5),
                    y: .value("Skala", "Feedback")
                )
                .foregroundStyle(.orange.opacity(0.25))

                RectangleMark(
                    xStart: .value("Start", 2.5),
                    xEnd: .value("Ende", 3.0),
                    y: .value("Skala", "Feedback")
                )
                .foregroundStyle(.green.opacity(0.25))

                RuleMark(x: .value("Durchschnitt", avg))
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))

                PointMark(
                    x: .value("Durchschnitt", avg),
                    y: .value("Skala", "Feedback")
                )
                .foregroundStyle(.blue)
                .symbolSize(80)
            }
            .chartXScale(domain: 1...3)
            .chartXAxis {
                AxisMarks(values: [1, 2, 3])
            }
            .frame(height: 120)

            Text("\(feedbackEmoji(for: avg)) Ø \(String(format: "%.2f", avg)) bei \(count) Bewertungen")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Noch kein Feedback vorhanden")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120)
        }
    }

    private func feedbackEmoji(for avg: Double) -> String {
        if avg >= 2.5 { return "😍" }
        if avg >= 1.5 { return "😊" }
        return "😐"
    }
}

private struct DashboardGenrePlot: View {
    let entries: [(genre: String, count: Int)]

    var body: some View {
        if entries.isEmpty {
            Text("Keine Genre-Daten vorhanden")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 130)
        } else {
            Chart(entries, id: \.genre) { entry in
                BarMark(
                    x: .value("Anzahl", entry.count),
                    y: .value("Genre", entry.genre)
                )
                .foregroundStyle(.purple.gradient)
                .annotation(position: .trailing) {
                    Text("\(entry.count)x")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: max(140, CGFloat(entries.count) * 30))
        }
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

private struct GigChecklistTodoRow: View {
    let item: GigChecklistTodo
    let onDone: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.body)
                HStack(spacing: 6) {
                    Text(item.gig_name)
                        .font(.caption).foregroundStyle(.secondary)
                    if let datum = item.gig_datum {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        Text(formatDate(datum))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let cat = item.category, !cat.isEmpty {
                    Text(cat)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                        .foregroundStyle(.secondary)
                }
                if item.isOverdue {
                    Label("Überfällig", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2).foregroundStyle(.red)
                }
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

    private func formatDate(_ raw: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        if let d = f.date(from: raw) {
            let out = DateFormatter()
            out.locale = Locale(identifier: "de_DE")
            out.dateStyle = .short
            return out.string(from: d)
        }
        return raw
    }
}

private struct PendingGigRow: View {
    let gig: PendingAvailabilityGig

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(gig.name ?? "Auftritt")
                    .font(.body)
                HStack(spacing: 6) {
                    if let datum = gig.datum {
                        Text(formatDate(datum))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let kind = gig.kind_of_gig, !kind.isEmpty {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        Text(kind).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Label("Noch keine Rückmeldung", systemImage: "questionmark.circle")
                .font(.caption2)
                .foregroundStyle(.orange)
                .labelStyle(.iconOnly)
        }
    }

    private func formatDate(_ raw: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        if let d = f.date(from: raw) {
            let out = DateFormatter()
            out.locale = Locale(identifier: "de_DE")
            out.dateStyle = .medium
            return out.string(from: d)
        }
        return raw
    }
}
