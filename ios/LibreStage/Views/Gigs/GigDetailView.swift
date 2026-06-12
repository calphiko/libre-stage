// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct GigDetailView: View {
    let gig: GigOut
    let onGigUpdated: ((GigOut) -> Void)?
    @State private var vm = GigDetailViewModel()
    @State private var isEditing = false
    @State private var draft = GigDetailsDraft()
    @State private var editableGig: GigOut?
    @State private var shareItem: ShareSheetItem? = nil
    @State private var showGigStats = false
    @State private var showGigSchedule = false
    @State private var showDownloadErrorAlert = false
    @State private var downloadErrorMessage = ""
    @State private var selectedSongForDetails: GigSongDetailSheetItem?
    @State private var showSetlistEditor = false
    @Environment(AuthManager.self) private var authManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(gig: GigOut, onGigUpdated: ((GigOut) -> Void)? = nil) {
        self.gig = gig
        self.onGigUpdated = onGigUpdated
    }

    private var canEdit: Bool {
        authManager.userRole == .admin || authManager.userRole == .editor
    }

    private var currentGig: GigOut {
        editableGig ?? gig
    }

    private var isSetlistEditorDisabledOnSmallDisplays: Bool {
#if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .phone
#else
        horizontalSizeClass == .compact
#endif
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.setlist == nil {
                SkeletonList()
            } else if let setlist = vm.setlist {
                let hasSongsInSetlist = setlist.sets.contains { !$0.songs.isEmpty }
                List {
                    // MARK: Gig Info
                    Section("Infos") {
                        if isEditing {
                            ForEach(vm.gigFields) { field in
                                gigEditorView(for: field)
                            }
                        } else {
                            ForEach(vm.gigFields) { field in
                                GigInfoRow(label: field.label, value: gigDisplayValue(for: field))
                            }
                        }
                    }
                    .listRowBackground(AppTheme.rowBackground(for: colorScheme))

                    if canEdit {
                        Section {
                            if isEditing {
                                Button {
                                    Task {
                                        if let updated = await vm.saveGig(gigId: gig.id, draft: draft) {
                                            editableGig = updated
                                            draft = GigDetailsDraft(gig: updated)
                                            isEditing = false
                                            onGigUpdated?(updated)
                                        }
                                    }
                                } label: {
                                    if vm.isSaving {
                                        ProgressView()
                                    } else {
                                        Text("Speichern")
                                    }
                                }
                                .disabled(vm.isSaving)

                                Button("Abbrechen", role: .cancel) {
                                    draft = GigDetailsDraft(gig: currentGig)
                                    isEditing = false
                                }
                            } else {
                                Button("Bearbeiten") {
                                    draft = GigDetailsDraft(gig: currentGig)
                                    isEditing = true
                                }
                            }
                        }
                        .listRowBackground(AppTheme.rowBackground(for: colorScheme))
                    }

                    // MARK: Live-Modus (nur Editor/Admin)


                    // MARK: Aktionen (für alle)
                    Section("Aktionen") {
                        Button {
                            showGigSchedule = true
                        } label: {
                            Label("Ablaufplan", systemImage: "calendar.badge.clock")
                        }

                        Button {
                            showGigStats = true
                        } label: {
                            Label("Gig-Statistiken", systemImage: "chart.bar.fill")
                        }

                        Button {
                            Task { @MainActor in
                                if let fileURL = await vm.downloadSetlistPDF(gig: currentGig) {
                                    shareItem = ShareSheetItem(url: fileURL)
                                } else {
                                    presentDownloadError(documentName: "Setliste")
                                }
                            }
                        } label: {
                            Label("Setliste herunterladen", systemImage: "arrow.down.doc")
                        }
                        .disabled(!hasSongsInSetlist)

                        Button {
                            Task { @MainActor in
                                if let fileURL = await vm.downloadForScoreSetlist(gig: currentGig) {
                                    shareItem = ShareSheetItem(url: fileURL)
                                } else {
                                    presentDownloadError(documentName: "forScore-Setliste")
                                }
                            }
                        } label: {
                            Label("forScore-Setliste (.4ss)", systemImage: "music.note.list")
                        }
                        .disabled(!hasSongsInSetlist)

                        Button {
                            Task { @MainActor in
                                if let fileURL = await vm.downloadGemaList(gig: currentGig) {
                                    shareItem = ShareSheetItem(url: fileURL)
                                } else {
                                    presentDownloadError(documentName: "GEMA-Liste")
                                }
                            }
                        } label: {
                            Label("GEMA-Liste herunterladen", systemImage: "tablecells.badge.ellipsis")
                        }
                        .disabled(!hasSongsInSetlist)


                        if canEdit {
                            Button {
                                showSetlistEditor = true
                            } label: {
                                Label("Setliste bearbeiten", systemImage: "square.and.pencil")
                            }
                            .disabled(isSetlistEditorDisabledOnSmallDisplays)

                            if isSetlistEditorDisabledOnSmallDisplays {
                                Text("Setlisten-Editor ist auf kleinen Displays nicht verfuegbar.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if vm.liveModeAvailability?.available == true {
                                NavigationLink {
                                    LiveModeView(gig: currentGig)
                                } label: {
                                    HStack {
                                        Label("Live-Modus starten", systemImage: "bolt.fill")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        if vm.liveModeAvailability?.forced == true {
                                            Text("🔓")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                }
                                .listRowBackground(Color.accentColor)
                            } else if vm.liveModeAvailability?.can_force == true {
                                Button {
                                    Task { await vm.loadLiveModeAvailability(gigId: gig.id, force: true) }
                                } label: {
                                    Label("Live Mode entsperren", systemImage: "lock.open")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                            } else {
                                Label("Live-Modus aktuell nicht verfügbar", systemImage: "lock.fill")
                                    .foregroundStyle(.secondary)
                            }

                            if let reason = vm.liveModeAvailability?.reason {
                                Text(liveModeReasonText(reason))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                        }
                    }
                    .listRowBackground(AppTheme.rowBackground(for: colorScheme))

                    // MARK: Setlist
                    ForEach(Array(setlist.sets.enumerated()), id: \.offset) { setIndex, set in
                        let setKey = setPositionKey(for: set, index: setIndex)
                        Section(set.setlist_name ?? set.set_name ?? "Set") {
                            if let setSummary = setTimeSummary(for: setlist, setKey: setKey, setIndex: setIndex) {
                                LabeledContent("Zeitkalkulation", value: setSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(Array(set.songs.enumerated()), id: \.element.id) { idx, song in
                                Button {
                                    selectedSongForDetails = GigSongDetailSheetItem(id: song.song_id, title: song.title)
                                } label: {
                                    SetlistSongRow(index: idx + 1, song: song)
                                }
                                .buttonStyle(.plain)
                            }
                            if let pauseLabel = pauseLabelAfterSet(for: setlist, setIndex: setIndex) {
                                Label(pauseLabel, systemImage: "pause.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(AppTheme.rowBackground(for: colorScheme))
                    }

                    if let totalSummary = totalSetlistTimeSummary(for: setlist) {
                        Section("Gesamt") {
                            LabeledContent("Zeitkalkulation", value: totalSummary)
                            if let endDelta = setlistEndDeltaToPlannedGigEnd(for: setlist, gig: currentGig) {
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text("Differenz zu geplantem Ende")
                                    Spacer(minLength: 8)
                                    Text(endDelta.value)
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(endDelta.isReached ? .green : .red)
                                }
                            }
                        }
                        .listRowBackground(AppTheme.rowBackground(for: colorScheme))
                    }

                }
                .softCardContainer()
                .refreshable {
                    await vm.loadSetlist(gigId: gig.id)
                    await vm.loadLiveModeAvailability(gigId: gig.id)
                }
            } else {
                ContentUnavailableView("Keine Setlist", systemImage: "music.note.list")
            }
        }
        .appShellBackground()
        .navigationTitle(currentGig.name ?? "Gig")
        .navigationBarTitleDisplayMode(.inline)
        .errorBanner($vm.error)
        .task {
            if editableGig == nil {
                editableGig = gig
                draft = GigDetailsDraft(gig: gig)
            }
            await vm.loadGigFieldConfig()
            await vm.loadSetlist(gigId: gig.id)
            if canEdit {
                await vm.loadLiveModeAvailability(gigId: gig.id)
            }
        }
        .fullScreenCover(isPresented: $showSetlistEditor) {
            SetlistEditorSheet(
                gigId: currentGig.id,
                gigName: currentGig.name ?? "Gig",
                onSaved: { updated in
                    vm.setlist = updated
                }
            )
        }
        .sheet(item: $shareItem) { item in
#if canImport(UIKit)
            ShareSheet(activityItems: [item.url])
#else
            Text("Datei heruntergeladen: \(item.url.lastPathComponent)")
                .padding()
#endif
        }
        .sheet(item: $selectedSongForDetails) { item in
            NavigationStack {
                SongDetailsView(songId: item.id, initialTitle: item.title, modalPresentation: true)
            }
        }
        .sheet(isPresented: $showGigStats) {
            GigStatisticsSheet(vm: vm, gig: currentGig)
        }
        .sheet(isPresented: $showGigSchedule) {
            GigScheduleSheet(vm: vm, gig: currentGig, canEdit: canEdit)
        }
        .alert("Download fehlgeschlagen", isPresented: $showDownloadErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(downloadErrorMessage)
        }
    }

    private func liveModeReasonText(_ reason: String) -> String {
        switch reason {
        case "gig_day":
            return "Live-Mode ist am Gig-Tag aktiv."
        case "not_gig_day":
            return "Live-Mode ist nur am Gig-Tag aktiv oder muss manuell entsperrt werden."
        case "manually_unlocked":
            return "Live-Mode wurde manuell entsperrt."
        case "insufficient_permissions":
            return "Keine Berechtigung für Live-Mode."
        default:
            return "Live-Mode-Status: \(reason)"
        }
    }

    private func presentDownloadError(documentName: String) {
        if let error = vm.error {
            downloadErrorMessage = "\(documentName) konnte nicht heruntergeladen werden.\n\n\(error.localizedMessage)"
            vm.error = nil
        } else {
            downloadErrorMessage = "\(documentName) konnte nicht heruntergeladen werden. Bitte später erneut versuchen."
        }
        showDownloadErrorAlert = true
    }

    private func totalSetlistTimeSummary(for setlist: GigSetlistOut) -> String? {
        let timing = totalSetlistTiming(for: setlist)
        let setSeconds = timing.sets
        let pauseSeconds = timing.pauses
        let total = timing.total
        guard total > 0 else { return nil }

        var summary = "Sets: \(formatDuration(seconds: setSeconds))"
        if pauseSeconds > 0 {
            summary += " + Pausen: \(formatDuration(seconds: pauseSeconds))"
        }
        summary += " = \(formatDuration(seconds: total))"
        return summary
    }

    private func totalSetlistTiming(for setlist: GigSetlistOut) -> (sets: Int, pauses: Int, total: Int) {
        guard let timing = setlist.timing else { return (0, 0, 0) }

        var setSeconds = 0
        var pauseSeconds = 0

        for (setIndex, set) in setlist.sets.enumerated() {
            let setKey = setPositionKey(for: set, index: setIndex)
            if let seconds = setDurationSeconds(from: timing, setKey: setKey) {
                setSeconds += seconds
            }
            if let pause = pauseSecondsAfterSet(from: timing, sets: setlist.sets, setIndex: setIndex) {
                pauseSeconds += pause
            }
        }

        return (setSeconds, pauseSeconds, setSeconds + pauseSeconds)
    }

    private func setlistEndDeltaToPlannedGigEnd(for setlist: GigSetlistOut, gig: GigOut) -> (value: String, isReached: Bool)? {
        guard let planned = plannedGigDurationSeconds(gig: gig) else { return nil }
        let actual = totalSetlistTiming(for: setlist).total
        let diff = actual - planned
        let prefix = diff >= 0 ? "+" : "-"
        let value = "\(prefix)\(formatDuration(seconds: abs(diff)))"
        return (value, diff >= 0)
    }

    private func plannedGigDurationSeconds(gig: GigOut) -> Int? {
        guard let begin = parseClockTimeToSeconds(gig.begin),
              let end = parseClockTimeToSeconds(gig.end) else {
            return nil
        }

        if end < begin {
            return (24 * 3600 - begin) + end
        }
        return end - begin
    }

    private func setPositionKey(for set: SetInGigOut, index: Int) -> String {
        if let position = set.position {
            return String(position)
        }
        return String(index + 1)
    }

    private func setTimeSummary(for setlist: GigSetlistOut, setKey: String, setIndex: Int) -> String? {
        guard let timing = setlist.timing,
              let setSeconds = setDurationSeconds(from: timing, setKey: setKey),
              setSeconds > 0 else {
            return nil
        }

        let pauseSeconds = pauseSecondsAfterSet(from: timing, sets: setlist.sets, setIndex: setIndex) ?? 0
        var summary = "Set: \(formatDuration(seconds: setSeconds))"
        if pauseSeconds > 0 {
            summary += " + Pause: \(formatDuration(seconds: pauseSeconds))"
        }
        summary += " = \(formatDuration(seconds: setSeconds + pauseSeconds))"
        return summary
    }

    private func pauseLabelAfterSet(for setlist: GigSetlistOut, setIndex: Int) -> String? {
        guard let timing = setlist.timing,
              let pauseSeconds = pauseSecondsAfterSet(from: timing, sets: setlist.sets, setIndex: setIndex),
              pauseSeconds > 0 else {
            return nil
        }
        return "Pause: \(formatDuration(seconds: pauseSeconds))"
    }

    private func setDurationSeconds(from timing: GigSetlistTimingOut, setKey: String) -> Int? {
        guard let starts = timing.schedule[setKey],
              let firstStart = starts.first,
              let setEnd = timing.set_end[setKey],
              let startSeconds = parseClockTimeToSeconds(firstStart),
              let endSeconds = parseClockTimeToSeconds(setEnd) else {
            return nil
        }

        if endSeconds < startSeconds {
            return (24 * 3600 - startSeconds) + endSeconds
        }
        return endSeconds - startSeconds
    }

    private func pauseSecondsAfterSet(from timing: GigSetlistTimingOut, sets: [SetInGigOut], setIndex: Int) -> Int? {
        let nextIndex = setIndex + 1
        guard nextIndex < sets.count else { return nil }

        let nextSetKey = setPositionKey(for: sets[nextIndex], index: nextIndex)
        guard let pauseMinutes = timing.pause_before[nextSetKey], pauseMinutes > 0 else {
            return nil
        }
        return pauseMinutes * 60
    }

    private func parseClockTimeToSeconds(_ value: String?) -> Int? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        let parts = raw.split(separator: ":").map(String.init)
        guard parts.count == 2 || parts.count == 3 else { return nil }
        let numbers = parts.compactMap(Int.init)
        guard numbers.count == parts.count else { return nil }

        let hour = numbers[0]
        let minute = numbers[1]
        let second = numbers.count == 3 ? numbers[2] : 0
        guard (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else {
            return nil
        }

        return hour * 3600 + minute * 60 + second
    }

    private func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    @ViewBuilder
    private func gigEditorView(for field: GigFieldDefinition) -> some View {
        switch field.type {
        case .option:
            Picker(field.required ? "\(field.label) *" : field.label, selection: gigBinding(for: field.key)) {
                if !field.required {
                    Text("-").tag("")
                }
                ForEach(field.options) { option in
                    Text(option.label).tag(option.key)
                }
            }
        case .time:
            HStack {
                DatePicker(
                    field.required ? "\(field.label) *" : field.label,
                    selection: timeBinding(for: field.key),
                    displayedComponents: .hourAndMinute
                )
                if !field.required {
                    Button("Loeschen") {
                        draft.setValue("", for: field.key)
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
        case .date:
            DatePicker(
                field.required ? "\(field.label) *" : field.label,
                selection: dateBinding(for: field.key),
                displayedComponents: .date
            )
        case .text:
            TextField(field.required ? "\(field.label) *" : field.label, text: gigBinding(for: field.key))
        }
    }

    private func gigBinding(for key: String) -> Binding<String> {
        Binding(
            get: { draft.value(for: key) },
            set: { draft.setValue($0, for: key) }
        )
    }

    private func gigDisplayValue(for field: GigFieldDefinition) -> String? {
        let raw = draft.value(for: field.key)
        guard !raw.isEmpty else { return nil }

        if field.type == .option,
           let option = field.options.first(where: { $0.key == raw }) {
            return option.label
        }

        return raw
    }

    private func dateBinding(for key: String) -> Binding<Date> {
        Binding(
            get: { parseISODate(draft.value(for: key)) ?? Date() },
            set: { draft.setValue(formatISODate($0), for: key) }
        )
    }

    private func timeBinding(for key: String) -> Binding<Date> {
        Binding(
            get: { parseTime(draft.value(for: key)) ?? defaultTimeDate() },
            set: { draft.setValue(formatTime($0), for: key) }
        )
    }

    private func parseISODate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func formatISODate(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: value)
    }

    private func parseTime(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        let parts = value.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components)
    }

    private func formatTime(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: value)
    }

    private func defaultTimeDate() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 20
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}

#if canImport(UIKit)
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

private struct GigInfoRow: View {
    let label: String
    let value: String?

    var body: some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(value)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

private struct SetlistSongRow: View {
    let index: Int
    let song: SongInSetOut

    private var displayDuration: String? {
        guard let raw = song.duration?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        let parts = raw.split(separator: ":")
        if parts.count == 3, parts[0] == "0" {
            return "\(parts[1]):\(parts[2])"
        }
        return raw
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title).font(.body)
                if let interpret = song.interpret {
                    Text(interpret).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let key = song.tone_key {
                Text(key)
                    .font(.caption2.bold())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
            if let duration = displayDuration {
                Text(duration)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct GigSongDetailSheetItem: Identifiable {
    let id: Int
    let title: String?
}

private struct ShareSheetItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct GigStatisticsSheet: View {
    @Bindable var vm: GigDetailViewModel
    let gig: GigOut

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if vm.isGigStatisticsLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if let stats = vm.gigStatistics {
                    Section("Uebersicht") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            GigKpiTile(title: "Songs", value: String(stats.song_count), icon: "music.note.list", tint: .blue)
                            GigKpiTile(title: "Uebersprungen", value: String(stats.skipped_count), icon: "forward.fill", tint: .orange)
                            GigKpiTile(title: "Eingeschoben", value: String(stats.inserted_count), icon: "pin.fill", tint: .green)
                            if let avg = stats.feedback_avg {
                                GigKpiTile(title: "Live", value: "\(feedbackEmoji(for: avg)) \(String(format: "%.2f", avg))", icon: "star.fill", tint: .yellow)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    if !stats.genre_distribution.isEmpty {
                        Section("Genres") {
                            ForEach(stats.genre_distribution.sorted(by: { $0.value > $1.value }), id: \.key) { entry in
                                LabeledContent(entry.key, value: String(entry.value))
                            }
                        }
                    }

                    if !stats.sets.isEmpty {
                        ForEach(stats.sets) { setEntry in
                            Section(setEntry.set_name) {
                                if let setAvg = setEntry.feedback_avg {
                                    LabeledContent("Set-Bewertung", value: String(format: "%.2f", setAvg))
                                }
                                ForEach(setEntry.songs) { song in
                                    HStack(spacing: 10) {
                                        Text("\(song.position)")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                            .frame(width: 18, alignment: .trailing)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(song.title).font(.body)
                                            Text(song.interpret).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if let fb = song.feedback {
                                            Text(feedbackEmoji(for: fb))
                                        }
                                        if song.uebersprungen == true {
                                            Text("⏭")
                                        }
                                        if song.eingeschoben == true {
                                            Text("📌")
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        Text("Keine Gig-Statistiken verfuegbar.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .softCardContainer()
            .appShellBackground()
            .navigationTitle(gig.name ?? "Gig-Statistik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schliessen") { dismiss() }
                }
            }
            .task {
                await vm.loadGigStatistics(gigId: gig.id)
            }
        }
    }

    private func feedbackEmoji(for value: Int) -> String {
        switch value {
        case 3: return "😊"
        case 2: return "😐"
        case 1: return "😞"
        default: return "-"
        }
    }

    private func feedbackEmoji(for avg: Double) -> String {
        if avg >= 2.5 { return "😊" }
        if avg >= 1.5 { return "😐" }
        return "😞"
    }
}

private struct GigKpiTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

