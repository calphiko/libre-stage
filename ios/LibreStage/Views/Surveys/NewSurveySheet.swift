// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NewSurveySheet: View {
    let onCreate: (SurveyIn) async -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title   = ""
    @State private var kind    = "Terminfindung"
    @State private var fields: [String] = []
    @State private var newDate = Date()
    @State private var useRange         = false
    @State private var rangeFrom        = Date()
    @State private var rangeTo          = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var rangeTime        = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var selectedWeekdays = Set<Int>()
    @State private var newOption = ""
    @State private var isSaving   = false
    @State private var genError   = ""
    @State private var saveError  = ""

    // Mo=2 … So=1 (Calendar.weekday Nummerierung)
    private let weekdayList: [(Int, String)] = [
        (2,"Mo"),(3,"Di"),(4,"Mi"),(5,"Do"),(6,"Fr"),(7,"Sa"),(1,"So")
    ]

    private static let storeFmt: DateFormatter = {
        let df = DateFormatter()
        df.locale     = Locale(identifier: "de_DE")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return df
    }()
    private static let displayFmt: DateFormatter = {
        let df = DateFormatter()
        df.locale     = Locale(identifier: "de_DE")
        df.dateFormat = "EEE dd.MM.yy, HH:mm 'Uhr'"
        return df
    }()

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !fields.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Titel
                Section("Titel") {
                    TextField("z.B. Probentermin Oktober", text: $title)
                        .formFieldSurface()
                }

                // Art
                Section("Art der Abstimmung") {
                    Picker("Typ", selection: $kind) {
                        Text("Terminfindung").tag("Terminfindung")
                        Text("Meinungsumfrage").tag("Meinungsumfrage")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, _ in fields = []; genError = "" }
                }

                // Felder
                if kind == "Terminfindung" {
                    terminfindungSection
                } else {
                    meinungsumfrageSection
                }

                // Bereits hinzugefuegte Eintraege
                if !fields.isEmpty {
                    Section(kind == "Terminfindung"
                            ? "Hinzugef\u{FC}gte Termine (\(fields.count))"
                            : "Hinzugef\u{FC}gte Optionen (\(fields.count))") {
                        ForEach(Array(fields.enumerated()), id: \.offset) { idx, f in
                            HStack {
                                Text(displayText(for: f)).font(.subheadline)
                                Spacer()
                                Button(role: .destructive) {
                                    fields.remove(at: idx)
                                } label: {
                                    Image(systemName: "trash").foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onDelete { off in fields.remove(atOffsets: off) }
                    }
                }
            }
            .softCardContainer()
            .appShellBackground()
            .navigationTitle("Neue Abstimmung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Erstellen") { Task { await submit() } }
                            .disabled(!canSubmit)
                    }
                }
            }
            // Hinweis wenn noch keine Felder hinzugefügt wurden
            if !canSubmit && !title.trimmingCharacters(in: .whitespaces).isEmpty {
                Section {
                    Label(
                        kind == "Terminfindung"
                            ? "Bitte mindestens einen Termin hinzuf\u{FC}gen."
                            : "Bitte mindestens eine Option hinzuf\u{FC}gen.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
            if !saveError.isEmpty {
                Section {
                    Label(saveError, systemImage: "xmark.circle.fill")
                        .font(.caption).foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Terminfindung Section

    private var terminfindungSection: some View {
        Group {
            Section {
                Toggle("Zeitraum generieren", isOn: $useRange.animation())
            }
            if !useRange {
                Section("Termin hinzuf\u{FC}gen") {
                    DatePicker("Datum & Zeit", selection: $newDate,
                               displayedComponents: [.date, .hourAndMinute])
                    .formFieldSurface()
                    Button { addDate(newDate) } label: {
                        Label("Hinzuf\u{FC}gen", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Section("Zeitraum & Uhrzeit") {
                    DatePicker("Von",     selection: $rangeFrom,
                               displayedComponents: .date)
                    .formFieldSurface()
                    DatePicker("Bis",     selection: $rangeTo,
                               in: rangeFrom...,
                               displayedComponents: .date)
                    .formFieldSurface()
                    DatePicker("Uhrzeit", selection: $rangeTime,
                               displayedComponents: .hourAndMinute)
                    .formFieldSurface()
                }
                Section("Wochentage") {
                    HStack(spacing: 6) {
                        ForEach(weekdayList, id: \.0) { calDay, label in
                            let active = selectedWeekdays.contains(calDay)
                            Button {
                                if active { selectedWeekdays.remove(calDay) }
                                else      { selectedWeekdays.insert(calDay) }
                            } label: {
                                Text(label).font(.caption.bold())
                                    .frame(width: 36, height: 36)
                                    .background(
                                        active ? Color.blue : Color.secondary.opacity(0.15)
                                    )
                                    .foregroundStyle(active ? .white : .primary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)

                    if !genError.isEmpty {
                        Text(genError).font(.caption).foregroundStyle(.red)
                    }

                    Button { generateDates() } label: {
                        Label("Termine generieren", systemImage: "wand.and.rays")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedWeekdays.isEmpty)
                }
            }
        }
    }

    // MARK: - Meinungsumfrage Section

    private var meinungsumfrageSection: some View {
        Section("Option hinzuf\u{FC}gen") {
            HStack {
                TextField("Neue Option \u{2026}", text: $newOption)
                    .formFieldSurface()
                    .onSubmit { addOption() }
                Button { addOption() } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .disabled(newOption.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Logic

    private func addDate(_ date: Date) {
        let str = Self.storeFmt.string(from: date)
        guard !fields.contains(str) else { return }
        fields.append(str)
        fields.sort()
    }

    private func addOption() {
        let opt = newOption.trimmingCharacters(in: .whitespaces)
        guard !opt.isEmpty, !fields.contains(opt) else { return }
        fields.append(opt)
        newOption = ""
    }

    private func generateDates() {
        genError = ""
        let cal       = Calendar.current
        let timeComps = cal.dateComponents([.hour, .minute], from: rangeTime)
        var current   = cal.startOfDay(for: rangeFrom)
        let end       = cal.startOfDay(for: rangeTo)
        var added     = 0
        while current <= end {
            let weekday = cal.component(.weekday, from: current)
            if selectedWeekdays.contains(weekday) {
                var comps    = cal.dateComponents([.year, .month, .day], from: current)
                comps.hour   = timeComps.hour
                comps.minute = timeComps.minute
                if let date = cal.date(from: comps) { addDate(date); added += 1 }
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        if added == 0 {
            genError = "Keine Termine f\u{FC}r die gew\u{E4}hlten Wochentage im Zeitraum."
        }
    }

    private func displayText(for field: String) -> String {
        if kind == "Terminfindung",
           let date = Self.storeFmt.date(from: field) {
            return Self.displayFmt.string(from: date)
        }
        return field
    }

    private func submit() async {
        guard canSubmit else { return }
        isSaving = true
        saveError = ""
        defer { isSaving = false }
        await onCreate(SurveyIn(
            kind_of_survey: kind,
            rf_survey: title.trimmingCharacters(in: .whitespaces),
            released: true,
            closed: false,
            fields: fields.map { SurveyFieldIn(field_text: $0) }
        ))
        // Only dismiss if no error was set
        dismiss()
    }
}
