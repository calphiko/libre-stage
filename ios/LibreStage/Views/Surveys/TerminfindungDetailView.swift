// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct TerminfindungDetailView: View {
    private struct DateVoteStats: Identifiable {
        let id: Int
        let fieldText: String
        let yes: Int
        let maybe: Int
        let no: Int

        var total: Int { yes + maybe + no }
        var score: Int { yes - no }
    }

    let surveyId:   Int
    let passedUser: UserOut?    // provided by SurveysView at nav time
    @Environment(AuthManager.self) private var authManager

    @State private var vm         = SurveysViewModel()
    @State private var localUser: UserOut? = nil   // fallback if passedUser is nil
    @State private var isUpdating = false
    @State private var showOthers = false

    /// Best available user – parameter takes precedence, then session user, then local fetch.
    private var me: UserOut? { passedUser ?? authManager.currentUser ?? localUser }

    /// Only musicians are allowed to participate in appointment surveys.
    private var canParticipate: Bool { me?.musician ?? false }

    init(surveyId: Int, passedUser: UserOut? = nil) {
        self.surveyId = surveyId
        self.passedUser = passedUser
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let survey = vm.detail {
                listContent(survey, me: me)
                    .refreshable { await vm.loadDetail(id: surveyId) }
            } else if vm.isLoading {
                SkeletonList()
            } else {
                ContentUnavailableView("Umfrage nicht gefunden",
                                       systemImage: "calendar.badge.exclamationmark")
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
            if let sessionError = authManager.sessionError {
                vm.error = sessionError
            } else {
                vm.error = .unauthorized
            }
        }
    }

    // MARK: - List content

    @ViewBuilder
    private func listContent(_ survey: SurveyQuestionOut, me: UserOut?) -> some View {
        List {

            // ── Info Header ──────────────────────────────────────────
            Section {
                HStack {
                    Label("Terminfindung", systemImage: "calendar")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    statusBadge(survey.closed)
                }
                if survey.closed {
                    Text("Archiviert – keine Stimmabgabe mehr möglich.")
                        .font(.caption).foregroundStyle(.secondary).italic()
                }
            }

            // ── Termine (mein Votum + Auswertung) ───────────────────
            Section {
                if let me {
                    let topFieldId = voteStats(survey).first?.id

                    ForEach(sortedFields(survey)) { field in
                        let myFb = field.feedbacks.first { $0.id_user == me.id }
                        let yes = field.feedbacks.filter { $0.value == "a" }.count
                        let maybe = field.feedbacks.filter { $0.value == "m" }.count
                        let no = field.feedbacks.filter { $0.value == "o" }.count
                        let total = yes + maybe + no
                        let score = yes - no

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Text(formatDate(field.field_text))
                                    .font(.subheadline)
                                    .fontWeight(field.id == topFieldId ? .semibold : .regular)
                                if field.id == topFieldId {
                                    Text("Top")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.14))
                                        .foregroundStyle(.green)
                                        .clipShape(Capsule())
                                }
                                Spacer()
                                Text(score > 0 ? "+\(score)" : "\(score)")
                                    .font(.headline)
                                    .foregroundStyle(score > 0 ? .green : score < 0 ? .red : .secondary)
                            }

                            Button {
                                guard canParticipate && !survey.closed && !isUpdating else { return }
                                Task {
                                    isUpdating = true
                                    await castFeedback(survey: survey, field: field,
                                                       userId: me.id,
                                                       newValue: nextValue(myFb?.value))
                                    isUpdating = false
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    feedbackIcon(myFb?.value)
                                    Text("Mein Votum: \(labelFor(myFb?.value))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    if canParticipate && !survey.closed {
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(survey.closed || isUpdating || !canParticipate)

                            HStack(spacing: 6) {
                                scoreChip("checkmark.circle.fill", yes, .green)
                                scoreChip("questionmark.circle.fill", maybe, .yellow)
                                scoreChip("xmark.circle.fill", no, .red)
                                Spacer()
                                Text("\(total) Stimmen")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            stackedVoteBar(yes: yes, maybe: maybe, no: no)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(colorFor(myFb?.value).opacity(0.1))
                    }

                    if isUpdating {
                        HStack {
                            ProgressView().padding(.trailing, 4)
                            Text("Wird gespeichert…")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Benutzerkontext konnte nicht geladen werden.")
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
            } header: {
                Text("Termine")
            } footer: {
                if me != nil && canParticipate && !survey.closed {
                    Text("Tippen: Ja → Vielleicht → Nein → leer")
                        .font(.caption2)
                } else if me != nil && !canParticipate {
                    Text("Nur Musiker können an dieser Terminumfrage teilnehmen.")
                        .font(.caption2)
                }
            }

            // ── Andere Teilnehmer ────────────────────────────────────
            let others = otherUsers(survey, me: me)
            if !others.isEmpty {
                Section {
                    DisclosureGroup(
                        "Andere Teilnehmer (\(others.count))",
                        isExpanded: $showOthers
                    ) {
                        ForEach(others, id: \.id) { u in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(u.clear_name).font(.subheadline).bold()
                                ForEach(sortedFields(survey)) { field in
                                    let fb = field.feedbacks.first { $0.id_user == u.id }
                                    HStack(spacing: 8) {
                                        feedbackIcon(fb?.value)
                                        Text(formatDate(field.field_text))
                                            .font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                        Text(labelFor(fb?.value))
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

        }
    }

    // MARK: - Sub-views

    @ViewBuilder private func feedbackIcon(_ value: String?) -> some View {
        Image(systemName: iconFor(value)).foregroundStyle(colorFor(value)).font(.title3)
    }

    @ViewBuilder private func scoreChip(_ icon: String, _ count: Int, _ color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon).foregroundStyle(color).font(.caption2)
            Text("\(count)").font(.caption2).foregroundStyle(color)
        }
    }

    @ViewBuilder private func statusBadge(_ closed: Bool) -> some View {
        Text(closed ? "Archiviert" : "Offen")
            .font(.caption2).bold()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(closed ? Color.secondary.opacity(0.15) : Color.green.opacity(0.15))
            .foregroundStyle(closed ? Color.secondary : Color.green)
            .clipShape(Capsule())
    }

    // MARK: - Helpers

    private func sortedFields(_ s: SurveyQuestionOut) -> [SurveyFieldsOut] {
        s.fields.sorted { dateFromText($0.field_text) < dateFromText($1.field_text) }
    }

    private func voteStats(_ survey: SurveyQuestionOut) -> [DateVoteStats] {
        survey.fields
            .map { field in
                DateVoteStats(
                    id: field.id,
                    fieldText: field.field_text,
                    yes: field.feedbacks.filter { $0.value == "a" }.count,
                    maybe: field.feedbacks.filter { $0.value == "m" }.count,
                    no: field.feedbacks.filter { $0.value == "o" }.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                if lhs.yes != rhs.yes { return lhs.yes > rhs.yes }
                if lhs.maybe != rhs.maybe { return lhs.maybe > rhs.maybe }
                return dateFromText(lhs.fieldText) < dateFromText(rhs.fieldText)
            }
    }

    private func otherUsers(_ s: SurveyQuestionOut, me: UserOut?) -> [UserListElem] {
        guard let me else { return vm.users }
        return vm.users.filter { $0.id != me.id }
    }

    private func nextValue(_ v: String?) -> String? {
        switch v { case nil: return "a"; case "a": return "m"; case "m": return "o"; default: return nil }
    }

    private func colorFor(_ v: String?) -> Color {
        switch v { case "a": return .green; case "m": return .yellow; case "o": return .red; default: return .secondary }
    }

    private func iconFor(_ v: String?) -> String {
        switch v {
        case "a": return "checkmark.circle.fill"
        case "m": return "questionmark.circle.fill"
        case "o": return "xmark.circle.fill"
        default:  return "minus.circle"
        }
    }

    private func labelFor(_ v: String?) -> String {
        switch v {
        case "a": return "✓ Ja"
        case "m": return "~ Vielleicht"
        case "o": return "✗ Nein"
        default:  return "– Keine Angabe"
        }
    }

    @ViewBuilder
    private func stackedVoteBar(yes: Int, maybe: Int, no: Int) -> some View {
        let total = max(yes + maybe + no, 1)

        GeometryReader { proxy in
            let width = proxy.size.width
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.green)
                    .frame(width: width * CGFloat(yes) / CGFloat(total))
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: width * CGFloat(maybe) / CGFloat(total))
                Rectangle()
                    .fill(Color.red)
                    .frame(width: width * CGFloat(no) / CGFloat(total))
            }
            .clipShape(Capsule())
        }
        .frame(height: 10)
    }

    private func dateFromText(_ t: String) -> Date {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return df.date(from: t) ?? Date.distantFuture
    }

    private func formatDate(_ t: String) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm"
        if let d = df.date(from: t) {
            df.dateFormat = "EEE dd.MM.yy, HH:mm 'Uhr'"
            return df.string(from: d)
        }
        return t
    }

    // MARK: - Feedback payload

    @MainActor
    private func castFeedback(survey: SurveyQuestionOut, field: SurveyFieldsOut,
                               userId: Int, newValue: String?) async {
        guard canParticipate else {
            vm.error = .serverError(statusCode: 403, detail: "An Terminumfragen können nur Musiker teilnehmen.")
            return
        }

        var payload: [SurveyFeedbackPayload] = []
        for f in survey.fields {
            if f.id == field.id {
                for fb in f.feedbacks where fb.id_user != userId {
                    payload.append(.init(id_sv_field: f.id, id_user: fb.id_user,
                                        value: fb.value, comment: fb.comment))
                }
                if let v = newValue {
                    payload.append(.init(id_sv_field: f.id, id_user: userId,
                                        value: v, comment: nil))
                }
            } else {
                for fb in f.feedbacks {
                    payload.append(.init(id_sv_field: f.id, id_user: fb.id_user,
                                        value: fb.value, comment: fb.comment))
                }
            }
        }
        await vm.updateFeedback(surveyId: surveyId, feedbacks: payload)
    }
}
