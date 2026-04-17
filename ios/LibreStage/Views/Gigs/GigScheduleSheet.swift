// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct GigScheduleSheet: View {
    @Bindable var vm: GigDetailViewModel
    let gig: GigOut
    let canEdit: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var editMode = false
    @State private var inlineError = ""
    @State private var formRows: [GigScheduleFormRow] = []
    @State private var newRowCounter = 0
    @State private var shareItem: GigScheduleShareSheetItem?
    @State private var showDownloadErrorAlert = false
    @State private var downloadErrorMessage = ""
    @State private var showAddRowSheet = false
    @State private var newRowDraft = GigScheduleNewRowDraft(dateTime: Date(), was: "", wer: "", wo: "")

    var body: some View {
        NavigationStack {
            List {
                if vm.isGigScheduleLoading && vm.gigSchedule == nil {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if let schedule = vm.gigSchedule {
                    if canEdit {
                        Section {
                            Toggle("Edit-Mode", isOn: $editMode)
                        }
                    }

                    if editMode {
                        editSection
                    } else {
                        readOnlySection(schedule)
                    }
                } else {
                    Section {
                        Text("Kein Ablaufplan verfuegbar.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .softCardContainer()
            .appShellBackground()
            .navigationTitle("Ablaufplan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schliessen") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        Task { await exportPdf() }
                    } label: {
                        Label("PDF", systemImage: "arrow.down.doc")
                    }

                    Button {
                        Task { await vm.loadGigSchedule(gigId: gig.id) }
                    } label: {
                        Label("Neu laden", systemImage: "arrow.clockwise")
                    }
                }
            }
            .task {
                if vm.gigSchedule == nil {
                    await vm.loadGigSchedule(gigId: gig.id)
                }
            }
            .onChange(of: editMode) { _, newValue in
                inlineError = ""
                if newValue {
                    buildFormRowsFromSchedule()
                    resetNewRowDraft()
                }
            }
            .alert("Download fehlgeschlagen", isPresented: $showDownloadErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(downloadErrorMessage)
            }
            .sheet(item: $shareItem) { item in
#if canImport(UIKit)
                GigScheduleShareSheet(activityItems: [item.url])
#else
                Text("Datei heruntergeladen: \(item.url.lastPathComponent)")
                    .padding()
#endif
            }
            .sheet(isPresented: $showAddRowSheet) {
                addRowSheet
            }
        }
    }

    private var editSection: some View {
        Section("Ablaufplan bearbeiten") {
            Button {
                openAddRowSheet()
            } label: {
                Label("Neuen Eintrag anlegen", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)

            if formRows.filter({ !$0.isFixed }).isEmpty {
                Text("Keine flexiblen Eintraege vorhanden.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach($formRows) { $row in
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker(
                        "Zeitpunkt",
                        selection: bindingForDateTime(row: $row),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .disabled(row.isFixed)
                    .formFieldSurface()

                    TextField("Was", text: $row.was)
                        .disabled(row.isFixed)
                        .formFieldSurface()
                    TextField("Wer", text: $row.wer)
                        .disabled(row.isFixed)
                        .formFieldSurface()
                    TextField("Wo", text: $row.wo)
                        .disabled(row.isFixed)
                        .formFieldSurface()

                    HStack {
                        if row.isFixed {
                            Label("fix", systemImage: "pin.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Button(role: .destructive) {
                                removeRow(row.rowKey)
                            } label: {
                                Label("Loeschen", systemImage: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Button {
                Task { await saveAll() }
            } label: {
                if vm.isGigScheduleSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Gesamten Ablaufplan speichern")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isGigScheduleSaving)

            if !inlineError.isEmpty {
                Text(inlineError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var addRowSheet: some View {
        NavigationStack {
            Form {
                Section("Neuer Eintrag") {
                    DatePicker(
                        "Zeitpunkt",
                        selection: $newRowDraft.dateTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .formFieldSurface()
                    TextField("Was", text: $newRowDraft.was)
                        .formFieldSurface()
                    TextField("Wer", text: $newRowDraft.wer)
                        .formFieldSurface()
                    TextField("Wo", text: $newRowDraft.wo)
                        .formFieldSurface()
                }

                Section {
                    Text("Der Eintrag wird nach dem Hinzufuegen unten in der Bearbeitungsliste angezeigt und kann dort weiter angepasst werden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .softCardContainer()
            .appShellBackground()
            .navigationTitle("Eintrag hinzufuegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        showAddRowSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufuegen") {
                        addRowFromDraft()
                    }
                    .disabled(!isNewRowDraftValid)
                }
            }
        }
    }

    private func readOnlySection(_ schedule: GigScheduleOut) -> some View {
        Section {
            if schedule.items.isEmpty {
                Text("Noch keine Eintraege vorhanden.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedItems(schedule.items), id: \.stableId) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(formatDateTime(item.item_datetime))
                                .font(.subheadline.weight(.semibold))
                            if item.is_fixed {
                                Text("fix")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(item.was)
                            .font(.body)
                        Text("\(item.wer) - \(item.wo)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func buildFormRowsFromSchedule() {
        let rows = (vm.gigSchedule?.items ?? []).map { item in
            let split = splitIsoToDateTime(item.item_datetime)
            return GigScheduleFormRow(
                rowKey: item.id.map { "id-\($0)" } ?? "fixed-\(item.item_datetime)-\(item.was)",
                itemId: item.id,
                isFixed: item.is_fixed,
                date: split.date,
                time: split.time,
                was: item.was,
                wer: item.wer,
                wo: item.wo
            )
        }
        formRows = rows.sorted(by: sortRows)
    }

    private func openAddRowSheet() {
        resetNewRowDraft()
        showAddRowSheet = true
    }

    private func resetNewRowDraft() {
        let initialDate: Date
        if let gigDate = parseGigDate() {
            initialDate = gigDate
        } else {
            initialDate = Date()
        }
        newRowDraft = GigScheduleNewRowDraft(dateTime: initialDate, was: "", wer: "", wo: "")
    }

    private var isNewRowDraftValid: Bool {
        !trimmed(newRowDraft.was).isEmpty
            && !trimmed(newRowDraft.wer).isEmpty
            && !trimmed(newRowDraft.wo).isEmpty
    }

    private func addRowFromDraft() {
        let split = formatDateTimeForInputs(newRowDraft.dateTime)
        formRows.append(
            GigScheduleFormRow(
                rowKey: "new-\(newRowCounter)",
                itemId: nil,
                isFixed: false,
                date: split.date,
                time: split.time,
                was: trimmed(newRowDraft.was),
                wer: trimmed(newRowDraft.wer),
                wo: trimmed(newRowDraft.wo)
            )
        )
        formRows.sort(by: sortRows)
        newRowCounter += 1
        showAddRowSheet = false
    }

    private func removeRow(_ rowKey: String) {
        formRows.removeAll { $0.rowKey == rowKey }
    }

    private func saveAll() async {
        inlineError = ""
        let editableRows = formRows.filter { !$0.isFixed }
        let fixedIso = Set(formRows.filter { $0.isFixed }.map { toNaiveIso(datePart: $0.date, timePart: $0.time) })

        var seenIso = fixedIso
        for row in editableRows {
            if row.date.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || row.time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || row.was.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || row.wer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || row.wo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                inlineError = "Bitte alle flexiblen Eintraege vollstaendig ausfuellen."
                return
            }

            let iso = toNaiveIso(datePart: row.date, timePart: row.time)
            if seenIso.contains(iso) {
                inlineError = "Ein Zeitpunkt ist doppelt oder kollidiert mit einem festen Eintrag."
                return
            }
            seenIso.insert(iso)
        }

        let payload = GigScheduleBulkUpdateIn(
            items: editableRows.map { row in
                GigScheduleBulkItemIn(
                    id: row.itemId,
                    item_datetime: toNaiveIso(datePart: row.date, timePart: row.time),
                    was: row.was,
                    wer: row.wer,
                    wo: row.wo
                )
            }
        )

        if await vm.saveGigScheduleBulk(gigId: gig.id, payload: payload) != nil {
            buildFormRowsFromSchedule()
            editMode = false
        } else if let error = vm.error {
            inlineError = error.localizedMessage
        } else {
            inlineError = "Fehler beim Speichern."
        }
    }

    private func exportPdf() async {
        if let fileURL = await vm.downloadSchedulePDF(gig: gig) {
            shareItem = GigScheduleShareSheetItem(url: fileURL)
            return
        }

        if let error = vm.error {
            downloadErrorMessage = "Ablaufplan konnte nicht heruntergeladen werden.\n\n\(error.localizedMessage)"
            vm.error = nil
        } else {
            downloadErrorMessage = "Ablaufplan konnte nicht heruntergeladen werden. Bitte spaeter erneut versuchen."
        }
        showDownloadErrorAlert = true
    }

    private func sortedItems(_ items: [GigScheduleItemOut]) -> [GigScheduleItemOut] {
        items.sorted {
            if $0.item_datetime != $1.item_datetime {
                return $0.item_datetime < $1.item_datetime
            }
            return ($0.is_fixed ? 0 : 1) < ($1.is_fixed ? 0 : 1)
        }
    }

    private func sortRows(lhs: GigScheduleFormRow, rhs: GigScheduleFormRow) -> Bool {
        let lhsIso = toNaiveIso(datePart: lhs.date, timePart: lhs.time)
        let rhsIso = toNaiveIso(datePart: rhs.date, timePart: rhs.time)
        if lhsIso != rhsIso {
            return lhsIso < rhsIso
        }
        return (lhs.isFixed ? 0 : 1) < (rhs.isFixed ? 0 : 1)
    }

    private func toNaiveIso(datePart: String, timePart: String) -> String {
        let safeTime: String
        if timePart.count == 5 {
            safeTime = "\(timePart):00"
        } else {
            safeTime = timePart
        }
        return "\(datePart)T\(safeTime)"
    }

    private func splitIsoToDateTime(_ iso: String) -> (date: String, time: String) {
        let parts = iso.split(separator: "T", maxSplits: 1).map(String.init)
        let date = parts.first ?? ""
        let timeRaw = parts.count > 1 ? parts[1] : ""
        let time = String(timeRaw.prefix(5))
        return (date, time)
    }

    private func bindingForDateTime(row: Binding<GigScheduleFormRow>) -> Binding<Date> {
        Binding(
            get: {
                parseDateTime(date: row.wrappedValue.date, time: row.wrappedValue.time) ?? Date()
            },
            set: { newValue in
                let split = formatDateTimeForInputs(newValue)
                row.wrappedValue.date = split.date
                row.wrappedValue.time = split.time
            }
        )
    }

    private func parseDateTime(date: String, time: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: "\(date) \(time)")
    }

    private func formatDateTimeForInputs(_ value: Date) -> (date: String, time: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm"

        return (dateFormatter.string(from: value), timeFormatter.string(from: value))
    }

    private func parseGigDate() -> Date? {
        guard let dateString = gig.datum else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatDateTime(_ value: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        let fallbackParser = DateFormatter()
        fallbackParser.locale = Locale(identifier: "en_US_POSIX")
        fallbackParser.dateFormat = "yyyy-MM-dd'T'HH:mm"

        let output = DateFormatter()
        output.locale = Locale(identifier: "de_DE")
        output.dateFormat = "dd.MM.yyyy HH:mm"

        if let date = parser.date(from: value) ?? fallbackParser.date(from: value) {
            return output.string(from: date)
        }
        return value
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

private struct GigScheduleFormRow: Identifiable {
    let rowKey: String
    let itemId: Int?
    let isFixed: Bool
    var date: String
    var time: String
    var was: String
    var wer: String
    var wo: String

    var id: String { rowKey }
}

private struct GigScheduleShareSheetItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct GigScheduleNewRowDraft {
    var dateTime: Date
    var was: String
    var wer: String
    var wo: String
}

#if canImport(UIKit)
private struct GigScheduleShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif


