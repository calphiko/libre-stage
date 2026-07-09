// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct GigChecklistView: View {
    let gig: GigOut
    @Bindable var vm: GigDetailViewModel
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var showAddForm = false
    @State private var editingItem: GigChecklistItem? = nil
    @State private var formTitle = ""
    @State private var formCategory = ""
    @State private var formCategoryCustom = false   // true = "Eigene..." gewählt
    @State private var formAssigneeUserId: Int? = nil
    @State private var formAssigneeName = ""
    @State private var formDone = false
    @State private var formComment = ""
    @State private var showDeleteConfirm: GigChecklistItem? = nil

    private static let predefinedCategories = ["Equipment", "Soundcheck", "Aufbau", "Abbau", "Sonstiges"]

    /// Vordefinierte + bereits verwendete Kategorien, dedupliziert und sortiert
    private var allCategoryOptions: [String] {
        let used = vm.checklist.compactMap(\.category).filter { !$0.isEmpty }
        let merged = Set(Self.predefinedCategories + used)
        return merged.sorted()
    }

    private var canEdit: Bool {
        authManager.userRole == .admin || authManager.userRole == .editor
    }

    private var gigDate: Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        if let d = iso.date(from: gig.datum ?? "") { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: gig.datum ?? "")
    }

    /// Neue Checklisten-Items dürfen nur bis 2 Tage nach dem Gig hinzugefügt werden.
    private var canAddChecklistItems: Bool {
        guard let date = gigDate else { return true }
        let deadline = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: date))!
        return Calendar.current.startOfDay(for: Date()) <= deadline
    }

    private var total: Int { vm.checklist.count }
    private var doneCount: Int { vm.checklist.filter(\.done).count }
    private var progressPct: Double {
        total > 0 ? Double(doneCount) / Double(total) : 0
    }

    private var grouped: [(category: String, items: [GigChecklistItem])] {
        var dict: [String: [GigChecklistItem]] = [:]
        for item in vm.checklist {
            let cat = (item.category?.isEmpty == false) ? item.category! : "(ohne Kategorie)"
            dict[cat, default: []].append(item)
        }
        return dict.map { (category: $0.key, items: $0.value) }
            .sorted { $0.category < $1.category }
    }

    var body: some View {
        NavigationStack {
            List {
                if total > 0 {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(doneCount) / \(total) erledigt")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(progressPct * 100)) %")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(progressPct >= 1 ? .green : .accentColor)
                            }
                            ProgressView(value: progressPct)
                                .tint(progressPct >= 1 ? .green : .accentColor)
                        }
                        .padding(.vertical, 4)
                    }
                }

                if showAddForm && canEdit {
                    Section(editingItem == nil ? "Neuer Eintrag" : "Eintrag bearbeiten") {

                        // Titel
                        TextField("Titel *", text: $formTitle)

                        // ── Kategorie-Picker ──────────────────────────────
                        Picker("Kategorie", selection: Binding<String>(
                            get: { formCategoryCustom ? "__custom__" : formCategory },
                            set: { val in
                                if val == "__custom__" {
                                    formCategoryCustom = true
                                    formCategory = ""
                                } else {
                                    formCategoryCustom = false
                                    formCategory = val
                                }
                            }
                        )) {
                            Text("- Keine Kategorie -").tag("")
                            ForEach(allCategoryOptions, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                            Text("Eigene...").tag("__custom__")
                        }
                        .pickerStyle(.menu)

                        if formCategoryCustom {
                            TextField("Eigene Kategorie eingeben", text: $formCategory)
                        }

                        // ── Zuständigkeit: Bandmitglied ───────────────────
                        if vm.isUsersLoading {
                            HStack {
                                Text("Bandmitglieder werden geladen")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                                Spacer()
                                ProgressView().scaleEffect(0.8)
                            }
                        } else {
                            Picker("Zustaendig (Bandmitglied)", selection: $formAssigneeUserId) {
                                Text("- Keine Auswahl -").tag(Optional<Int>.none)
                                ForEach(vm.users) { user in
                                    Text(user.displayName)
                                        .tag(Optional(user.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: formAssigneeUserId) { _, _ in
                                if formAssigneeUserId != nil { formAssigneeName = "" }
                            }
                        }

                        // ── Zuständigkeit: externe Person ─────────────────
                        if formAssigneeUserId == nil {
                            TextField("Zustaendig (externe Person)", text: $formAssigneeName)
                        }

                        if editingItem != nil {
                            Toggle("Bereits erledigt", isOn: $formDone)
                        }

                        TextField("Kommentar / Ergebnis", text: $formComment, axis: .vertical)
                            .lineLimit(2...4)

                        HStack {
                            Button(editingItem == nil ? "Hinzufuegen" : "Speichern") {
                                Task { await saveForm() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(formTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                            Button("Abbrechen", role: .cancel) { cancelForm() }
                        }
                    }
                }

                if vm.isChecklistLoading && vm.checklist.isEmpty {
                    Section {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    }
                } else if total == 0 {
                    Section {
                        Text(canEdit && canAddChecklistItems
                             ? "Noch keine Eintraege. Tippe auf \"+\" um loszulegen."
                             : canEdit
                                 ? "Noch keine Eintraege. Frist zum Hinzufügen ist abgelaufen."
                                 : "Noch keine Eintraege.")
                            .foregroundStyle(.secondary).font(.subheadline)
                    }
                } else {
                    ForEach(grouped, id: \.category) { group in
                        Section(group.category) {
                            ForEach(group.items) { item in checklistRow(item) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Checkliste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                if canEdit {
                    ToolbarItem(placement: .primaryAction) {
                        if canAddChecklistItems {
                            Button {
                                openNewForm()
                            } label: {
                                Label("Hinzufuegen", systemImage: "plus")
                            }
                        } else {
                            Label("Frist abgelaufen", systemImage: "lock.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .task { await vm.loadChecklist(gigId: gig.id) }
            .refreshable { await vm.loadChecklist(gigId: gig.id) }
            .confirmationDialog(
                "Eintrag loeschen?",
                isPresented: Binding(
                    get: { showDeleteConfirm != nil },
                    set: { if !$0 { showDeleteConfirm = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let item = showDeleteConfirm {
                    Button("Loeschen", role: .destructive) {
                        Task { await vm.deleteChecklistItem(gigId: gig.id, itemId: item.id) }
                    }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                if let item = showDeleteConfirm {
                    Text(item.title + " wird geloescht.")
                }
            }
        }
    }

    @ViewBuilder
    private func checklistRow(_ item: GigChecklistItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                guard canEdit else { return }
                Task { await vm.toggleChecklistItemDone(gigId: gig.id, itemId: item.id) }
            } label: {
                Image(systemName: item.done ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(item.done ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canEdit)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body)
                    .strikethrough(item.done)
                    .foregroundStyle(item.done ? .secondary : .primary)
                HStack(spacing: 10) {
                    if let due = item.due_datetime {
                        Label(formatDue(due), systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(isDueOverdue(due) && !item.done ? .red : .secondary)
                    }
                    if let assignee = item.displayAssignee {
                        Label(assignee, systemImage: "person")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let comment = item.comment, !comment.isEmpty {
                    Text(comment).font(.caption).foregroundStyle(.secondary).italic()
                }
            }
            Spacer(minLength: 4)
            if canEdit {
                Menu {
                    Button {
                        openEditForm(item)
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = item
                    } label: {
                        Label("Loeschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func openNewForm() {
        editingItem = nil; formTitle = ""; formCategory = ""
        formCategoryCustom = false
        formAssigneeUserId = nil; formAssigneeName = ""; formDone = false; formComment = ""
        showAddForm = true
        Task { await vm.loadUsersIfNeeded() }
    }

    private func openEditForm(_ item: GigChecklistItem) {
        editingItem = item; formTitle = item.title
        let cat = item.category ?? ""
        if cat.isEmpty {
            formCategory = ""; formCategoryCustom = false
        } else if allCategoryOptions.contains(cat) {
            formCategory = cat; formCategoryCustom = false
        } else {
            formCategory = cat; formCategoryCustom = true
        }
        formAssigneeUserId = item.assignee_user_id; formAssigneeName = item.assignee_name ?? ""
        formDone = item.done; formComment = item.comment ?? ""
        showAddForm = true
        Task { await vm.loadUsersIfNeeded() }
    }

    private func cancelForm() { showAddForm = false; editingItem = nil }

    private func saveForm() async {
        let t = formTitle.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        let payload = GigChecklistItemIn(
            title: t,
            category: formCategory.isEmpty ? nil : formCategory,
            assignee_user_id: formAssigneeUserId,
            assignee_name: formAssigneeUserId != nil ? nil : (formAssigneeName.isEmpty ? nil : formAssigneeName),
            done: formDone,
            due_datetime: nil,
            position: editingItem?.position,
            comment: formComment.isEmpty ? nil : formComment
        )
        if let item = editingItem {
            await vm.updateChecklistItem(gigId: gig.id, itemId: item.id, item: payload)
        } else {
            await vm.createChecklistItem(gigId: gig.id, item: payload)
        }
        cancelForm()
    }

    private func formatDue(_ raw: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        if let date = f.date(from: raw) {
            let out = DateFormatter()
            out.locale = Locale(identifier: "de_DE")
            out.dateStyle = .short; out.timeStyle = .short
            return out.string(from: date)
        }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        if let date = f2.date(from: raw) {
            let out = DateFormatter()
            out.locale = Locale(identifier: "de_DE")
            out.dateStyle = .short; out.timeStyle = .short
            return out.string(from: date)
        }
        return raw
    }

    private func isDueOverdue(_ raw: String) -> Bool {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: raw) { return d < Date() }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        if let d = f2.date(from: raw) { return d < Date() }
        return false
    }
}
