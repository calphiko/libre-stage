// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Vollbild-Sheet fuer die Anwesenheitsverfolgung eines Gigs.
/// Spiegelt das AvailabilityWidget.svelte aus dem Web-Frontend.
struct GigAvailabilityView: View {
    let gig: GigOut
    @Bindable var vm: GigDetailViewModel
    @Environment(AuthManager.self) private var authManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var myStatus: String = ""
    @State private var myComment: String = ""
    @State private var substituteName: String = ""
    @State private var substituteUserId: Int? = nil

    private var currentUserId: Int? { authManager.currentUser?.id }

    private var gigDate: Date? {
        guard let datum = gig.datum else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        if let d = iso.date(from: datum) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: datum)
    }

    /// Rückmeldung ist nur bis einschließlich dem Tag des Gigs möglich (0 Tage danach).
    private var canSubmitAvailability: Bool {
        guard let date = gigDate else { return true }
        let gigDay = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: Date())
        return today <= gigDay
    }

    private var available: [AvailabilityEntry] {
        vm.availability?.availabilities.filter { $0.status == "available" } ?? []
    }
    private var maybe: [AvailabilityEntry] {
        vm.availability?.availabilities.filter { $0.status == "maybe" } ?? []
    }
    private var unavailable: [AvailabilityEntry] {
        vm.availability?.availabilities.filter { $0.status == "unavailable" } ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: Eigene Verfuegbarkeit
                Section("Meine Verfuegbarkeit") {
                    if canSubmitAvailability {
                        HStack(spacing: 8) {
                            statusButton(label: "Dabei", icon: "checkmark.circle.fill", color: .green, status: "available")
                            statusButton(label: "Vielleicht", icon: "questionmark.circle.fill", color: .orange, status: "maybe")
                            statusButton(label: "Absage", icon: "xmark.circle.fill", color: .red, status: "unavailable")
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                        if !myStatus.isEmpty {
                            TextField("Kommentar (optional)", text: $myComment)
                                .onSubmit { saveAvailability() }

                            Button("Rueckmeldung zurueckziehen", role: .destructive) {
                                Task { await clearAvailability() }
                            }
                            .font(.subheadline)
                        }

                        if vm.isAvailabilitySaving {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text("Wird gespeichert ...")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Label("Rückmeldung war nur bis zum Tag des Gigs möglich.", systemImage: "lock.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Aushilfe
                if myStatus == "unavailable" {
                    Section("Aushilfe eintragen") {
                        if !vm.users.isEmpty {
                            Picker("Bandmitglied als Aushilfe", selection: $substituteUserId) {
                                Text("- Externe Aushilfe -").tag(Optional<Int>.none)
                                ForEach(vm.users.filter { $0.id != currentUserId }) { user in
                                    Text(user.displayName)
                                        .tag(Optional(user.id))
                                }
                            }
                            .onChange(of: substituteUserId) { _, newId in
                                if let id = newId,
                                   let u = vm.users.first(where: { $0.id == id }) {
                                    substituteName = u.displayName
                                } else {
                                    substituteName = ""
                                }
                                saveAvailability()
                            }
                        }
                        if substituteUserId == nil {
                            TextField("Name der externen Aushilfe", text: $substituteName)
                                .onSubmit { saveAvailability() }
                        }
                    }
                }

                // MARK: Zusammenfassung
                if let data = vm.availability {
                    Section("Ueberblick") {
                        HStack(spacing: 16) {
                            summaryBadge(count: data.summary.available, label: "Dabei", color: .green, icon: "checkmark.circle.fill")
                            summaryBadge(count: data.summary.maybe, label: "Vielleicht", color: .orange, icon: "questionmark.circle.fill")
                            summaryBadge(count: data.summary.unavailable, label: "Absagen", color: .red, icon: "xmark.circle.fill")
                        }
                        .padding(.vertical, 4)
                    }

                    if !available.isEmpty {
                        Section("Dabei (\(available.count))") {
                            ForEach(available) { entry in availabilityRow(entry) }
                        }
                    }
                    if !maybe.isEmpty {
                        Section("Vielleicht (\(maybe.count))") {
                            ForEach(maybe) { entry in availabilityRow(entry) }
                        }
                    }
                    if !unavailable.isEmpty {
                        Section("Absagen (\(unavailable.count))") {
                            ForEach(unavailable) { entry in unavailableRow(entry) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Verfuegbarkeit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task {
                await vm.loadAvailability(gigId: gig.id)
                await vm.loadUsersIfNeeded()
                syncFormFromData()
            }
            .refreshable {
                await vm.loadAvailability(gigId: gig.id)
                syncFormFromData()
            }
        }
    }

    // MARK: - Sub-Views

    @ViewBuilder
    private func statusButton(label: String, icon: String, color: Color, status: String) -> some View {
        let isSelected = myStatus == status
        Button {
            myStatus = status
            if status != "unavailable" {
                substituteName = ""
                substituteUserId = nil
            }
            saveAvailability()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : color)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? color : color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(isSelected ? 0 : 0.4), lineWidth: 1)
            )
        }
        .disabled(vm.isAvailabilitySaving)
    }

    @ViewBuilder
    private func summaryBadge(count: Int, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text("\(count)").font(.title2.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func availabilityRow(_ entry: AvailabilityEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.displayName).font(.body)
            if let comment = entry.comment, !comment.isEmpty {
                Text(comment).font(.caption).foregroundStyle(.secondary).italic()
            }
        }
    }

    @ViewBuilder
    private func unavailableRow(_ entry: AvailabilityEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.displayName).font(.body)
            if let sub = entry.substitute_clear_name ?? entry.substitute_name, !sub.isEmpty {
                Label("Aushilfe: \(sub)", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let comment = entry.comment, !comment.isEmpty {
                Text(comment).font(.caption).foregroundStyle(.secondary).italic()
            }
        }
    }

    // MARK: - Helpers

    private func syncFormFromData() {
        guard let uid = currentUserId,
              let mine = vm.availability?.availabilities.first(where: { $0.user_id == uid })
        else { return }
        myStatus = mine.status
        myComment = mine.comment ?? ""
        substituteName = mine.substitute_name ?? ""
        substituteUserId = mine.substitute_user_id
    }

    private func saveAvailability() {
        guard !myStatus.isEmpty else { return }
        let data = AvailabilityIn(
            status: myStatus,
            comment: myComment.isEmpty ? nil : myComment,
            substitute_name: substituteName.isEmpty ? nil : substituteName,
            substitute_user_id: substituteUserId
        )
        Task { await vm.setAvailability(gigId: gig.id, data: data) }
    }

    private func clearAvailability() async {
        await vm.deleteAvailability(gigId: gig.id)
        myStatus = ""
        myComment = ""
        substituteName = ""
        substituteUserId = nil
    }
}


