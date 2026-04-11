// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import Charts

struct MeinungsumfrageDetailView: View {
    let surveyId: Int
    let passedUser: UserOut?
    let onFeedbackChanged: (() -> Void)?
    @Environment(AuthManager.self) private var authManager
    @State private var vm = SurveysViewModel()
    @State private var localUser: UserOut? = nil
    @State private var isUpdating = false
    @State private var expandedId: Int? = nil

    private var me: UserOut? { passedUser ?? authManager.currentUser ?? localUser }

    init(surveyId: Int, passedUser: UserOut? = nil, onFeedbackChanged: (() -> Void)? = nil) {
        self.surveyId = surveyId
        self.passedUser = passedUser
        self.onFeedbackChanged = onFeedbackChanged
    }

    private static let palette: [Color] = [
        .blue, .orange, .green, .red, .purple, .cyan, .yellow, .pink, .mint, .teal
    ]
    private func color(at index: Int) -> Color { Self.palette[index % Self.palette.count] }

    private var survey: SurveyQuestionOut? { vm.detail }

    // MARK: - Body

    var body: some View {
        let currentUser = me

        return Group {
            if let survey = vm.detail {
                listContent(survey, me: currentUser)
                    .refreshable { await vm.loadDetail(id: surveyId) }
            } else if vm.isLoading {
                SkeletonList()
            } else {
                ContentUnavailableView("Umfrage nicht gefunden", systemImage: "chart.bar")
            }
        }
        .navigationTitle(vm.detail?.rf_survey ?? "Umfrage")
        .navigationBarTitleDisplayMode(.inline)
        .errorBanner(
            $vm.error,
            actionTitle: vm.error?.isUnauthorized == true ? "Erneut einloggen" : nil,
            onAction: vm.error?.isUnauthorized == true ? { Task { await authManager.logout() } } : nil
        )
        .task {
            await ensureUserContext()
            await vm.loadDetail(id: surveyId)
        }
    }

    @MainActor
    private func ensureUserContext() async {
        guard me == nil else { return }
        await authManager.fetchMe()
        localUser = authManager.currentUser
        if localUser == nil {
            vm.error = authManager.sessionError ?? .unauthorized
        }
    }

    @ViewBuilder
    private func listContent(_ survey: SurveyQuestionOut, me: UserOut?) -> some View {
        List {

            // ── Header ─────────────────────────────────────────────────
            Section {
                HStack {
                    Label("Meinungsumfrage", systemImage: "chart.bar.fill")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    statusBadge(survey.closed)
                }
                if survey.closed {
                    Text("Archiviert \u{2013} keine Stimmabgabe mehr m\u{F6}glich.")
                        .font(.caption).foregroundStyle(.secondary).italic()
                }
            }

            if me == nil {
                Section("Anmeldung") {
                    Text("Benutzerkontext konnte nicht geladen werden. Abstimmen ist erst nach erfolgreicher Anmeldung möglich.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Button("Erneut versuchen") {
                            Task { await ensureUserContext() }
                        }
                        .buttonStyle(.bordered)

                        Button("Erneut einloggen") {
                            Task { await authManager.logout() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            // ── Balkendiagramm ─────────────────────────────────────────
            if !survey.fields.isEmpty {
                Section("Ergebnisse") {
                    Chart {
                        ForEach(Array(survey.fields.enumerated()), id: \.element.id) { idx, field in
                            BarMark(
                                x: .value("Option", "\(idx + 1)"),
                                y: .value("Stimmen", field.feedbacks.count)
                            )
                            .foregroundStyle(color(at: idx))
                            .annotation(position: .top, alignment: .center) {
                                Text("\(field.feedbacks.count)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(height: 150)
                    .chartYAxis { AxisMarks(values: .stride(by: 1)) }

                    FlowLayout(spacing: 6) {
                        ForEach(Array(survey.fields.enumerated()), id: \.element.id) { idx, field in
                            HStack(spacing: 4) {
                                Circle().fill(color(at: idx)).frame(width: 8, height: 8)
                                Text("\(idx + 1). \(field.field_text)")
                                    .font(.caption2).lineLimit(1)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }

            // ── Optionen ───────────────────────────────────────────────
            Section {
                if survey.fields.isEmpty {
                    Text("Keine Antwortoptionen definiert.")
                        .foregroundStyle(.secondary).italic()
                } else {
                    ForEach(Array(survey.fields.enumerated()), id: \.element.id) { idx, field in
                        optionRow(survey: survey, field: field, index: idx)
                    }
                }
                if isUpdating {
                    HStack {
                        ProgressView().padding(.trailing, 4)
                        Text("Wird gespeichert\u{2026}").font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Optionen")
            } footer: {
                if !survey.closed {
                    Text("Tippen um abzustimmen. Nochmal tippen um die Stimme zur\u{FC}ckzuziehen.")
                        .font(.caption2)
                }
            }
        }
    }

    // MARK: - Option Row

    @ViewBuilder
    private func optionRow(survey: SurveyQuestionOut, field: SurveyFieldsOut, index: Int) -> some View {
        let c        = color(at: index)
        let hasVoted = hasVoted(field)
        let isTop    = isTopVoted(survey: survey, field: field)
        let expanded = expandedId == field.id

        VStack(alignment: .leading, spacing: 0) {
            Button {
                guard !survey.closed && !isUpdating else { return }
                Task {
                    isUpdating = true
                    await toggleVote(survey: survey, field: field)
                    isUpdating = false
                }
            } label: {
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(hasVoted ? c : c.opacity(0.35))
                        .clipShape(Circle())
                        .shadow(color: hasVoted ? c.opacity(0.4) : .clear, radius: 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(field.field_text)
                            .font(.subheadline)
                            .fontWeight(isTop ? .bold : .regular)
                            .foregroundStyle(.primary)
                        if hasVoted {
                            Text("Deine Stimme \u{2713}")
                                .font(.caption2).foregroundStyle(c)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(field.feedbacks.count)")
                            .font(.title3.bold())
                            .foregroundStyle(hasVoted ? c : Color.secondary)
                        Text(field.feedbacks.count == 1 ? "Stimme" : "Stimmen")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(survey.closed || isUpdating)

            if !field.feedbacks.isEmpty {
                Divider()
                Button {
                    withAnimation { expandedId = expanded ? nil : field.id }
                } label: {
                    HStack {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                        Text(expanded
                             ? "Abstimmende ausblenden"
                             : "\(field.feedbacks.count) Abstimmende anzeigen")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    ForEach(field.feedbacks, id: \.id_user) { fb in
                        let name = vm.users.first { $0.id == fb.id_user }?.clear_name ?? "#\(fb.id_user)"
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill").font(.caption2).foregroundStyle(c)
                            Text(name).font(.caption).foregroundStyle(.secondary)
                            if let comment = fb.comment, !comment.isEmpty {
                                Text("\u{2013} \(comment)")
                                    .font(.caption).foregroundStyle(.secondary).italic()
                            }
                        }
                        .padding(.leading, 12).padding(.vertical, 2)
                    }
                }
            }
        }
        .listRowBackground(hasVoted ? c.opacity(0.08) : nil)
    }

    // MARK: - Status Badge

    @ViewBuilder
    private func statusBadge(_ closed: Bool) -> some View {
        Text(closed ? "Archiviert" : "Offen")
            .font(.caption2).bold()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(closed ? Color.secondary.opacity(0.15) : Color.green.opacity(0.15))
            .foregroundStyle(closed ? Color.secondary : Color.green)
            .clipShape(Capsule())
    }

    // MARK: - Helpers

    private func hasVoted(_ field: SurveyFieldsOut) -> Bool {
        guard let me = me else { return false }
        return field.feedbacks.contains { $0.id_user == me.id }
    }

    private func isTopVoted(survey: SurveyQuestionOut, field: SurveyFieldsOut) -> Bool {
        let max = survey.fields.map { $0.feedbacks.count }.max() ?? 0
        return max > 0 && field.feedbacks.count == max
    }

    // MARK: - API Payload Builder

    @MainActor
    private func toggleVote(survey: SurveyQuestionOut, field: SurveyFieldsOut) async {
        if me == nil {
            await ensureUserContext()
        }
        guard let me = me else {
            vm.error = authManager.sessionError ?? .unauthorized
            return
        }
        let userId  = me.id
        let alreadyVoted = hasVoted(field)
        var payload: [SurveyFeedbackPayload] = []

        for f in survey.fields {
            if f.id == field.id {
                for fb in f.feedbacks where fb.id_user != userId {
                    payload.append(.init(id_sv_field: f.id, id_user: fb.id_user,
                                        value: fb.value, comment: fb.comment))
                }
                if !alreadyVoted {
                    payload.append(.init(id_sv_field: f.id, id_user: userId,
                                        value: "a", comment: nil))
                }
                // If alreadyVoted: don't include user's entry → backend deletes it
            } else {
                for fb in f.feedbacks {
                    payload.append(.init(id_sv_field: f.id, id_user: fb.id_user,
                                        value: fb.value, comment: fb.comment))
                }
            }
        }
        await vm.updateFeedback(surveyId: surveyId, feedbacks: payload)
        if vm.error == nil {
            onFeedbackChanged?()
        }
    }
}

// MARK: - FlowLayout (für Diagramm-Legende)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = makeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { row in
            row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        }.reduce(0) { $0 + $1 + spacing }
        return CGSize(width: proposal.width ?? 0, height: max(0, height - spacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in makeRows(proposal: proposal, subviews: subviews) {
            var x = bounds.minX
            let h = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for sv in row {
                let s = sv.sizeThatFits(.unspecified)
                sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += h + spacing
        }
    }

    private func makeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxW = proposal.width ?? .infinity
        for sv in subviews {
            let w = sv.sizeThatFits(.unspecified).width
            if x + w > maxW, !rows[rows.count - 1].isEmpty { rows.append([]); x = 0 }
            rows[rows.count - 1].append(sv)
            x += w + spacing
        }
        return rows
    }
}
