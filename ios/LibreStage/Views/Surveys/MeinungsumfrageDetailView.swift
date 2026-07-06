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
    @Environment(\.colorScheme) private var colorScheme
    @State private var vm = SurveysViewModel()
    @State private var localUser: UserOut? = nil
    @State private var isUpdating = false
    @State private var expandedId: Int? = nil
    @State private var commentDraftByFieldId: [Int: String] = [:]
    @FocusState private var focusedCommentFieldId: Int?

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
                    .refreshable {
                        await vm.loadDetail(id: surveyId)
                        syncCommentDrafts(from: vm.detail, userId: me?.id)
                    }
            } else if vm.isLoading {
                SkeletonList()
            } else {
                ContentUnavailableView("Umfrage nicht gefunden", systemImage: "chart.bar")
            }
        }
        .appShellBackground()
        .navigationTitle(vm.detail?.rf_survey ?? "Umfrage")
        .navigationBarTitleDisplayMode(.inline)
        .headerBodyBlend()
        .errorBanner(
            $vm.error,
            actionTitle: vm.error?.isUnauthorized == true ? "Erneut einloggen" : nil,
            onAction: vm.error?.isUnauthorized == true ? { Task { await authManager.logout() } } : nil
        )
        .task {
            await ensureUserContext()
            await vm.loadDetail(id: surveyId)
            syncCommentDrafts(from: vm.detail, userId: me?.id)
        }
        .onChange(of: focusedCommentFieldId) { oldValue, newValue in
            guard let oldFieldId = oldValue,
                  oldFieldId != newValue,
                  let userId = me?.id else { return }

            Task {
                await persistCommentOnBlur(fieldId: oldFieldId, userId: userId)
            }
        }
        .navigationSubpage()
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
            .listRowBackground(AppTheme.rowBackground(for: colorScheme))

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
                .listRowBackground(AppTheme.rowBackground(for: colorScheme))
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
                .listRowBackground(AppTheme.rowBackground(for: colorScheme))
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
        .softCardContainer()
    }

    // MARK: - Option Row

    @ViewBuilder
    private func optionRow(survey: SurveyQuestionOut, field: SurveyFieldsOut, index: Int) -> some View {
        let c        = color(at: index)
        let hasVoted = hasVoted(field)
        let isTop    = isTopVoted(survey: survey, field: field)
        let expanded = expandedId == field.id
        let actionEnabled = !survey.closed && !isUpdating

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("\(index + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(hasVoted ? c : c.opacity(0.45))
                    .clipShape(Circle())

                Text(field.field_text)
                    .font(.subheadline)
                    .fontWeight(isTop ? .bold : .semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Spacer()

                Image(systemName: actionEnabled ? "hand.tap.fill" : "lock.fill")
                    .font(.caption)
                    .foregroundStyle(actionEnabled ? c : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(actionEnabled ? c.opacity(0.14) : Color.secondary.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(actionEnabled ? c.opacity(0.45) : Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .accessibilityAddTraits(.isButton)
            .onTapGesture {
                guard actionEnabled else { return }
                Task {
                    isUpdating = true
                    await toggleVote(survey: survey, field: field)
                    isUpdating = false
                }
            }

            HStack(spacing: 12) {
                if hasVoted {
                    Text("Deine Stimme \u{2713}")
                        .font(.caption2)
                        .foregroundStyle(c)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(field.feedbacks.count)")
                        .font(.title3.bold())
                        .foregroundStyle(hasVoted ? c : Color.secondary)
                    Text(field.feedbacks.count == 1 ? "Stimme" : "Stimmen")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 4)

            if let me,
               let myFeedback = field.feedbacks.first(where: { $0.id_user == me.id }) {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    TextField(
                        "Dein Kommentar (optional)",
                        text: Binding(
                            get: { commentDraft(for: field, userId: me.id) },
                            set: { commentDraftByFieldId[field.id] = $0 }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(1...3)
                    .textInputAutocapitalization(.sentences)
                    .focused($focusedCommentFieldId, equals: field.id)
                    .disabled(survey.closed || isUpdating)

                    if !survey.closed {
                        Button {
                            Task {
                                isUpdating = true
                                await updateComment(
                                    survey: survey,
                                    fieldId: field.id,
                                    userId: me.id
                                )
                                isUpdating = false
                            }
                        } label: {
                            Label("Kommentar speichern", systemImage: "text.bubble")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .disabled(isUpdating)
                    }
                }
                .padding(.vertical, 6)
            }

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
                    let comment = normalizedCommentDraft(forFieldId: f.id)
                    payload.append(.init(id_sv_field: f.id, id_user: userId,
                                        value: "a", comment: comment))
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
            syncCommentDrafts(from: vm.detail, userId: userId)
            onFeedbackChanged?()
        }
    }

    @MainActor
    private func updateComment(
        survey: SurveyQuestionOut,
        fieldId: Int,
        userId: Int
    ) async {
        let sourceSurvey = vm.detail ?? survey
        guard let field = sourceSurvey.fields.first(where: { $0.id == fieldId }) else { return }

        // Meinungsumfragen haben semantisch nur "hat abgestimmt"; falls der Backend-Wert leer ist,
        // senden wir stabil "a", damit der Kommentar persistiert.
        let currentValue = field.feedbacks.first(where: { $0.id_user == userId })?.value ?? "a"

        let updatedComment = normalizedCommentDraft(forFieldId: fieldId)
        var payload: [SurveyFeedbackPayload] = []

        for f in sourceSurvey.fields {
            if f.id == fieldId {
                for fb in f.feedbacks where fb.id_user != userId {
                    payload.append(.init(id_sv_field: f.id, id_user: fb.id_user,
                                        value: fb.value, comment: fb.comment))
                }
                payload.append(.init(id_sv_field: f.id, id_user: userId,
                                    value: currentValue, comment: updatedComment))
            } else {
                for fb in f.feedbacks {
                    payload.append(.init(id_sv_field: f.id, id_user: fb.id_user,
                                        value: fb.value, comment: fb.comment))
                }
            }
        }

        await vm.updateFeedback(surveyId: surveyId, feedbacks: payload)
        if vm.error == nil {
            syncCommentDrafts(from: vm.detail, userId: userId)
            onFeedbackChanged?()
        }
    }

    private func commentDraft(for field: SurveyFieldsOut, userId: Int) -> String {
        if let draft = commentDraftByFieldId[field.id] {
            return draft
        }
        return field.feedbacks.first(where: { $0.id_user == userId })?.comment ?? ""
    }

    private func normalizedCommentDraft(forFieldId fieldId: Int) -> String? {
        let trimmed = (commentDraftByFieldId[fieldId] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func syncCommentDrafts(from survey: SurveyQuestionOut?, userId: Int?) {
        guard let survey, let userId else {
            commentDraftByFieldId = [:]
            return
        }

        var next: [Int: String] = [:]
        for field in survey.fields {
            if let myFeedback = field.feedbacks.first(where: { $0.id_user == userId }) {
                next[field.id] = myFeedback.comment ?? ""
            }
        }
        commentDraftByFieldId = next
    }

    @MainActor
    private func persistCommentOnBlur(fieldId: Int, userId: Int) async {
        guard !isUpdating else { return }
        guard let survey = vm.detail else { return }
        guard let field = survey.fields.first(where: { $0.id == fieldId }) else { return }
        guard field.feedbacks.contains(where: { $0.id_user == userId }) else { return }

        let draft = normalizedCommentDraft(forFieldId: fieldId)
        let current = field.feedbacks
            .first(where: { $0.id_user == userId })?
            .comment?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let currentNormalized = (current?.isEmpty == true) ? nil : current

        guard draft != currentNormalized else { return }

        isUpdating = true
        await updateComment(survey: survey, fieldId: fieldId, userId: userId)
        isUpdating = false
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
