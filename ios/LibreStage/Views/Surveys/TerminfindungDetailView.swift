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
    let onFeedbackChanged: (() -> Void)?
    @Environment(AuthManager.self) private var authManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var vm         = SurveysViewModel()
    @State private var localUser: UserOut? = nil   // fallback if passedUser is nil
    @State private var isUpdating = false
    @State private var showOthers = false
    @State private var showVotingControls = false

    /// Best available user – parameter takes precedence, then session user, then local fetch.
    private var me: UserOut? { passedUser ?? authManager.currentUser ?? localUser }

    /// Only musicians are allowed to participate in appointment surveys.
    private var canParticipate: Bool { me?.musician ?? false }

    init(surveyId: Int, passedUser: UserOut? = nil, onFeedbackChanged: (() -> Void)? = nil) {
        self.surveyId = surveyId
        self.passedUser = passedUser
        self.onFeedbackChanged = onFeedbackChanged
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
            .listRowBackground(AppTheme.rowBackground(for: colorScheme))

            // ── Kombinierte Tabelle als Standardansicht ───────────────
            if !survey.fields.isEmpty {
                Section("Kombinierte Tabellenansicht") {
                    let fields = sortedFields(survey)
                    let topFieldIds = topOptionIds(survey)
                    let others = otherUsers(survey, me: me)

                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 6) {
                                tableHeaderCell("Termin", width: 150)
                                if let me {
                                    tableHeaderCell(me.clear_name ?? me.user_name, width: 92)
                                }
                                ForEach(others, id: \.id) { u in
                                    tableHeaderCell(u.clear_name, width: 92)
                                }
                                tableHeaderCell("Summe", width: 92)
                            }

                            ForEach(fields, id: \.id) { field in
                                let yes = field.feedbacks.filter { $0.value == "a" }.count
                                let maybe = field.feedbacks.filter { $0.value == "m" }.count
                                let no = field.feedbacks.filter { $0.value == "o" }.count

                                HStack(spacing: 6) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(shortDate(dateFromText(field.field_text)))
                                            .font(.caption.weight(topFieldIds.contains(field.id) ? .bold : .semibold))
                                            .foregroundStyle(topFieldIds.contains(field.id) ? .primary : .secondary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                        if topFieldIds.contains(field.id) {
                                            Text("Top")
                                                .font(.caption2.bold())
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.14))
                                                .foregroundStyle(.green)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .frame(width: 150, alignment: .leading)

                                    if let me {
                                        let current = field.feedbacks.first { $0.id_user == me.id }?.value
                                        tableVoteCell(
                                            survey: survey,
                                            field: field,
                                            userId: me.id,
                                            current: current,
                                            canEdit: canParticipate && !survey.closed,
                                            highlight: true
                                        )
                                    }

                                    ForEach(others, id: \.id) { u in
                                        let current = field.feedbacks.first { $0.id_user == u.id }?.value
                                        tableVoteCell(
                                            survey: survey,
                                            field: field,
                                            userId: u.id,
                                            current: current,
                                            canEdit: false,
                                            highlight: false
                                        )
                                    }

                                    tableSummaryCell(
                                        yes: yes,
                                        maybe: maybe,
                                        no: no,
                                        isTop: topFieldIds.contains(field.id)
                                    )
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }
                }
                .listRowBackground(AppTheme.rowBackground(for: colorScheme))
            }

            // ── Stimmabgabe (eingeklappt) ────────────────────────────
            Section {
                if let me {
                    let topFieldIds = topOptionIds(survey)
                    DisclosureGroup(isExpanded: $showVotingControls) {
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
                                        .fontWeight(topFieldIds.contains(field.id) ? .semibold : .regular)
                                    if topFieldIds.contains(field.id) {
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
                    } label: {
                        Text("Stimmabgabe")
                            .font(.body)
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
                Text("Abstimmen")
            } footer: {
                if me != nil && canParticipate && !survey.closed {
                    Text("Du kannst direkt in der Tabellenansicht abstimmen oder die Stimmabgabe aufklappen.")
                        .font(.caption2)
                } else if me != nil && !canParticipate {
                    Text("Nur Musiker können an dieser Terminumfrage teilnehmen.")
                        .font(.caption2)
                }
            }
            .listRowBackground(AppTheme.rowBackground(for: colorScheme))

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
                .listRowBackground(AppTheme.rowBackground(for: colorScheme))
            }

        }
        .softCardContainer()
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

    @ViewBuilder
    private func tableHeaderCell(_ title: String, width: CGFloat, isTop: Bool = false) -> some View {
        Text(title)
            .font(.caption.weight(isTop ? .bold : .semibold))
            .foregroundStyle(isTop ? .primary : .secondary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(width: width, alignment: .leading)
            .padding(.vertical, 6)
    }

    @ViewBuilder
    private func tableSummaryCell(yes: Int, maybe: Int, no: Int, isTop: Bool) -> some View {
        let score = yes - no
        let scoreText = score > 0 ? "+\(score)" : "\(score)"
        let scoreColor: Color = score > 0 ? .green : (score < 0 ? .red : .secondary)
        let backgroundColor: Color = isTop ? Color.green.opacity(0.14) : Color.secondary.opacity(0.08)

        VStack(spacing: 2) {
            Text(scoreText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(scoreColor)
            Text("\(maybe) vielleicht")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 92)
        .frame(minHeight: 44)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func tableVoteCell(
        survey: SurveyQuestionOut,
        field: SurveyFieldsOut,
        userId: Int,
        current: String?,
        canEdit: Bool,
        highlight: Bool
    ) -> some View {
        Button {
            guard canEdit && !isUpdating else { return }
            Task {
                isUpdating = true
                await castFeedback(
                    survey: survey,
                    field: field,
                    userId: userId,
                    newValue: nextValue(current)
                )
                isUpdating = false
            }
        } label: {
            Image(systemName: iconFor(current))
                .font(.caption.weight(.semibold))
                .foregroundStyle(colorFor(current))
                .frame(width: 92, height: 34)
                .background(colorFor(current).opacity(current == nil ? (highlight ? 0.12 : 0.08) : (highlight ? 0.24 : 0.18)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!canEdit || isUpdating)
    }

    // MARK: - Helpers

    private func sortedFields(_ s: SurveyQuestionOut) -> [SurveyFieldsOut] {
        s.fields.sorted { dateFromText($0.field_text) < dateFromText($1.field_text) }
    }

    private func topOptionIds(_ survey: SurveyQuestionOut) -> Set<Int> {
        let stats = voteStats(survey)
        guard let best = stats.first else { return [] }

        return Set(
            stats
                .filter { $0.score == best.score && $0.yes == best.yes && $0.maybe == best.maybe }
                .map(\.id)
        )
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
        // Supports both legacy local format and ISO8601 timestamps from backend.
        if let parsed = parseSurveyDate(t) {
            return parsed
        }
        return Date.distantFuture
    }

    private func formatDate(_ t: String) -> String {
        guard let d = parseSurveyDate(t) else { return t }
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateFormat = "EEE dd.MM.yy, HH:mm 'Uhr'"
        return df.string(from: d)
    }

    private func shortDate(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateFormat = "dd.MM HH:mm"
        return df.string(from: d)
    }

    private func parseSurveyDate(_ raw: String) -> Date? {
        let isoWithFractional = ISO8601DateFormatter()
        isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoWithFractional.date(from: raw) {
            return d
        }

        let isoStandard = ISO8601DateFormatter()
        isoStandard.formatOptions = [.withInternetDateTime]
        if let d = isoStandard.date(from: raw) {
            return d
        }

        let formats = [
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm"
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        for format in formats {
            df.dateFormat = format
            if let d = df.date(from: raw) {
                return d
            }
        }
        return nil
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
        if vm.error == nil {
            onFeedbackChanged?()
        }
    }
}
