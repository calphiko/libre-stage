// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct RehearsalCreateSheet: View {
    let onCreate: (RehCreateRequest) async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var beginDate: Date = Calendar.current.date(
        bySettingHour: 19, minute: 0, second: 0, of: Date()
    ) ?? Date()
    @State private var endDate: Date = Calendar.current.date(
        bySettingHour: 21, minute: 0, second: 0, of: Date()
    ) ?? Date()
    @State private var hasEnd = true
    @State private var comment = ""
    @State private var isSaving = false

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Zeitraum") {
                    DatePicker("Beginn", selection: $beginDate, displayedComponents: [.date, .hourAndMinute])
                        .addModalFieldStyle()
                    Toggle("Ende festlegen", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("Ende", selection: $endDate, in: beginDate..., displayedComponents: [.date, .hourAndMinute])
                            .addModalFieldStyle()
                    }
                }
                .addModalSectionStyle()
                Section("Kommentar") {
                    TextField("Optional", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                        .addModalFieldStyle()
                }
                .addModalSectionStyle()
            }
            .addModalFormStyle()
            .navigationTitle("Neue Probe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") {
                        Task {
                            isSaving = true
                            let normalizedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
                            let request = RehCreateRequest(
                                begin: Self.isoFormatter.string(from: beginDate),
                                end: hasEnd ? Self.isoFormatter.string(from: endDate) : nil,
                                comment: normalizedComment.isEmpty ? "" : normalizedComment
                            )
                            await onCreate(request)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}

